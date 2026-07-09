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
- Eine auf die IP-Adresse des Servers zeigende Domain oder Subdomain (wird für automatische Let's Encrypt SSL-Zertifikate benötigt).
- Offene Ports: `80` (HTTP) und `443` (HTTPS).

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

## 📄 EULA & Lizenz

Durch die Installation und Nutzung von JaanOS stimmen Sie den Bedingungen der [EULA.md](EULA.md) zu.
