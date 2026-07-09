# Backup & Restore

Regular backups are essential. Because JaanOS Core stores encrypted ERP connection credentials, the database dump and the environment configuration file must always be backed up together.

## The Critical .env Warning

> [!WARNING]
> **Always back up your `.env` file along with the database!**
> The file `/opt/jaanos/.env` contains the `ENCRYPTION_KEY` (AES-256 key). This key is used to encrypt all ERP credentials, Lexware API tokens, and custom API keys inside the PostgreSQL database.
> If you restore a database dump but lose the original `ENCRYPTION_KEY` from the `.env` file, all restored credentials will be rendered useless because the application will be unable to decrypt them.

---

## Creating a Backup

A complete backup consists of two parts:
1. The configuration file `.env`.
2. A SQL dump of the PostgreSQL database.

Execute the following commands to create a backup manually:

```bash
# 1. Create backup directory
mkdir -p /opt/jaanos/backups
cd /opt/jaanos

# 2. Export database dump
docker compose exec db pg_dump -U jaanos -d jaanos > backups/jaanos_db_$(date +%F).sql

# 3. Copy .env file
cp .env backups/jaanos_env_$(date +%F).env
```

Move the generated backup files from `/opt/jaanos/backups` to an external secure storage device.

---

## Restoring a Backup (Step-by-Step)

To restore a backup to a clean or reset server, follow these steps:

### 1. Prepare Environment
Install JaanOS using the official installation script. This sets up the directory layout and default Docker compose services:

```bash
curl -fsSL https://jaanos.com/install.sh | bash
```

### 2. Stop Services
Stop the main application container to prevent write requests during the restore:

```bash
cd /opt/jaanos
docker compose stop jaanos-suite
```

### 3. Restore Configuration (.env)
Replace the newly generated `.env` file with your backed-up `.env` file containing the original `ENCRYPTION_KEY`:

```bash
cp /path/to/your/backup/jaanos_env_[DATE].env /opt/jaanos/.env
chmod 600 /opt/jaanos/.env
```

### 4. Restore Database Dump
Drop the clean database created by the installer and restore the SQL dump:

```bash
# Empty existing database and recreate it
docker compose exec db dropdb -U jaanos jaanos
docker compose exec db createdb -U jaanos jaanos

# Import the SQL dump
cat /path/to/your/backup/jaanos_db_[DATE].sql | docker compose exec -T db psql -U jaanos -d jaanos
```

### 5. Start Application
Start the application services. Since the original `.env` and database are in place, the system is immediately ready for use:

```bash
docker compose start jaanos-suite
```

---

## Automating Backups with Cron

To automate backups every night at 3:00 AM, configure a cron job.

1. Open the root user's crontab editor:
   ```bash
   sudo crontab -e
   ```
2. Add the following line (adjust paths as needed for external mounts):
   ```cron
   0 3 * * * cd /opt/jaanos && docker compose exec -T db pg_dump -U jaanos -d jaanos > /opt/jaanos/backups/jaanos_db_$(date +\%F).sql && cp /opt/jaanos/.env /opt/jaanos/backups/jaanos_env_$(date +\%F).env
   ```
