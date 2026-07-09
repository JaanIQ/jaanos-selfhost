# Installation

Diese Anleitung beschreibt die Systemvoraussetzungen, die Funktionsweise des Installationsskripts sowie die manuelle Anpassung von JaanOS Core auf Ihrer eigenen Serverinfrastruktur.

## Voraussetzungen

Bevor Sie mit der Installation beginnen, stellen Sie sicher, dass Ihr Server folgende Voraussetzungen erfüllt:
* **Betriebssystem:** Ein frischer Linux-Server (Ubuntu oder Debian empfohlen).
* **Systemressourcen:** Mindestens 2 GB Arbeitsspeicher (RAM) werden empfohlen.
* **Netzwerk:** Eine öffentliche IPv4-Adresse.
* **Firewall / Offene Ports:** Die Ports `80` (HTTP) und `443` (HTTPS) müssen für eingehenden Datenverkehr geöffnet sein.
* **Domain:** Eine auf die öffentliche IP-Adresse des Servers zeigende Domain oder Subdomain (erforderlich für die Ausstellung des automatischen Let's Encrypt SSL-Zertifikats).

### Fallback-Domain (sslip.io)
Wenn Sie über keine eigene Domain verfügen oder das System vorab testen möchten, können Sie eine Wildcard-Domain von `sslip.io` nutzen. Verwenden Sie dazu Ihre öffentliche IP-Adresse im Format:
`[IHRE-SERVER-IP].sslip.io` (Beispiel: `192.0.2.1.sslip.io`). Die DNS-Auflösung leitet Zugriffe automatisch an Ihren Server weiter, sodass Caddy ein gültiges SSL-Zertifikat ausstellen kann.

---

## Der Ein-Zeiler-Installer

Führen Sie das folgende Kommando als Benutzer mit Root-Rechten auf Ihrem Server aus:

```bash
curl -fsSL https://jaanos.com/install.sh | bash
```

### Optionale Parameter
Sie können die gewünschte Domain auch direkt beim Aufruf als Argument übergeben, um die interaktive Abfrage zu überspringen:

```bash
curl -fsSL https://jaanos.com/install.sh | bash -s -- --domain jaanos.ihre-domain.de
```

---

## Funktionsweise des Installationsskripts (Schritt für Schritt)

Das Installationsskript führt nacheinander folgende Aktionen aus:

1. **Workspace-Verzeichnis anlegen:** Es erstellt das Verzeichnis `/opt/jaanos` auf Ihrem Server und wechselt dorthin. Alle Konfigurationen und persistenten Daten werden dort verwaltet.
2. **Dateien herunterladen:** Es lädt die aktuellen Versionen von `docker-compose.yml` und `Caddyfile` aus dem GitHub-Repository herunter.
3. **Docker-Umgebung prüfen:** Es prüft, ob Docker und das Docker Compose Plugin installiert sind. Falls Docker fehlt, wird es automatisch über das offizielle Skript `https://get.docker.com` installiert. Das Vorhandensein des Compose-Plugins wird überprüft (das Skript bricht ab, falls dieses fehlt).
4. **Domain-Konfiguration abfragen:** Falls kein `--domain`-Parameter übergeben wurde, prüft das Skript, ob bereits eine `.env` mit eingetragener Domain existiert. Andernfalls fordert es Sie interaktiv zur Eingabe der Domain auf.
5. **Geheimnisse generieren:** Falls keine `.env`-Datei vorhanden ist, erstellt das Skript diese neu und generiert kryptografisch sichere Zufallswerte für:
   * `POSTGRES_PASSWORD` (Passwort für die lokale PostgreSQL-Datenbank)
   * `ENCRYPTION_KEY` (AES-256-Schlüssel zur Verschlüsselung von ERP-Zugangsdaten)
   * `AUTH_SECRET` (Sicherheitsschlüssel für Anmeldesitzungen)
   Die Dateirechte der `.env` werden per `chmod 600` geschützt.
6. **Container starten:** Zieht die neuesten Docker-Images (`ghcr.io/vibebuild-ai/jaanos/suite:latest`, `postgres:16-alpine`, `caddy:2-alpine` und `containrrr/watchtower`) und startet den Stack im Hintergrund mittels `docker compose up -d`.
7. **Systemprüfung:** Das Skript führt bis zu 12 Healthchecks durch (Intervall: 5 Sekunden), um festzustellen, ob das Dashboard antwortet. Bei erfolgreicher Antwort gibt es die Zugriffs-URL (`https://[DOMAIN]`) aus.
