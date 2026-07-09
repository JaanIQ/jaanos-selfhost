#!/bin/bash
# ==============================================================================
# JaanOS Core — Self-Hosted One-Line Installer
# Idempotent, robust installation and update utility.
# ==============================================================================

set -euo pipefail

# Visual styling
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 JaanOS Core Self-Hosted Installer${NC}"
echo "================================================="

# Parse arguments
DOMAIN=""
APP_PORT=""
PORT_MODE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --domain)
      DOMAIN="$2"
      PORT_MODE=false
      shift 2
      ;;
    --port)
      APP_PORT="$2"
      PORT_MODE=true
      shift 2
      ;;
    *)
      echo -e "${RED}Unknown argument: $1${NC}"
      exit 1
      ;;
  esac
done

# Interactive prompt helper. Under `curl … | bash`, stdin is the SCRIPT itself —
# a plain `read` would consume script text. Read from the terminal instead.
# A 120s timeout prevents hanging forever in non-interactive contexts (automation,
# detached shells): after the timeout the sensible default is used and announced.
ask() {
  local prompt="$1" default="$2" answer=""
  if [ -r /dev/tty ]; then
    if ! read -t 120 -rp "$prompt" answer < /dev/tty; then
      echo "" > /dev/tty 2>/dev/null || true
    fi
  fi
  if [ -z "$answer" ]; then
    answer="$default"
  fi
  echo "$answer"
}

# 1. Set up Workspace Directory
echo -e "${BLUE}📁 Setting up workspace directory /opt/jaanos...${NC}"
mkdir -p /opt/jaanos
cd /opt/jaanos

# 2. Respect an existing installation's mode if no flags were passed (re-run = update)
if [ -z "$PORT_MODE" ]; then
  if [ -f .env ]; then
    INSTALL_MODE=$(grep -E "^INSTALL_MODE=" .env | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    if [ "$INSTALL_MODE" = "port" ]; then
      PORT_MODE=true
      APP_PORT=$(grep -E "^APP_PORT=" .env | cut -d'=' -f2- | tr -d '"' | tr -d "'")
      DOMAIN=$(grep -E "^DOMAIN=" .env | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    else
      PORT_MODE=false
      DOMAIN=$(grep -E "^DOMAIN=" .env | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    fi
  fi
fi

# 3. Occupied 80/443? Offer port mode (for servers already running a web server).
if [ -z "$PORT_MODE" ]; then
  if command -v ss >/dev/null 2>&1 && ss -tln | grep -q -E ':(80|443)\b'; then
    echo -e "${RED}⚠️ Ports 80/443 sind belegt (z. B. durch einen bestehenden Webserver).${NC}"
    echo "JaanOS kann im Test-Modus auf einem eigenen Port laufen — ohne die bestehenden Dienste zu berühren."
    CHOOSE_PORT_MODE=$(ask "Test-Modus auf eigenem Port starten? (J/n): " "J")
    if [[ "$CHOOSE_PORT_MODE" =~ ^[Nn] ]]; then
      echo "Installation abgebrochen."
      exit 1
    fi
    USER_PORT=$(ask "Gewünschter Port [Default: 8321]: " "8321")
    if [[ ! "$USER_PORT" =~ ^[0-9]+$ ]]; then
      echo -e "${RED}Fehler: Ungültiger Port.${NC}"
      exit 1
    fi
    APP_PORT="$USER_PORT"
    PORT_MODE=true
  else
    PORT_MODE=false
  fi
fi

# Helper: detect the server's public IPv4 (empty on failure — callers decide).
get_public_ip() {
  local ip
  ip=$(curl -fsS --max-time 10 -4 https://api.ipify.org 2>/dev/null || curl -fsS --max-time 10 -4 https://ifconfig.me 2>/dev/null || true)
  echo "$ip" | tr -d ' \n'
}

# 4. Resolve Domain / IP based on mode
if [ "$PORT_MODE" = true ]; then
  if [ -z "$APP_PORT" ]; then
    APP_PORT=8321
  fi
  if [ -z "$DOMAIN" ]; then
    DOMAIN=$(get_public_ip)
    if [ -z "$DOMAIN" ]; then
      DOMAIN=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    if [ -z "$DOMAIN" ]; then
      DOMAIN="127.0.0.1"
      echo -e "${RED}⚠️ Konnte keine Server-IP ermitteln — verwende 127.0.0.1 (nur lokal erreichbar).${NC}"
    fi
  fi
else
  if [ -z "$DOMAIN" ]; then
    echo ""
    echo "Eine eigene Domain ist optional. Einfach ENTER drücken — JaanOS ist dann über eine"
    echo "kostenlose sslip.io-Adresse erreichbar (echtes HTTPS, keine DNS-Einrichtung nötig)."
    USER_DOMAIN=$(ask "Domain (z. B. jaanos.example.com) oder ENTER für automatisch: " "")
    if [ -z "$USER_DOMAIN" ]; then
      echo -e "${BLUE}🌐 Keine Domain angegeben — ermittle öffentliche IP für die automatische sslip.io-Adresse...${NC}"
      PUBLIC_IP=$(get_public_ip)
      if [ -z "$PUBLIC_IP" ]; then
        echo -e "${RED}Fehler: Öffentliche IP nicht ermittelbar. Bitte erneut mit --domain <ihre-domain> ausführen.${NC}"
        exit 1
      fi
      DOMAIN="$(echo "$PUBLIC_IP" | tr '.' '-').sslip.io"
      echo -e "${GREEN}✓ Automatische Adresse: https://${DOMAIN}${NC}"
      echo "  (Eigene Domain jederzeit nachrüstbar: bash install.sh --domain ihre-domain.de)"
    else
      DOMAIN="$USER_DOMAIN"
    fi
  fi
fi

if [ -z "$DOMAIN" ]; then
  echo -e "${RED}Error: Domain is required.${NC}"
  exit 1
fi

DOMAIN=$(echo "$DOMAIN" | tr -d ' ' | tr -d '"' | tr -d "'")

# 5. Download Stack Configurations (from main — single source of truth)
echo -e "${BLUE}📥 Downloading stack configurations...${NC}"
if [ "$PORT_MODE" = true ]; then
  curl -fsSL https://raw.githubusercontent.com/JaanIQ/jaanos-selfhost/main/docker-compose.port.yml -o docker-compose.yml
  rm -f Caddyfile
else
  curl -fsSL https://raw.githubusercontent.com/JaanIQ/jaanos-selfhost/main/docker-compose.yml -o docker-compose.yml
  curl -fsSL https://raw.githubusercontent.com/JaanIQ/jaanos-selfhost/main/Caddyfile -o Caddyfile
fi

# 6. Check/Install Docker and Compose
echo -e "${BLUE}⚙️ Checking Docker environment...${NC}"
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed. Installing Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  rm get-docker.sh
fi

if ! docker compose version >/dev/null 2>&1; then
  echo -e "${RED}Docker Compose plugin is missing. Please install docker-compose-plugin.${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Docker and Compose plugin are active.${NC}"

# 7. Generate .env values securely if not exists
generate_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

echo -e "${BLUE}🔑 Processing environment configuration...${NC}"
if [ -f .env ]; then
  echo "Existing .env file found. Preserving all keys."
  temp_file=$(mktemp)
  grep -E -v "^(DOMAIN|INSTALL_MODE|APP_PORT)=" .env > "$temp_file" || true

  echo "DOMAIN=${DOMAIN}" >> "$temp_file"
  if [ "$PORT_MODE" = true ]; then
    echo "INSTALL_MODE=port" >> "$temp_file"
    echo "APP_PORT=${APP_PORT}" >> "$temp_file"
  else
    echo "INSTALL_MODE=standard" >> "$temp_file"
  fi
  mv "$temp_file" .env
else
  echo "Creating fresh .env configuration..."
  POSTGRES_PASS=$(generate_secret)
  ENC_KEY=$(generate_secret)
  AUTH_SEC=$(generate_secret)

  if [ "$PORT_MODE" = true ]; then
    cat <<EOF > .env
DOMAIN=${DOMAIN}
POSTGRES_PASSWORD=${POSTGRES_PASS}
ENCRYPTION_KEY=${ENC_KEY}
AUTH_SECRET=${AUTH_SEC}
INSTALL_MODE=port
APP_PORT=${APP_PORT}
EOF
  else
    cat <<EOF > .env
DOMAIN=${DOMAIN}
POSTGRES_PASSWORD=${POSTGRES_PASS}
ENCRYPTION_KEY=${ENC_KEY}
AUTH_SECRET=${AUTH_SEC}
INSTALL_MODE=standard
EOF
  fi
  chmod 600 .env
fi
echo -e "${GREEN}✓ Configuration saved in .env.${NC}"

# 8. Pull and launch the stack
echo -e "${BLUE}📥 Pulling latest Docker images...${NC}"
if [ "${TEST_MODE_NO_PULL:-false}" != "true" ]; then
  if ! docker compose pull; then
    # Common on servers already in use: a stale registry login makes Docker send
    # invalid credentials even though the JaanOS image is public ("denied").
    # Retry anonymously with an EMPTY docker config — this ignores stored logins
    # for this one command WITHOUT touching or deleting the user's credentials.
    echo ""
    echo -e "${BLUE}↻ Erster Download fehlgeschlagen — erneuter Versuch ohne gespeicherte Registry-Logins (anonym)...${NC}"
    ANON_CONFIG=$(mktemp -d)
    if DOCKER_CONFIG="$ANON_CONFIG" docker compose pull; then
      echo -e "${GREEN}✓ Anonymer Download erfolgreich (Ihre gespeicherten Docker-Logins wurden nicht verändert).${NC}"
      rm -rf "$ANON_CONFIG"
    else
      rm -rf "$ANON_CONFIG"
      echo ""
      echo -e "${RED}⚠️ Image-Download fehlgeschlagen.${NC}"
      echo "Bitte prüfen Sie die Internetverbindung des Servers und führen Sie das Skript erneut aus."
      echo "Bleibt der Fehler 'denied' bestehen:  docker logout ghcr.io  und erneut ausführen."
      exit 1
    fi
  fi
else
  echo "TEST_MODE_NO_PULL is active. Skipping docker compose pull."
fi

echo -e "${BLUE}♻️ Starting containers...${NC}"
docker compose up -d

# 9. Wait for proxy/app to become active
echo -e "${BLUE}🏥 Checking system health...${NC}"
for i in {1..12}; do
  sleep 5
  if [ "$PORT_MODE" = true ]; then
    if curl -sf "http://127.0.0.1:${APP_PORT}/" >/dev/null 2>&1; then
      echo -e "${GREEN}✓ JaanOS is responding.${NC}"
      break
    fi
  else
    if curl -sf -H "Host: ${DOMAIN}" http://127.0.0.1/ >/dev/null 2>&1 || \
       curl -sf -k https://127.0.0.1/ >/dev/null 2>&1; then
      echo -e "${GREEN}✓ JaanOS is responding.${NC}"
      break
    fi
  fi
  echo "Waiting for services... (Attempt $i/12)"
  if [ "$i" -eq 12 ]; then
    echo -e "${RED}⚠️ Startup health check timed out. Please check container logs with 'docker compose logs'.${NC}"
  fi
done

echo "================================================="
if [ "$PORT_MODE" = true ]; then
  echo -e "${GREEN}JaanOS läuft (Test-Modus, ohne SSL) → http://${DOMAIN}:${APP_PORT}${NC}"
  echo "Hinweis: Für den Dauerbetrieb mit HTTPS: eigenen Server ohne belegte Ports 80/443 nutzen"
  echo "oder JaanOS hinter Ihren bestehenden Webserver legen (siehe Doku)."
else
  echo -e "${GREEN}🎉 JaanOS Core is running!${NC}"
  echo -e "Access it here: ${BLUE}https://${DOMAIN}${NC}"
fi
echo "================================================="
