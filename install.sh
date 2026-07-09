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
while [[ $# -gt 0 ]]; do
  case $1 in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    *)
      echo -e "${RED}Unknown argument: $1${NC}"
      exit 1
      ;;
  esac
done

# 1. Set up Workspace Directory
echo -e "${BLUE}📁 Setting up workspace directory /opt/jaanos...${NC}"
mkdir -p /opt/jaanos
cd /opt/jaanos

# 2. Download Stack Configurations
echo -e "${BLUE}📥 Downloading stack configurations...${NC}"
curl -fsSL https://raw.githubusercontent.com/JaanIQ/jaanos-selfhost/main/docker-compose.yml -o docker-compose.yml
curl -fsSL https://raw.githubusercontent.com/JaanIQ/jaanos-selfhost/main/Caddyfile -o Caddyfile

# 3. Check/Install Docker and Compose
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

# 4. Get Domain Configuration
if [ -z "$DOMAIN" ]; then
  if [ -f .env ]; then
    # Extract domain from existing .env
    DOMAIN=$(grep -E "^DOMAIN=" .env | cut -d'=' -f2- | tr -d '"' | tr -d "'")
  fi

  if [ -z "$DOMAIN" ]; then
    echo ""
    echo "A domain is optional. Press ENTER to skip — JaanOS will then be reachable"
    echo "via a free sslip.io address based on your server IP (real HTTPS, zero DNS setup)."
    read -rp "Domain (e.g. jaanos.example.com) or ENTER for automatic: " DOMAIN
  fi
fi

# No domain? Fall back to a magic sslip.io hostname (resolves to this server's IP
# automatically — Let's Encrypt works, no DNS configuration required).
if [ -z "$DOMAIN" ]; then
  echo -e "${BLUE}🌐 No domain provided — detecting public IP for an automatic sslip.io address...${NC}"
  PUBLIC_IP=$(curl -fsS --max-time 10 -4 https://api.ipify.org 2>/dev/null || curl -fsS --max-time 10 -4 https://ifconfig.me 2>/dev/null || true)
  if [ -z "$PUBLIC_IP" ]; then
    echo -e "${RED}Error: Could not detect the public IP. Please re-run with --domain <your-domain>.${NC}"
    exit 1
  fi
  DOMAIN="$(echo "$PUBLIC_IP" | tr '.' '-').sslip.io"
  echo -e "${GREEN}✓ Using automatic address: https://${DOMAIN}${NC}"
  echo "  (You can switch to your own domain at any time: bash install.sh --domain your-domain.com)"
fi

# Clean domain name input
DOMAIN=$(echo "$DOMAIN" | tr -d ' ' | tr -d '"' | tr -d "'")

# 5. Generate .env values securely if not exists
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
  # Ensure the domain is up to date in .env
  # Temp file for replacement
  temp_file=$(mktemp)
  grep -v "^DOMAIN=" .env > "$temp_file" || true
  echo "DOMAIN=${DOMAIN}" >> "$temp_file"
  mv "$temp_file" .env
else
  echo "Creating fresh .env configuration..."
  POSTGRES_PASS=$(generate_secret)
  ENC_KEY=$(generate_secret)
  AUTH_SEC=$(generate_secret)

  cat <<EOF > .env
DOMAIN=${DOMAIN}
POSTGRES_PASSWORD=${POSTGRES_PASS}
ENCRYPTION_KEY=${ENC_KEY}
AUTH_SECRET=${AUTH_SEC}
EOF
  chmod 600 .env
fi
echo -e "${GREEN}✓ Configuration saved in .env.${NC}"

# 6. Pull and launch the stack
echo -e "${BLUE}📥 Pulling latest Docker images...${NC}"
docker compose pull

echo -e "${BLUE}♻️ Starting containers...${NC}"
docker compose up -d

# 7. Wait for proxy/app to become active
echo -e "${BLUE}🏥 Checking system health...${NC}"
for i in {1..12}; do
  sleep 5
  if curl -sf -H "Host: ${DOMAIN}" http://127.0.0.1/ >/dev/null 2>&1 || \
     curl -sf -k https://127.0.0.1/ >/dev/null 2>&1; then
    echo -e "${GREEN}✓ JaanOS is responding.${NC}"
    break
  fi
  echo "Waiting for services... (Attempt $i/12)"
  if [ "$i" -eq 12 ]; then
    echo -e "${RED}⚠️ Startup health check timed out. Please check container logs with 'docker compose logs'.${NC}"
  fi
done

echo "================================================="
echo -e "${GREEN}🎉 JaanOS Core is running!${NC}"
echo -e "Access it here: ${BLUE}https://${DOMAIN}${NC}"
echo "================================================="
