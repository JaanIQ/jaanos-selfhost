# Installation

This guide describes the system requirements, the functionality of the installation script, and manual configuration options for JaanOS Core on your own server infrastructure.

## Requirements

Before beginning the installation, ensure your server meets the following requirements:
* **Operating System:** A clean Linux server (Ubuntu or Debian recommended).
* **System Resources:** At least 2 GB of RAM is recommended.
* **Network:** A public IPv4 address.
* **Firewall / Open Ports:** Ports `80` (HTTP) and `443` (HTTPS) must be open for inbound traffic.
* **Domain:** A domain or subdomain pointing to the server's public IP address (required for the automatic Let's Encrypt SSL certificate).

### Fallback Domain (sslip.io)
If you do not own a registered domain or want to test the system first, you can use a wildcard domain from `sslip.io`. Use your public IP address in the following format:
`[YOUR-SERVER-IP].sslip.io` (e.g., `192.0.2.1.sslip.io`). The DNS resolution automatically routes requests to your server, allowing Caddy to issue a valid SSL certificate.

---

## One-Line Installer

Execute the following command as a root user on your server:

```bash
curl -fsSL https://jaanos.com/install.sh | bash
```

### Optional Parameters
You can supply the desired domain directly as an argument to bypass the interactive prompt:

```bash
curl -fsSL https://jaanos.com/install.sh | bash -s -- --domain jaanos.your-domain.com
```

---

## How the Installation Script Works (Step-by-Step)

The installation script performs the following actions sequentially:

1. **Create Workspace Directory:** It creates the directory `/opt/jaanos` on your server and navigates into it. All configuration files and persistent data volumes are managed here.
2. **Download Configuration Files:** It downloads the current versions of `docker-compose.yml` and `Caddyfile` from the GitHub repository.
3. **Verify Docker Environment:** It checks if Docker and the Docker Compose plugin are installed. If Docker is missing, it is automatically installed using the official script from `https://get.docker.com`. The script verifies that the Compose plugin is active (it will exit if it is missing).
4. **Retrieve Domain Configuration:** If the `--domain` parameter was not provided, the script checks if an existing `.env` file contains a configured domain. Otherwise, it prompts you interactively to enter your domain.
5. **Generate Secrets:** If no `.env` file exists, the script creates a new one and generates cryptographically secure random values for:
   * `POSTGRES_PASSWORD` (password for the local PostgreSQL database)
   * `ENCRYPTION_KEY` (AES-256 key used to encrypt ERP credentials)
   * `AUTH_SECRET` (security key for authentication sessions)
   File permissions of `.env` are protected via `chmod 600`.
6. **Start Containers:** Pulls the latest Docker images (`ghcr.io/vibebuild-ai/jaanos/suite:latest`, `postgres:16-alpine`, `caddy:2-alpine`, and `containrrr/watchtower`) and starts the stack in the background using `docker compose up -d`.
7. **System Health Check:** The script performs up to 12 health checks (5-second intervals) to verify if the dashboard is responding. Upon a successful response, it prints the access URL (`https://[DOMAIN]`).
