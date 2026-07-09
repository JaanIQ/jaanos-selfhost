# Updates & Maintenance

JaanOS Core is designed to minimize administrative overhead. The system automatically updates itself and applies pending database schema migrations upon boot.

## Automatic Updates via Watchtower

By default, the update service **Watchtower** is enabled in your `docker-compose.yml` configuration:
* **How It Works:** Watchtower checks every 24 hours (interval: `86400` seconds) if an updated Docker image has been pushed to the GitHub Container Registry (GHCR) for the `jaanos-suite` image.
* **Process:** If a new image is found, Watchtower pulls the image, stops the running container, and recreates it using the same configuration parameters.
* **Benefit:** Security patches and feature improvements are rolled out automatically without manual intervention.

---

## Manual Updates

To force an update immediately or apply changes made to your `.env` configuration file, execute the update manually.

Navigate to your workspace directory (default: `/opt/jaanos`) and run the following commands:

```bash
cd /opt/jaanos
docker compose pull
docker compose up -d
```

Alternatively, re-run the official installation script. It detects your existing installation and performs the update:

```bash
curl -fsSL https://jaanos.com/install.sh | bash
```

---

## Data Preservation Guarantee

During update processes (both manual and automated), your persistent data is safe:
* **Persistent Volumes:** The JaanOS PostgreSQL database resides in a dedicated Docker volume (`postgres_data`). This volume is never deleted or modified when containers are updated or recreated.
* **Configuration Retention:** Because all environment variables and secrets are defined in `/opt/jaanos/.env`, the recreated container reads them upon startup. The critical `ENCRYPTION_KEY` remains intact, ensuring credentials for your ERP connections continue to decrypt successfully.

---

## Automatic Database Migrations on Boot

When a software update changes the database schema of JaanOS Core, the local database tables must be migrated:
* **Automated Migration:** The environment variable `RUN_MIGRATIONS_ON_BOOT=true` is defined in the `docker-compose.yml` configuration.
* **Execution:** Every time the `jaanos-suite` container starts up, the application scans for pending database schema migrations and applies them automatically before serving web traffic. No manual migrations are required.
