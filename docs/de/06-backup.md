# Backups & Wiederherstellung

Eine regelmäßige Datensicherung ist essenziell. Da JaanOS Core sensible ERP-Zugangsdaten verschlüsselt speichert, müssen das Datenbank-Backup und die Konfigurationsdatei stets zusammen gesichert werden.

## Die kritische .env-Warnung

> [!WARNING]
> **Sichern Sie immer die `.env`-Datei zusammen mit der Datenbank!**
> Die Datei `/opt/jaanos/.env` enthält den `ENCRYPTION_KEY` (AES-256-Schlüssel). Mit diesem Schlüssel werden alle ERP-Passwörter, Lexware-Tokens und API-Keys in der PostgreSQL-Datenbank verschlüsselt.
> Wenn Sie ein Datenbank-Backup wiederherstellen, aber den ursprünglichen `ENCRYPTION_KEY` aus der `.env` verlieren, sind alle wiederhergestellten Zugangsdaten unbrauchbar, da sie nicht mehr entschlüsselt werden können.

---

## Backup erstellen

Ein vollständiges Backup besteht aus zwei Teilen:
1. Der Konfigurationsdatei `.env`.
2. Einem SQL-Dump der PostgreSQL-Datenbank.

Führen Sie folgende Befehle aus, um das Backup manuell zu erstellen:

```bash
# 1. Verzeichnis für Backups erstellen und wechseln
mkdir -p /opt/jaanos/backups
cd /opt/jaanos

# 2. Datenbank-Dump erstellen
docker compose exec db pg_dump -U jaanos -d jaanos > backups/jaanos_db_$(date +%F).sql

# 3. .env-Datei kopieren
cp .env backups/jaanos_env_$(date +%F).env
```

Sichern Sie die erzeugten Dateien im Ordner `/opt/jaanos/backups` anschließend auf ein externes Medium.

---

## Wiederherstellung (Restore-Schritt-für-Schritt)

Um ein Backup auf einem neuen oder zurückgesetzten Server einzuspielen, gehen Sie wie folgt vor:

### 1. Umgebung vorbereiten
Installieren Sie JaanOS wie gewohnt über das Installationsskript. Dadurch werden die Verzeichnisse und standardmäßigen Docker-Dienste angelegt:

```bash
curl -fsSL https://jaanos.com/install.sh | bash
```

### 2. Dienste stoppen
Stoppen Sie den Anwendungs-Container, damit während des Restores keine Schreibzugriffe erfolgen:

```bash
cd /opt/jaanos
docker compose stop jaanos-suite
```

### 3. Konfiguration (.env) wiederherstellen
Ersetzen Sie die neu generierte `.env`-Datei durch Ihre gesicherte `.env`-Datei (die den ursprünglichen `ENCRYPTION_KEY` enthält):

```bash
cp /pfad/zu/ihrem/backup/jaanos_env_[DATUM].env /opt/jaanos/.env
chmod 600 /opt/jaanos/.env
```

### 4. Datenbank-Dump einspielen
Löschen Sie die neu angelegte, leere Datenbank und spielen Sie das Backup ein:

```bash
# Bestehende Datenbank leeren und neu erstellen
docker compose exec db dropdb -U jaanos jaanos
docker compose exec db createdb -U jaanos jaanos

# Dump einspielen
cat /pfad/zu/ihrem/backup/jaanos_db_[DATUM].sql | docker compose exec -T db psql -U jaanos -d jaanos
```

### 5. Anwendung starten
Starten Sie die Anwendung wieder. Durch das Laden der alten `.env` und der Datenbank ist das System sofort wieder im Zustand des Backups einsatzbereit:

```bash
docker compose start jaanos-suite
```

---

## Cron-Beispiel für automatische Backups

Um jede Nacht um 03:00 Uhr automatisch ein Backup zu erstellen, können Sie einen Cron-Job einrichten.

1. Öffnen Sie die Crontab des Root-Benutzers:
   ```bash
   sudo crontab -e
   ```
2. Fügen Sie folgende Zeile hinzu (passen Sie den Pfad für externe Sicherung an):
   ```cron
   0 3 * * * cd /opt/jaanos && docker compose exec -T db pg_dump -U jaanos -d jaanos > /opt/jaanos/backups/jaanos_db_$(date +\%F).sql && cp /opt/jaanos/.env /opt/jaanos/backups/jaanos_env_$(date +\%F).env
   ```
