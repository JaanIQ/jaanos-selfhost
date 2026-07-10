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

### 📦 Komplettpaket mit integriertem Tryton ERP (empfohlen)
Der Installer bietet Ihnen interaktiv an, ein vorkonfiguriertes, lokales Tryton ERP mitzuinstallieren:
* **Sicherheit:** Das Tryton ERP ist **nicht** öffentlich erreichbar, sondern läuft ausschließlich im geschützten Docker-Netzwerk. Nur JaanOS kommuniziert direkt mit ihm.
* **Ersteinrichtung:** Die Datenbank und Module (u. a. SKR03-Kontenrahmen und Steuerschlüssel) werden vollautomatisch beim ersten Start eingerichtet (ca. 2-3 Minuten).
* **Automatisierung:** Nutzen Sie `--with-tryton` oder `--no-tryton` beim Aufruf des Installers, um die interaktive Abfrage zu überspringen.
* **Tryton direkt öffnen (optional):** Sie können Tryton über einen frei wählbaren Host-Port (Standard: `8069`) freigeben, um direkt auf den Sao-Web-Client oder den Desktop-Gtk-Client zuzugreifen. Verwenden Sie hierzu das Flag `--expose-tryton [PORT]` (z. B. `--expose-tryton 8069`) bzw. interaktiv die Bestätigung. Zum Deaktivieren nutzen Sie `--no-expose-tryton`. ⚠️ **Sicherheitshinweis:** Ein offener Port erhöht die Angriffsfläche. Standardmäßig läuft Tryton sicher nur intern. Details und Login-Informationen finden Sie in der [Installationsanleitung](docs/de/01-installation.md#tryton-direkt-offnen-optional).



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

1. **Die Datenbanken** (alle Verbindungen, Einstellungen, Verlauf sowie das integrierte Tryton ERP):

```bash
# Sichern der JaanOS-Konfigurationsdatenbank
docker exec jaanos-db pg_dump -U jaanos jaanos > /opt/jaanos/backup_jaanos_$(date +%F).sql

# Sichern der Tryton ERP-Datenbank (falls integriertes Tryton genutzt wird)
docker exec jaanos-db pg_dump -U jaanos tryton > /opt/jaanos/backup_tryton_$(date +%F).sql 2>/dev/null || true
```

2. **Die `.env`-Datei** (enthält den `ENCRYPTION_KEY`):

```bash
cp /opt/jaanos/.env /opt/jaanos/env_backup_$(date +%F)
```

> [!WARNING]
> **Ohne den originalen `ENCRYPTION_KEY` ist ein Datenbank-Backup nur eingeschränkt nutzbar** — die verschlüsselten Zugangsdaten (ERP-Verbindungen, API-Keys) können dann nicht mehr entschlüsselt werden und müssten neu hinterlegt werden. Sichern Sie `.env` und die Datenbank-Dumps daher immer **zusammen** und bewahren Sie beide an einem sicheren Ort **außerhalb des Servers** auf.

**Wiederherstellung** auf einem frischen Server: Installer ausführen, dann die gesicherte `.env` nach `/opt/jaanos/.env` zurückkopieren, `bash install.sh` erneut ausführen (um die Container zu stoppen/starten und den Key einzulesen), und die SQL-Dumps einspielen:

```bash
# JaanOS-Datenbank wiederherstellen
docker exec -i jaanos-db psql -U jaanos jaanos < backup_jaanos_JJJJ-MM-TT.sql

# Tryton ERP-Datenbank wiederherstellen (falls integriertes Tryton genutzt wird)
docker exec -i jaanos-db psql -U jaanos tryton < backup_tryton_JJJJ-MM-TT.sql 2>/dev/null || true
```

Tipp: Automatisieren Sie die Datenbank-Backups per Cronjob (z. B. täglich) und rotieren Sie alte Dumps.

---

## 🗑️ Vollständiges Entfernen (Deinstallation)

Kein Lock-in — auch das Gehen ist nur ein paar Befehle. Möchten Sie Ihre Daten behalten, erstellen Sie **zuerst ein Backup** (siehe oben).

```bash
cd /opt/jaanos
docker compose down          # stoppt alle JaanOS-Container (Daten bleiben erhalten)
docker compose down -v --remove-orphans       # stoppt UND löscht die Daten-Volumes (unwiderruflich!)
cd / && rm -rf /opt/jaanos   # entfernt Konfiguration inkl. .env und Schlüssel
```

> [!NOTE]
> Meldet `docker network rm` einen Fehler wie `network has active endpoints`, hat sich ein **fremder** Container (aus einem anderen Projekt auf dem Server) mit dem Netz verbunden. Trennen Sie ihn — **löschen Sie ihn nicht**:
> ```bash
> docker network inspect jaanos_default --format '{{range .Containers}}{{.Name}} {{end}}'
> docker network disconnect jaanos_default <fremder-container-name>
> ```

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

