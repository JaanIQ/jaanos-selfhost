# JaanOS Core — Kostenloses, self-hosted EU-ERP

JaanOS ist ein modernes, minimales Dashboard und Interface für Tryton ERP und Lexware Office. Diese Distribution ermöglicht es Ihnen, den JaanOS Core schnell und einfach als souveränen Reverse-Proxy-Stack auf Ihrem eigenen Linux-VPS zu betreiben.

> [!IMPORTANT]
> **Lizenzierung & Open-Source-Status:**
> JaanOS Core ist **kostenlos nutzbar, aber nicht Open Source** (proprietär). Die Nutzung erfolgt im Rahmen der beiliegenden Endbenutzer-Lizenzvereinbarung (EULA). Weiterverkauf, kommerzieller Vertrieb sowie Reverse Engineering sind untersagt.

---

## ⚡ Ein-Zeilen-Installation

Führen Sie das folgende Kommando auf einem frischen Linux-Server (Ubuntu/Debian empfohlen) mit Root-Rechten aus:

```bash
curl -fsSL https://jaanos.com/install.sh | bash
```

### ⚙️ Voraussetzungen
- Ein Linux-Server (VPS) mit einer öffentlichen IPv4-Adresse (mindestens 2 GB RAM empfohlen).
- Offene Ports: `80` (HTTP) und `443` (HTTPS).
- **Eine eigene Domain ist optional.** Ohne Domain vergibt der Installer automatisch eine kostenlose Adresse über sslip.io (z. B. `https://203-0-113-10.sslip.io`) — mit echtem SSL-Zertifikat, ganz ohne DNS-Einrichtung. Eine eigene Domain (A-Record auf die Server-IP) können Sie jederzeit nachrüsten: `bash install.sh --domain ihre-domain.de`.

---

## 🔄 Automatische Updates & Wartung

Die Instanz aktualisiert sich standardmäßig vollautomatisch über **Watchtower**. Watchtower prüft im Hintergrund (alle 24 Stunden) auf neue Images in der GitHub Container Registry (GHCR), lädt diese herunter und erstellt den Container neu.

* **Daten & Keys bleiben erhalten:** Da Konfigurationen (wie der `ENCRYPTION_KEY` und das Datenbank-Passwort) aus der persistenten `.env`-Datei gelesen werden und die Daten in Docker-Volumes liegen, bleiben alle Keys und Datenbank-Inhalte beim automatischen Update unverändert und sicher.
* **Automatische Migrationen:** Neue Datenbank-Migrationen werden durch `RUN_MIGRATIONS_ON_BOOT=true` beim Start des aktualisierten Containers automatisch angewendet.

Falls Sie ein manuelles Update erzwingen oder die Konfiguration neu einlesen möchten, führen Sie einfach das Installationsskript erneut aus:

```bash
bash install.sh
```

---

## 💾 Backups (Ihre Verantwortung)

Beim Self-Hosting liegt die Datensicherung in Ihrer Hand (siehe Nutzungsbedingungen). Zu sichern sind **zwei Dinge** — beide liegen unter `/opt/jaanos`:

1. **Die Datenbank** (alle Verbindungen, Einstellungen, Verlauf):

```bash
docker exec jaanos-db pg_dump -U jaanos jaanos > /opt/jaanos/backup_$(date +%F).sql
```

2. **Die `.env`-Datei** (enthält den `ENCRYPTION_KEY`):

```bash
cp /opt/jaanos/.env /opt/jaanos/env_backup_$(date +%F)
```

> [!WARNING]
> **Ohne den originalen `ENCRYPTION_KEY` ist ein Datenbank-Backup nur eingeschränkt nutzbar** — die verschlüsselten Zugangsdaten (ERP-Verbindungen, API-Keys) können dann nicht mehr entschlüsselt werden und müssten neu hinterlegt werden. Sichern Sie `.env` und Datenbank daher immer **zusammen** und bewahren Sie beide an einem sicheren Ort **außerhalb des Servers** auf.

**Wiederherstellung** auf einem frischen Server: Installer ausführen, dann die gesicherte `.env` nach `/opt/jaanos/.env` zurückkopieren, `bash install.sh` erneut ausführen und den SQL-Dump einspielen:

```bash
docker exec -i jaanos-db psql -U jaanos jaanos < backup_JJJJ-MM-TT.sql
```

Tipp: Automatisieren Sie das Datenbank-Backup per Cronjob (z. B. täglich) und rotieren Sie alte Dumps.

---

## 🗑️ Vollständiges Entfernen (Deinstallation)

Kein Lock-in — auch das Gehen ist nur ein paar Befehle. Möchten Sie Ihre Daten behalten, erstellen Sie **zuerst ein Backup** (siehe oben).

```bash
cd /opt/jaanos
docker compose down          # stoppt alle JaanOS-Container (Daten bleiben erhalten)
docker compose down -v       # stoppt UND löscht die Daten-Volumes (unwiderruflich!)
cd / && rm -rf /opt/jaanos   # entfernt Konfiguration inkl. .env und Schlüssel
```

Docker selbst bleibt dabei installiert (wird evtl. von anderen Anwendungen genutzt); bei Bedarf entfernen Sie es über die Paketverwaltung Ihres Systems. Damit ist JaanOS rückstandsfrei vom Server entfernt.

---

## 📄 EULA & Lizenz

Durch die Installation und Nutzung von JaanOS stimmen Sie den Bedingungen der [EULA.md](EULA.md) zu.

---

## 📚 Dokumentation / Documentation

Detaillierte Anleitungen für die Einrichtung und Verwaltung von JaanOS Core:

### Deutsch (DE)
* [01 - Installation & Voraussetzungen](docs/de/01-installation.md)
* [02 - Erste Schritte & ERP-Anbindung](docs/de/02-erste-schritte.md)
* [03 - KI-Schlüssel & BYOK](docs/de/03-ki-schluessel.md)
* [04 - Tägliche Nutzung & Grenzen](docs/de/04-taegliche-nutzung.md)
* [05 - Updates & Wartung](docs/de/05-updates.md)
* [06 - Backups & Wiederherstellung](docs/de/06-backup.md)
* [07 - Fehlerbehebung & Logs](docs/de/07-fehlerbehebung.md)
* [08 - Sicherheit & Datenschutz](docs/de/08-sicherheit.md)

### English (EN)
* [01 - Installation & Requirements](docs/en/01-installation.md)
* [02 - Getting Started & ERP Connection](docs/en/02-erste-schritte.md)
* [03 - AI Keys & BYOK](docs/en/03-ki-schluessel.md)
* [04 - Daily Usage & Limitations](docs/en/04-taegliche-nutzung.md)
* [05 - Updates & Maintenance](docs/en/05-updates.md)
* [06 - Backup & Restore](docs/en/06-backup.md)
* [07 - Troubleshooting & Logs](docs/en/07-fehlerbehebung.md)
* [08 - Security & Privacy](docs/en/08-sicherheit.md)

