# Installation

This guide describes the system requirements, the functionality of the installation script, and manual configuration options for JaanOS Core on your own server infrastructure.

## Requirements

Before beginning the installation, ensure your server meets the following requirements:
* **Operating System:** A clean Linux server (Ubuntu or Debian recommended).
* **System Resources:** At least 2 GB of RAM is recommended.
* **Network:** A public IPv4 address.
* **Firewall / Open Ports:** Ports `80` (HTTP) and `443` (HTTPS) must be open for inbound traffic.
* **Domain (optional):** A domain of your own pointing to the server IP is **not required** — without one, the installer automatically assigns a working address (see below). You can switch to your own domain at any time.

### Without your own domain: the automatic sslip.io fallback
Simply press **ENTER** at the domain prompt. The installer then detects your server's public IP address and automatically uses an address of the form `[IP-WITH-DASHES].sslip.io` (e.g., `203-0-113-10.sslip.io`). sslip.io's DNS resolution automatically routes requests to your server, allowing Caddy to issue a valid Let's Encrypt SSL certificate — with zero DNS setup. Switch to your own domain later at any time with: `bash install.sh --domain your-domain.com`.

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
4. **Retrieve Domain Configuration:** If the `--domain` parameter was not provided, the script checks if an existing `.env` file contains a configured domain. Otherwise, it prompts you interactively — simply press **ENTER** and the script detects your server's public IP (via api.ipify.org or ifconfig.me) and automatically uses the address `[IP-WITH-DASHES].sslip.io`.
5. **Generate Secrets:** If no `.env` file exists, the script creates a new one and generates cryptographically secure random values for:
   * `POSTGRES_PASSWORD` (password for the local PostgreSQL database)
   * `ENCRYPTION_KEY` (AES-256 key used to encrypt ERP credentials)
   * `AUTH_SECRET` (security key for authentication sessions)
   File permissions of `.env` are protected via `chmod 600`.
6. **Start Containers:** Pulls the latest Docker images (`ghcr.io/vibebuild-ai/jaanos/suite:latest`, `postgres:16-alpine`, `caddy:2-alpine`, and `containrrr/watchtower`) and starts the stack in the background using `docker compose up -d`.
7. **System Health Check:** The script performs up to 12 health checks (5-second intervals) to verify if the dashboard is responding. Upon a successful response, it prints the access URL (`https://[DOMAIN]`).


---

## Installation on a Server with an Existing Web Server (Port Mode)

If a web server (nginx, Apache, Caddy) is already running on your server, ports 80/443 are occupied. The installer **detects this automatically** and sets JaanOS up on its own port — a complete, permanent installation, without touching your existing services:

```bash
curl -fsSL https://jaanos.com/install.sh | bash -s -- --port 8321
```

* Reachable at `http://[SERVER-IP]:8321`. The installation is **full-featured and permanent** (data, automatic updates — everything as in standard mode). Only SSL is missing: Let's Encrypt requires ports 80/443, which your existing web server holds. For access over the open internet, complete the HTTPS step (below) — **one step, no reinstall**. The installer ships a ready template with your chosen port at `/opt/jaanos/nginx-jaanos.conf.example`.
* No Caddy is started; all containers, volumes, and files stay isolated under `/opt/jaanos`.
* Clean removal: `cd /opt/jaanos && docker compose down -v --remove-orphans && cd / && rm -rf /opt/jaanos` — your existing services keep running untouched.
* Re-running the installer keeps port mode (stored in `.env` as `INSTALL_MODE=port`).

### Advanced: running behind your existing nginx

You can run JaanOS in port mode permanently by letting your existing web server forward requests and handle the SSL certificate (e.g. via certbot). Example server block:

```nginx
server {
    server_name jaanos.your-domain.com;
    location / {
        proxy_pass http://127.0.0.1:8321;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
    }
}
```

Configuration and certificate management are your responsibility in this case.

---

## Bundle Mode with Integrated Tryton ERP

JaanOS Core can optionally be installed alongside a pre-configured, local Tryton ERP instance as a complete bundle in a single step.

* **What it is:** The installer provisions a dedicated, isolated instance of Tryton ERP on the same server alongside the JaanOS dashboard.
* **Network Security:** The Tryton services are **not** publicly accessible from the internet. They run entirely within the internal, isolated Docker bridge network (`jaanos-net`). Only JaanOS communicates directly with Tryton, reducing the public network attack surface to zero.
* **Initial Setup Duration:** The initial provisioning of the database and its core modules (including the German SKR03 chart of accounts and tax templates) takes approximately **2 to 3 minutes** during the first boot.
* **Automation / Flags:**
  You can bypass the interactive Tryton prompt by passing one of the following arguments to the installer:
  * `--with-tryton`: Automatically installs the complete bundle with Tryton ERP.
  * `--no-tryton`: Installs only JaanOS without the local Tryton ERP.

### Opening Tryton Directly (Optional)

For developers or advanced administrators, there is an option to expose direct public access to the bundled Tryton ERP instance. By default, this port is closed, and Tryton runs only internally within the secure Docker network.

* **What it is:** When the port is exposed, accessing it via a web browser serves the official Sao web client. Direct connection using the native Tryton desktop client (Gtk) is also supported through the same port.
* **No Lock-in:** This is an unmodified, standard Tryton instance running on a standard PostgreSQL database. You have full ownership and control of your data, with no vendor lock-in.
* **Activation:**
  * Pass the `--expose-tryton [PORT]` flag to the installer (e.g., `--expose-tryton 8069`).
  * If no flag is passed, the installer prompts you interactively (Default: No). The default port is `8069`.
  * You can explicitly disable exposing Tryton using the `--no-expose-tryton` flag.
* **Login Credentials:**
  * **User:** `admin`
  * **Password:** Can be found in `/opt/jaanos/.env` under the `BUNDLED_TRYTON_ADMIN_PASSWORD` key.
  * **Database:** `tryton` (must be selected/entered in the login dialog).
* **⚠️ Security Warning:**
  Exposing this port directly to the internet increases your system's attack surface. By default, the connection is unencrypted (HTTP). Only run this exposed port within a local network or secured behind TLS. For permanent production use, it is highly recommended to keep the port closed (routing all access through JaanOS) or secure the endpoint with SSL by setting up a reverse proxy (e.g., using nginx) behind your web server.


