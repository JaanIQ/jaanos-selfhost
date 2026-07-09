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

## 🔄 Updates & Wartung

Updates können jederzeit durch erneutes Ausführen des Installationsskripts eingespielt werden:

```bash
bash install.sh
```

Hierbei werden automatisch die neuesten Docker-Images heruntergeladen (`docker compose pull`) und die Container neu gestartet. Ihre bestehenden Konfigurationen (wie der `ENCRYPTION_KEY` und das Datenbankpasswort in der `.env`-Datei) sowie alle Daten im Docker-Volume bleiben vollständig unberührt und sicher.

---

## 📄 EULA & Lizenz

Durch die Installation und Nutzung von JaanOS stimmen Sie den Bedingungen der [EULA.md](EULA.md) zu.
