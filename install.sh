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

# 1. Check/Install Docker and Compose
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

# 2. Get Domain Configuration
if [ -z "$DOMAIN" ]; then
  if [ -f .env ]; then
    # Extract domain from existing .env
    DOMAIN=$(grep -E "^DOMAIN=" .env | cut -d'=' -f2- | tr -d '"' | tr -d "'")
  fi
  
  if [ -z "$DOMAIN" ]; then
    read -rp "Please enter your domain (e.g. jaanos.example.com): " DOMAIN
  fi
fi

if [ -z "$DOMAIN" ]; then
  echo -e "${RED}Error: Domain is required.${NC}"
  exit 1
fi

# Clean domain name input
DOMAIN=$(echo "$DOMAIN" | tr -d ' ' | tr -d '"' | tr -d "'")

# 3. Generate .env values securely if not exists
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

# 4. Pull and launch the stack
echo -e "${BLUE}📥 Pulling latest Docker images...${NC}"
docker compose pull

echo -e "${BLUE}♻️ Starting containers...${NC}"
docker compose up -d

# 5. Wait for proxy/app to become active
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
