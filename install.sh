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
YELLOW='033[0;33m'
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
AUTO_HTTPS=""

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
    --auto-https)
      AUTO_HTTPS=true
      shift 1
      ;;
    --no-auto-https)
      AUTO_HTTPS=false
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

# Respect existing auto-https choice if not overridden by CLI flags
if [ -z "$AUTO_HTTPS" ]; then
  if [ -f .env ]; then
    EXISTING_AUTO_HTTPS=$(grep -E "^AUTO_HTTPS=" .env | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    if [ "$EXISTING_AUTO_HTTPS" = "true" ]; then
      AUTO_HTTPS=true
    elif [ "$EXISTING_AUTO_HTTPS" = "false" ]; then
      AUTO_HTTPS=false
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
  if command -v ss >/dev/null 2>&1; then
    _app_req="$APP_PORT"
    while ss -tln | grep -q -E ":${APP_PORT}([^0-9]|$)" && [ "$APP_PORT" -lt 65500 ]; do
      APP_PORT=$((APP_PORT + 1))
    done
    if [ "$APP_PORT" != "$_app_req" ]; then
      echo "   Port ${_app_req} ist bereits belegt. JaanOS wird stattdessen auf Port ${APP_PORT} bereitgestellt."
    fi
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
  echo "Standardmäßig erreichen Sie Tryton bequem über JaanOS — das genügt für die"
  echo "meisten. Möchten Sie Tryton zusätzlich direkt im Browser öffnen können?"
  CHOOSE_EXPOSE=$(ask "Tryton direkt öffnen? (j/N): " "N")
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

# Check if nginx is present
NGINX_PRESENT=false
if command -v nginx >/dev/null 2>&1 && [ -d /etc/nginx/sites-available ]; then
  NGINX_PRESENT=true
fi

# Ask Auto-HTTPS question if port mode and nginx present and choice not resolved
if [ "$PORT_MODE" = true ] && [ "$NGINX_PRESENT" = true ] && [ -z "${AUTO_HTTPS:-}" ]; then
  echo ""
  echo "Automatisch HTTPS für JaanOS einrichten?"
  echo "Nutzt Ihren vorhandenen Webserver, fügt nur eine Adresse hinzu und ändert nichts Bestehendes."
  CHOOSE_AUTO_HTTPS=$(ask "Automatisch HTTPS für JaanOS einrichten? (J/n): " "J")
  if [[ "$CHOOSE_AUTO_HTTPS" =~ ^[Nn] ]]; then
    AUTO_HTTPS=false
  else
    AUTO_HTTPS=true
  fi
fi

if [ "$PORT_MODE" = false ] || [ "$NGINX_PRESENT" = false ]; then
  AUTO_HTTPS=false
fi

# 4.7 If exposing Tryton, make sure the chosen port is free — otherwise pick the next
# free one (a busy server may already use 8069, e.g. another Tryton/Odoo instance).
if [ "${EXPOSE_TRYTON:-}" = true ] && command -v ss >/dev/null 2>&1; then
  _p="${TRYTON_EXPOSE_PORT:-8069}"
  _tries=0
  while ss -tln | grep -q -E ":${_p}\b" && [ "$_tries" -lt 50 ]; do
    _p=$((_p + 1))
    _tries=$((_tries + 1))
  done
  if [ "$_p" != "${TRYTON_EXPOSE_PORT:-8069}" ]; then
    echo "   Port ${TRYTON_EXPOSE_PORT:-8069} ist bereits belegt. Tryton wird stattdessen auf Port ${_p} bereitgestellt."
    TRYTON_EXPOSE_PORT="$_p"
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
  grep -E -v "^(DOMAIN|INSTALL_MODE|APP_PORT|BUNDLED_TRYTON|BUNDLED_TRYTON_URL|BUNDLED_TRYTON_DB|BUNDLED_TRYTON_ADMIN_USER|BUNDLED_TRYTON_ADMIN_PASSWORD|COMPOSE_PROFILES|TRYTON_EXPOSE_PORT|COMPOSE_FILE|AUTO_HTTPS)=" .env > "$temp_file" || true

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
  echo "AUTO_HTTPS=${AUTO_HTTPS}" >> "$temp_file"

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
  echo "AUTO_HTTPS=${AUTO_HTTPS}" >> .env
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

# 9.5 Auto-HTTPS setup for nginx if active
if [ "$PORT_MODE" = true ] && [ "${AUTO_HTTPS:-}" = true ]; then
  # SAFETY MODEL: On a busy production server the user's existing sites must NEVER
  # break. We therefore NEVER let certbot rewrite the user's nginx config. We only
  # ever ADD our own site file (/etc/nginx/sites-*/jaanos), obtain the certificate
  # with `certbot certonly --webroot` (which touches NO nginx config), and write the
  # HTTPS server block ourselves. Every nginx change is gated by `nginx -t` and rolled
  # back on any failure, so foreign sites are always left exactly as they were.

  # 1. Install certbot if needed (core package only; no nginx plugin — we don't let
  #    certbot edit nginx). Fallback to the HTTP port if it cannot be installed.
  if ! command -v certbot >/dev/null 2>&1; then
    echo -e "${BLUE}Installiere certbot...${NC}"
    if command -v apt-get >/dev/null 2>&1; then
      export DEBIAN_FRONTEND=noninteractive
      if apt-get update -y >/dev/null 2>&1 && apt-get install -y certbot >/dev/null 2>&1; then
        echo -e "${GREEN}certbot wurde installiert.${NC}"
      else
        echo -e "${YELLOW}certbot konnte nicht installiert werden. JaanOS läuft weiter über den Port.${NC}"
        AUTO_HTTPS=false
      fi
    else
      echo -e "${YELLOW}certbot ist nicht verfügbar. JaanOS läuft weiter über den Port.${NC}"
      AUTO_HTTPS=false
    fi
  fi

  if [ "${AUTO_HTTPS:-}" = true ]; then
    # 2. Determine the public hostname. A bare IP gets a free sslip.io name that
    #    always resolves back to exactly this server, so validation cannot misfire.
    AUTO_HTTPS_DOMAIN="$DOMAIN"
    if [[ "$DOMAIN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      AUTO_HTTPS_DOMAIN="$(echo "$DOMAIN" | tr '.' '-').sslip.io"
    fi

    # Direct Tryton access gets its own HTTPS hostname through the same nginx —
    # a subdomain of the app hostname (sslip.io resolves any name containing the
    # IP, so tryton.<ip-dashes>.sslip.io needs no DNS setup either). If the cert
    # for it cannot be issued (e.g. own domain without a tryton. DNS record),
    # Tryton simply stays on its plain port — never fatal.
    TRYTON_HTTPS_DOMAIN=""
    if [ "${EXPOSE_TRYTON:-}" = true ] && [ -n "${TRYTON_EXPOSE_PORT:-}" ]; then
      TRYTON_HTTPS_DOMAIN="tryton.${AUTO_HTTPS_DOMAIN}"
    fi

    echo -e "${BLUE}Richte HTTPS für ${AUTO_HTTPS_DOMAIN} ein...${NC}"

    mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
    ACME_WEBROOT=/var/www/jaanos-acme
    mkdir -p "${ACME_WEBROOT}/.well-known/acme-challenge"

    # 3. Add OUR site only (HTTP). The ACME challenge is served from a private webroot
    #    so certbot never needs to touch nginx to validate the domain.
    cat <<NGINXTMPL > /etc/nginx/sites-available/jaanos
server {
    listen 80;
    server_name ${AUTO_HTTPS_DOMAIN} ${TRYTON_HTTPS_DOMAIN};
    location /.well-known/acme-challenge/ {
        root ${ACME_WEBROOT};
    }
    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
NGINXTMPL
    ln -sf /etc/nginx/sites-available/jaanos /etc/nginx/sites-enabled/jaanos

    # 4. Validate BEFORE reload. `nginx -t` runs the exact same parser as the reload,
    #    so if it passes, the graceful reload cannot break the running server.
    NGINX_OK=false
    if ! nginx -t >/dev/null 2>&1; then
      echo -e "${YELLOW}Die Web-Server-Prüfung ist fehlgeschlagen. JaanOS läuft weiter über den Port; Ihre bestehenden Seiten bleiben unverändert.${NC}"
      rm -f /etc/nginx/sites-available/jaanos /etc/nginx/sites-enabled/jaanos
      AUTO_HTTPS=false
    elif ! systemctl reload nginx >/dev/null 2>&1; then
      echo -e "${YELLOW}Der Web-Server konnte nicht neu geladen werden. JaanOS läuft weiter über den Port; Ihre bestehenden Seiten bleiben unverändert.${NC}"
      rm -f /etc/nginx/sites-available/jaanos /etc/nginx/sites-enabled/jaanos
      systemctl reload nginx >/dev/null 2>&1 || true
      AUTO_HTTPS=false
    else
      NGINX_OK=true
    fi
  fi

  if [ "${AUTO_HTTPS:-}" = true ] && [ "${NGINX_OK:-}" = true ]; then
    # 5. Obtain the certificate WITHOUT touching nginx config (certonly --webroot).
    #    Idempotency guard: if a valid certificate already exists, reuse it instead of
    #    calling Let's Encrypt again (avoids rate limits on repeated installs).
    CERT_LIVE="/etc/letsencrypt/live/${AUTO_HTTPS_DOMAIN}/fullchain.pem"
    CERT_OK=false
    if [ -f "$CERT_LIVE" ]; then
      echo -e "${GREEN}Ein gültiges Zertifikat ist bereits vorhanden und wird verwendet.${NC}"
      CERT_OK=true
    else
      echo -e "${BLUE}Fordere Zertifikat an...${NC}"
      if certbot certonly --webroot -w "${ACME_WEBROOT}" -d "${AUTO_HTTPS_DOMAIN}" \
           --non-interactive --agree-tos --register-unsafely-without-email >/dev/null 2>&1; then
        CERT_OK=true
      fi
    fi

    # Own certificate for the direct Tryton hostname (same safe webroot method;
    # a failure here never affects the app's HTTPS — Tryton then stays on its port).
    TRYTON_HTTPS_OK=false
    if [ "$CERT_OK" = true ] && [ -n "$TRYTON_HTTPS_DOMAIN" ]; then
      TRYTON_CERT_LIVE="/etc/letsencrypt/live/${TRYTON_HTTPS_DOMAIN}/fullchain.pem"
      if [ -f "$TRYTON_CERT_LIVE" ]; then
        TRYTON_HTTPS_OK=true
      elif certbot certonly --webroot -w "${ACME_WEBROOT}" -d "${TRYTON_HTTPS_DOMAIN}" \
             --non-interactive --agree-tos --register-unsafely-without-email >/dev/null 2>&1 \
           && [ -f "$TRYTON_CERT_LIVE" ]; then
        TRYTON_HTTPS_OK=true
      fi
    fi

    if [ "$CERT_OK" = true ] && [ -f "$CERT_LIVE" ]; then
      # 6. Write the HTTPS block OURSELVES, in our own file only. certbot never edited
      #    a single line of the user's nginx config.
      cat <<NGINXSSL > /etc/nginx/sites-available/jaanos
server {
    listen 80;
    server_name ${AUTO_HTTPS_DOMAIN};
    location /.well-known/acme-challenge/ {
        root ${ACME_WEBROOT};
    }
    location / {
        return 301 https://\$host\$request_uri;
    }
}
server {
    listen 443 ssl;
    server_name ${AUTO_HTTPS_DOMAIN};
    ssl_certificate /etc/letsencrypt/live/${AUTO_HTTPS_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${AUTO_HTTPS_DOMAIN}/privkey.pem;
    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
NGINXSSL

      # Direct Tryton access over HTTPS too — appended only when its cert exists.
      # (The port-80 block keeps serving the ACME challenge so renewals keep working.)
      if [ "${TRYTON_HTTPS_OK:-}" = true ]; then
        cat <<NGINXTRYTON >> /etc/nginx/sites-available/jaanos
server {
    listen 80;
    server_name ${TRYTON_HTTPS_DOMAIN};
    location /.well-known/acme-challenge/ {
        root ${ACME_WEBROOT};
    }
    location / {
        return 301 https://\$host\$request_uri;
    }
}
server {
    listen 443 ssl;
    server_name ${TRYTON_HTTPS_DOMAIN};
    ssl_certificate /etc/letsencrypt/live/${TRYTON_HTTPS_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${TRYTON_HTTPS_DOMAIN}/privkey.pem;
    location / {
        proxy_pass http://127.0.0.1:${TRYTON_EXPOSE_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
NGINXTRYTON
      fi

      if nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1; then
        echo -e "${GREEN}HTTPS ist aktiv.${NC}"
        DOMAIN="${AUTO_HTTPS_DOMAIN}"
        sed -i "s|^DOMAIN=.*|DOMAIN=${AUTO_HTTPS_DOMAIN}|g" .env
        if grep -q "^AUTO_HTTPS=" .env; then
          sed -i "s|^AUTO_HTTPS=.*|AUTO_HTTPS=true|g" .env
        else
          echo "AUTO_HTTPS=true" >> .env
        fi
        # shellcheck disable=SC2016
        sed -i 's|NEXT_PUBLIC_APP_URL=http://${DOMAIN}:${APP_PORT}|NEXT_PUBLIC_APP_URL=https://${DOMAIN}|g' docker-compose.yml
        # shellcheck disable=SC2016
        sed -i 's|AUTH_URL=http://${DOMAIN}:${APP_PORT}/api/auth|AUTH_URL=https://${DOMAIN}/api/auth|g' docker-compose.yml
        docker compose up -d
      else
        # The HTTPS block failed to validate — restore the known-good HTTP-only block
        # we already reloaded successfully in step 4, so nothing is left degraded.
        echo -e "${YELLOW}HTTPS konnte nicht aktiviert werden. JaanOS läuft weiter über den Port; Ihre bestehenden Seiten bleiben unverändert.${NC}"
        cat <<NGINXTMPL > /etc/nginx/sites-available/jaanos
server {
    listen 80;
    server_name ${AUTO_HTTPS_DOMAIN};
    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
NGINXTMPL
        if ! nginx -t >/dev/null 2>&1; then
          rm -f /etc/nginx/sites-available/jaanos /etc/nginx/sites-enabled/jaanos
        fi
        systemctl reload nginx >/dev/null 2>&1 || true
        AUTO_HTTPS=false
      fi
    else
      # No certificate was issued (e.g. DNS not pointed here yet). Remove our site so
      # the server is exactly as before, and keep JaanOS on its working HTTP port.
      echo -e "${YELLOW}Es konnte kein Zertifikat ausgestellt werden. JaanOS läuft weiter über den Port; Ihre bestehenden Seiten bleiben unverändert.${NC}"
      rm -f /etc/nginx/sites-available/jaanos /etc/nginx/sites-enabled/jaanos
      systemctl reload nginx >/dev/null 2>&1 || true
      AUTO_HTTPS=false
    fi
  fi
fi

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

echo ""
if [ "$PORT_MODE" = true ]; then
  if [ "${AUTO_HTTPS:-}" = true ]; then
    ACCESS_URL="https://${DOMAIN}"
  else
    ACCESS_URL="http://${DOMAIN}:${APP_PORT}"
  fi
else
  ACCESS_URL="https://${DOMAIN}"
fi

echo -e "  ${GREEN}JaanOS ist bereit.${NC}"
echo ""
echo -e "    Oberfläche        ${BLUE}${ACCESS_URL}${NC}"
if [ "$EXPOSE_TRYTON" = true ]; then
  if [ "${AUTO_HTTPS:-}" = true ] && [ "${TRYTON_HTTPS_OK:-}" = true ]; then
    echo -e "    Tryton            ${BLUE}https://${TRYTON_HTTPS_DOMAIN}${NC}"
  else
    echo -e "    Tryton            ${BLUE}http://${DOMAIN}:${TRYTON_EXPOSE_PORT}${NC}"
  fi
  echo    "                      Benutzer admin · Passwort in /opt/jaanos/.env · Datenbank tryton"
fi
echo ""
if [ "$WITH_TRYTON" = true ]; then
  echo "    Das ERP wird im Hintergrund eingerichtet. Sie können sich bereits anmelden"
  echo "    und es anschließend in einem Schritt verbinden."
  if [ "$EXPOSE_TRYTON" != true ]; then
    echo "    Direkter Tryton-Zugang jederzeit:  bash install.sh --expose-tryton 8069"
  fi
  echo ""
fi
if [ "$PORT_MODE" = true ] && [ "${AUTO_HTTPS:-}" != true ]; then
  echo "    Die Verbindung ist noch nicht verschlüsselt. Solange Sie JaanOS im eigenen"
  echo "    Netz nutzen, ist alles gut; für den öffentlichen Zugriff später absichern."
elif [ "$EXPOSE_TRYTON" = true ] && [ "${TRYTON_HTTPS_OK:-}" != true ]; then
  echo "    Der direkte Tryton-Zugang ist noch nicht verschlüsselt — im eigenen Netz"
  echo "    unbedenklich; für den öffentlichen Zugriff später absichern."
fi
echo ""
