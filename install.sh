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
WITH_TRYTON=""
EXPOSE_TRYTON=""
TRYTON_EXPOSE_PORT=""

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
    --with-tryton)
      WITH_TRYTON=true
      shift 1
      ;;
    --no-tryton)
      WITH_TRYTON=false
      shift 1
      ;;
    --expose-tryton)
      EXPOSE_TRYTON=true
      if [[ $# -gt 1 && "$2" =~ ^[0-9]+$ ]]; then
        TRYTON_EXPOSE_PORT="$2"
        shift 2
      else
        shift 1
      fi
      ;;
    --no-expose-tryton)
      EXPOSE_TRYTON=false
      shift 1
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

# Respect existing tryton choice if not overridden by CLI flags
if [ -z "$WITH_TRYTON" ]; then
  if [ -f .env ]; then
    EXISTING_TRYTON=$(grep -E "^BUNDLED_TRYTON=" .env | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    if [ "$EXISTING_TRYTON" = "true" ]; then
      WITH_TRYTON=true
    elif [ "$EXISTING_TRYTON" = "false" ]; then
      WITH_TRYTON=false
    fi
  fi
fi

# Respect existing expose tryton choice if not overridden by CLI flags
if [ -z "$EXPOSE_TRYTON" ]; then
  if [ -f .env ]; then
    if grep -E "^TRYTON_EXPOSE_PORT=" .env >/dev/null 2>&1 || grep -q "docker-compose.expose.yml" .env 2>/dev/null; then
      EXPOSE_TRYTON=true
      if [ -z "$TRYTON_EXPOSE_PORT" ]; then
        TRYTON_EXPOSE_PORT=$(grep -E "^TRYTON_EXPOSE_PORT=" .env | cut -d'=' -f2- | tr -d '"' | tr -d "'")
      fi
    else
      EXPOSE_TRYTON=false
    fi
  fi
fi

# 3. Occupied 80/443? Offer port mode (for servers already running a web server).
if [ -z "$PORT_MODE" ]; then
  if command -v ss >/dev/null 2>&1 && ss -tln | grep -q -E ':(80|443)\b'; then
    echo -e "${RED}⚠️ Ports 80/443 sind belegt (z. B. durch einen bestehenden Webserver).${NC}"
    echo "JaanOS läuft dann auf einem eigenen Port — vollwertig, ohne die bestehenden Dienste zu berühren."
    echo "(Für HTTPS wird eine fertige Vorlage für Ihren vorhandenen Webserver mitgeliefert.)"
    CHOOSE_PORT_MODE=$(ask "Auf eigenem Port installieren? (J/n): " "J")
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

# 4.5 Ask Tryton question if not resolved
if [ -z "$WITH_TRYTON" ]; then
  echo ""
  echo "Möchten Sie das Komplettpaket mit integriertem Tryton ERP installieren?"
  echo "Falls Sie schon ein ERP haben (Tryton/Lexware), können Sie auch 'n' wählen und es später verbinden."
  CHOOSE_TRYTON=$(ask "Integriertes Tryton ERP installieren? (J/n): " "J")
  if [[ "$CHOOSE_TRYTON" =~ ^[Nn] ]]; then
    WITH_TRYTON=false
  else
    WITH_TRYTON=true
  fi
fi

if [ "$WITH_TRYTON" = false ]; then
  EXPOSE_TRYTON=false
fi

# 4.6 Ask Tryton expose question if Tryton is enabled and choice not resolved
if [ "$WITH_TRYTON" = true ] && [ -z "$EXPOSE_TRYTON" ]; then
  echo ""
  echo "Tryton-Weboberfläche direkt im Browser erreichbar machen?"
  echo "Ein offener Port ist zusätzliche Angriffsfläche; für den Dauerbetrieb hinter Ihren Reverse-Proxy mit SSL legen."
  CHOOSE_EXPOSE=$(ask "Tryton-Weboberfläche direkt im Browser erreichbar machen? (j/N) — Standard: nur über JaanOS: " "N")
  if [[ "$CHOOSE_EXPOSE" =~ ^[JjYy] ]]; then
    EXPOSE_TRYTON=true
  else
    EXPOSE_TRYTON=false
  fi
fi

if [ "${EXPOSE_TRYTON:-}" = true ]; then
  if [ -z "${TRYTON_EXPOSE_PORT:-}" ]; then
    USER_EXPOSE_PORT=$(ask "Gewünschter Tryton-Port [Default: 8069]: " "8069")
    if [[ ! "$USER_EXPOSE_PORT" =~ ^[0-9]+$ ]]; then
      echo -e "${RED}Fehler: Ungültiger Port.${NC}"
      exit 1
    fi
    TRYTON_EXPOSE_PORT="$USER_EXPOSE_PORT"
  fi
fi

# 5. Download Stack Configurations (from main — single source of truth)
echo -e "${BLUE}📥 Downloading stack configurations...${NC}"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
if [ "${TEST_MODE_LOCAL_CONFIG:-false}" = "true" ] && [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
  echo "TEST_MODE_LOCAL_CONFIG is active. Copying local configs instead of downloading."
  if [ "$PORT_MODE" = true ]; then
    cp "$SCRIPT_DIR/docker-compose.port.yml" ./docker-compose.yml
    rm -f Caddyfile
  else
    cp "$SCRIPT_DIR/docker-compose.yml" ./docker-compose.yml
    cp "$SCRIPT_DIR/Caddyfile" ./Caddyfile
  fi
  if [ "$EXPOSE_TRYTON" = true ] && [ -f "$SCRIPT_DIR/docker-compose.expose.yml" ]; then
    cp "$SCRIPT_DIR/docker-compose.expose.yml" ./docker-compose.expose.yml
  fi
else
  if [ "$PORT_MODE" = true ]; then
    curl -fsSL https://raw.githubusercontent.com/JaanIQ/jaanos-selfhost/main/docker-compose.port.yml -o docker-compose.yml
    rm -f Caddyfile
  else
    curl -fsSL https://raw.githubusercontent.com/JaanIQ/jaanos-selfhost/main/docker-compose.yml -o docker-compose.yml
    curl -fsSL https://raw.githubusercontent.com/JaanIQ/jaanos-selfhost/main/Caddyfile -o Caddyfile
  fi
  if [ "$EXPOSE_TRYTON" = true ]; then
    curl -fsSL https://raw.githubusercontent.com/JaanIQ/jaanos-selfhost/main/docker-compose.expose.yml -o docker-compose.expose.yml
  fi
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
# Extract or generate BUNDLED_TRYTON_ADMIN_PASSWORD once
BUNDLED_TRYTON_PASS=""
if [ -f .env ]; then
  BUNDLED_TRYTON_PASS=$(grep -E "^BUNDLED_TRYTON_ADMIN_PASSWORD=" .env | cut -d'=' -f2- | tr -d '"' | tr -d "'")
fi
if [ -z "$BUNDLED_TRYTON_PASS" ]; then
  BUNDLED_TRYTON_PASS=$(generate_secret)
fi

if [ -f .env ]; then
  echo "Existing .env file found. Preserving all keys."
  temp_file=$(mktemp)
  grep -E -v "^(DOMAIN|INSTALL_MODE|APP_PORT|BUNDLED_TRYTON|BUNDLED_TRYTON_URL|BUNDLED_TRYTON_DB|BUNDLED_TRYTON_ADMIN_USER|BUNDLED_TRYTON_ADMIN_PASSWORD|COMPOSE_PROFILES|TRYTON_EXPOSE_PORT|COMPOSE_FILE)=" .env > "$temp_file" || true

  echo "DOMAIN=${DOMAIN}" >> "$temp_file"
  if [ "$PORT_MODE" = true ]; then
    echo "INSTALL_MODE=port" >> "$temp_file"
    echo "APP_PORT=${APP_PORT}" >> "$temp_file"
  else
    echo "INSTALL_MODE=standard" >> "$temp_file"
  fi

  if [ "$WITH_TRYTON" = true ]; then
    echo "BUNDLED_TRYTON=true" >> "$temp_file"
    echo "BUNDLED_TRYTON_URL=http://tryton:8000" >> "$temp_file"
    echo "BUNDLED_TRYTON_DB=tryton" >> "$temp_file"
    echo "BUNDLED_TRYTON_ADMIN_USER=admin" >> "$temp_file"
    echo "BUNDLED_TRYTON_ADMIN_PASSWORD=${BUNDLED_TRYTON_PASS}" >> "$temp_file"
    echo "COMPOSE_PROFILES=tryton" >> "$temp_file"
    if [ "$EXPOSE_TRYTON" = true ]; then
      echo "TRYTON_EXPOSE_PORT=${TRYTON_EXPOSE_PORT}" >> "$temp_file"
      echo "COMPOSE_FILE=docker-compose.yml:docker-compose.expose.yml" >> "$temp_file"
    else
      echo "COMPOSE_FILE=docker-compose.yml" >> "$temp_file"
    fi
  else
    echo "BUNDLED_TRYTON=false" >> "$temp_file"
    echo "COMPOSE_PROFILES=" >> "$temp_file"
    echo "COMPOSE_FILE=docker-compose.yml" >> "$temp_file"
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

  if [ "$WITH_TRYTON" = true ]; then
    cat <<EOF >> .env
BUNDLED_TRYTON=true
BUNDLED_TRYTON_URL=http://tryton:8000
BUNDLED_TRYTON_DB=tryton
BUNDLED_TRYTON_ADMIN_USER=admin
BUNDLED_TRYTON_ADMIN_PASSWORD=${BUNDLED_TRYTON_PASS}
COMPOSE_PROFILES=tryton
EOF
    if [ "$EXPOSE_TRYTON" = true ]; then
      cat <<EOF >> .env
TRYTON_EXPOSE_PORT=${TRYTON_EXPOSE_PORT}
COMPOSE_FILE=docker-compose.yml:docker-compose.expose.yml
EOF
    else
      cat <<EOF >> .env
COMPOSE_FILE=docker-compose.yml
EOF
    fi
  else
    cat <<EOF >> .env
BUNDLED_TRYTON=false
COMPOSE_PROFILES=
COMPOSE_FILE=docker-compose.yml
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

# Port mode: ship a ready-to-use vhost template for the user's existing web server,
# with the actual chosen port already filled in — completing HTTPS is ONE step,
# not a reinstall (this installation is full-featured and permanent as-is).
if [ "$PORT_MODE" = true ]; then
  # Suggest the free sslip.io name for users without their own domain — it works
  # through THEIR web server + certbot too (no domain purchase, no DNS setup).
  SSLIP_SUGGESTION="$(echo "$DOMAIN" | tr '.' '-').sslip.io"
  cat > /opt/jaanos/nginx-jaanos.conf.example <<NGINXEOF
# JaanOS hinter Ihrem bestehenden nginx (HTTPS macht dann nginx/certbot):
#   1) Domain unten eintragen (DNS muss auf diesen Server zeigen).
#      Keine eigene Domain? Ihre kostenlose automatische Adresse funktioniert genauso:
#      ${SSLIP_SUGGESTION}   (einfach unten als server_name eintragen)
#   2) sudo cp /opt/jaanos/nginx-jaanos.conf.example /etc/nginx/sites-available/jaanos
#      sudo ln -s /etc/nginx/sites-available/jaanos /etc/nginx/sites-enabled/jaanos
#   3) sudo nginx -t && sudo systemctl reload nginx
#   4) sudo certbot --nginx -d ${SSLIP_SUGGESTION}   (oder Ihre eigene Domain)
server {
    listen 80;
    server_name ${SSLIP_SUGGESTION};
    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
NGINXEOF
fi

echo "================================================="
if [ "$PORT_MODE" = true ]; then
  echo -e "${GREEN}🎉 Geschafft! JaanOS läuft.${NC}"
  echo ""
  echo -e "   Jetzt im Browser öffnen:   ${BLUE}http://${DOMAIN}:${APP_PORT}${NC}"
  if [ "$WITH_TRYTON" = true ]; then
    echo ""
    echo "   Ihr ERP wird im Hintergrund eingerichtet (ein paar Minuten). Sie können"
    echo "   sich schon registrieren und es dann mit einem Klick verbinden."
  fi
  if [ "$EXPOSE_TRYTON" = true ]; then
    echo ""
    echo -e "   Tryton direkt:             ${BLUE}http://${DOMAIN}:${TRYTON_EXPOSE_PORT}${NC}"
    echo "   (Benutzer: admin · Passwort: grep BUNDLED_TRYTON_ADMIN_PASSWORD /opt/jaanos/.env · DB: tryton)"
  elif [ "$WITH_TRYTON" = true ]; then
    echo ""
    echo "   Tipp: Tryton direkt öffnen? Später:  bash install.sh --expose-tryton 8069"
  fi
  echo ""
  echo "   Läuft unverschlüsselt (HTTP) — ideal zum Testen und im eigenen Netz."
  echo "   Für den Dauerbetrieb übers Internet später mit SSL absichern (siehe Doku)."
else
  echo -e "${GREEN}🎉 Geschafft! JaanOS läuft.${NC}"
  echo ""
  echo -e "   Jetzt im Browser öffnen:   ${BLUE}https://${DOMAIN}${NC}"
  if [ "$WITH_TRYTON" = true ]; then
    echo ""
    echo "   Ihr ERP wird im Hintergrund eingerichtet (ein paar Minuten). Sie können"
    echo "   sich schon registrieren und es dann mit einem Klick verbinden."
  fi
  if [ "$EXPOSE_TRYTON" = true ]; then
    echo ""
    echo -e "   Tryton direkt:             ${BLUE}http://${DOMAIN}:${TRYTON_EXPOSE_PORT}${NC}"
    echo "   (Benutzer: admin · Passwort: grep BUNDLED_TRYTON_ADMIN_PASSWORD /opt/jaanos/.env · DB: tryton)"
    echo "   Offener Port — für Dauerbetrieb übers Internet mit SSL absichern."
  elif [ "$WITH_TRYTON" = true ]; then
    echo ""
    echo "   Tipp: Tryton direkt öffnen? Später:  bash install.sh --expose-tryton 8069"
  fi
fi
echo "================================================="
