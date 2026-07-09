# Installation

Diese Anleitung beschreibt die Systemvoraussetzungen, die Funktionsweise des Installationsskripts sowie die manuelle Anpassung von JaanOS Core auf Ihrer eigenen Serverinfrastruktur.

## Voraussetzungen

Bevor Sie mit der Installation beginnen, stellen Sie sicher, dass Ihr Server folgende Voraussetzungen erfüllt:
* **Betriebssystem:** Ein frischer Linux-Server (Ubuntu oder Debian empfohlen).
* **Systemressourcen:** Mindestens 2 GB Arbeitsspeicher (RAM) werden empfohlen.
* **Netzwerk:** Eine öffentliche IPv4-Adresse.
* **Firewall / Offene Ports:** Die Ports `80` (HTTP) und `443` (HTTPS) müssen für eingehenden Datenverkehr geöffnet sein.
* **Domain (optional):** Eine eigene, auf die Server-IP zeigende Domain oder Subdomain ist **nicht erforderlich** — ohne Domain vergibt der Installer automatisch eine funktionierende Adresse (siehe unten). Eine eigene Domain können Sie jederzeit nachrüsten.

### Ohne eigene Domain: der automatische sslip.io-Fallback
Drücken Sie bei der Domain-Abfrage einfach **ENTER**. Der Installer ermittelt dann die öffentliche IP-Adresse Ihres Servers und verwendet automatisch eine Adresse der Form `[IP-MIT-BINDESTRICHEN].sslip.io` (Beispiel: `203-0-113-10.sslip.io`). Die DNS-Auflösung von sslip.io leitet Zugriffe automatisch an Ihren Server weiter, sodass Caddy ein gültiges Let's-Encrypt-SSL-Zertifikat ausstellen kann — ganz ohne DNS-Einrichtung. Auf eine eigene Domain wechseln Sie später jederzeit mit: `bash install.sh --domain ihre-domain.de`.

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
4. **Domain-Konfiguration abfragen:** Falls kein `--domain`-Parameter übergeben wurde, prüft das Skript, ob bereits eine `.env` mit eingetragener Domain existiert. Andernfalls fragt es interaktiv nach der Domain — drücken Sie einfach **ENTER**, ermittelt das Skript die öffentliche IP Ihres Servers (über api.ipify.org bzw. ifconfig.me) und verwendet automatisch die Adresse `[IP-MIT-BINDESTRICHEN].sslip.io`.
5. **Geheimnisse generieren:** Falls keine `.env`-Datei vorhanden ist, erstellt das Skript diese neu und generiert kryptografisch sichere Zufallswerte für:
   * `POSTGRES_PASSWORD` (Passwort für die lokale PostgreSQL-Datenbank)
   * `ENCRYPTION_KEY` (AES-256-Schlüssel zur Verschlüsselung von ERP-Zugangsdaten)
   * `AUTH_SECRET` (Sicherheitsschlüssel für Anmeldesitzungen)
   Die Dateirechte der `.env` werden per `chmod 600` geschützt.
6. **Container starten:** Zieht die neuesten Docker-Images (`ghcr.io/vibebuild-ai/jaanos/suite:latest`, `postgres:16-alpine`, `caddy:2-alpine` und `containrrr/watchtower`) und startet den Stack im Hintergrund mittels `docker compose up -d`.
7. **Systemprüfung:** Das Skript führt bis zu 12 Healthchecks durch (Intervall: 5 Sekunden), um festzustellen, ob das Dashboard antwortet. Bei erfolgreicher Antwort gibt es die Zugriffs-URL (`https://[DOMAIN]`) aus.


---

## Testen auf einem bereits genutzten Server (Port-Modus)

Läuft auf Ihrem Server bereits ein Webserver (nginx, Apache, Caddy), sind die Ports 80/443 belegt. Der Installer **erkennt das automatisch** und bietet den Test-Modus an — JaanOS läuft dann auf einem eigenen Port, ohne die bestehenden Dienste zu berühren:

```bash
curl -fsSL https://jaanos.com/install.sh | bash -s -- --port 8321
```

* Erreichbar unter `http://[SERVER-IP]:8321` — **ohne SSL** (Let's Encrypt benötigt Port 80/443). Der Port-Modus ist zum **Testen** gedacht, nicht für den Dauerbetrieb über das offene Internet.
* Es wird kein Caddy gestartet; alle Container, Volumes und Dateien bleiben unter `/opt/jaanos` isoliert.
* Rückstandsfrei entfernen: `cd /opt/jaanos && docker compose down -v && cd / && rm -rf /opt/jaanos` — die bestehenden Dienste laufen unverändert weiter.
* Ein erneuter Aufruf des Installers behält den Port-Modus bei (in der `.env` als `INSTALL_MODE=port` gespeichert).

### Für Fortgeschrittene: hinter Ihrem bestehenden nginx betreiben

Sie können JaanOS im Port-Modus dauerhaft betreiben, indem Ihr vorhandener Webserver die Anfragen weiterleitet und das SSL-Zertifikat übernimmt (z. B. via certbot). Beispiel-Serverblock:

```nginx
server {
    server_name jaanos.ihre-domain.de;
    location / {
        proxy_pass http://127.0.0.1:8321;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
    }
}
```

Die Konfiguration und Zertifikatsverwaltung liegt in diesem Fall bei Ihnen.
