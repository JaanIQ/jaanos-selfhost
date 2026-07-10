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

* Erreichbar unter `http://[SERVER-IP]:8321`. Die Installation ist **vollwertig und dauerhaft** (Daten, automatische Updates — alles wie im Standard-Modus). Es fehlt nur SSL: Let's Encrypt benötigt Port 80/443, die Ihr bestehender Webserver hält. Für den Zugriff über das offene Internet schließen Sie daher den HTTPS-Schritt ab (siehe unten) — **ein Schritt, kein Neuaufsetzen**. Der Installer legt dafür eine fertige Vorlage mit dem gewählten Port unter `/opt/jaanos/nginx-jaanos.conf.example` ab.
* Es wird kein Caddy gestartet; alle Container, Volumes und Dateien bleiben unter `/opt/jaanos` isoliert.
* Rückstandsfrei entfernen: `cd /opt/jaanos && docker compose down -v --remove-orphans && cd / && rm -rf /opt/jaanos` — die bestehenden Dienste laufen unverändert weiter.
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

---

## Komplettpaket mit integriertem Tryton ERP

JaanOS Core kann optional mit einem vorkonfigurierten, lokalen Tryton ERP als Komplettpaket in einem Schritt installiert werden.

* **Was es ist:** Der Installer stellt neben JaanOS auch eine eigene, isolierte Instanz von Tryton ERP auf demselben Server bereit.
* **Netzwerk-Sicherheit:** Die Tryton-Dienste sind **nicht** öffentlich über das Internet erreichbar. Sie laufen ausschließlich im internen, isolierten Docker-Netzwerk (`jaanos-net`). Ausschließlich JaanOS kommuniziert direkt mit Tryton, was die Angriffsfläche gegen Angriffe aus dem Netz auf null reduziert.
* **Dauer der Ersteinrichtung:** Die erste Bereitstellung der Datenbank und aller Module (inklusive des deutschen SKR03-Kontenrahmens und Steuerschlüsseln) dauert beim ersten Start ca. **2 bis 3 Minuten**.
* **Automatisierung / Flags:**
  Sie können die interaktive Abfrage für das integrierte Tryton überspringen, indem Sie folgende Parameter übergeben:
  * `--with-tryton`: Installiert das Komplettpaket mit Tryton ERP direkt.
  * `--no-tryton`: Installiert ausschließlich JaanOS ohne lokales ERP.

### Tryton direkt öffnen (optional)

Für Entwickler oder fortgeschrittene Administratoren besteht die Möglichkeit, einen direkten, öffentlichen Zugang zum mitgelieferten Tryton ERP freizugeben. Standardmäßig ist dieser Port geschlossen und Tryton läuft nur intern im geschützten Docker-Netzwerk.

* **Was es ist:** Wenn Sie den Port freigeben, serviert der Tryton-Container bei Zugriff über den Browser direkt den offiziellen Sao-Web-Client. Ein Zugriff über den nativen Tryton-Desktop-Client (Gtk) gegen denselben Port ist ebenfalls möglich.
* **Kein Lock-in:** Es handelt sich um ein absolut unverändertes Standard-Tryton, das auf einer Standard-PostgreSQL-Datenbank läuft. Sie haben vollen Zugriff und können Ihre Daten jederzeit exportieren.
* **Aktivierung:** 
  * Nutzen Sie beim Aufruf des Installers das Flag `--expose-tryton [PORT]` (z. B. `--expose-tryton 8069`).
  * Ohne Flag fragt der Installer interaktiv nach, ob Tryton freigegeben werden soll (Standard: Nein). Der Standard-Port ist `8069`.
  * Deaktivieren können Sie die Freigabe über das Flag `--no-expose-tryton`.
* **Login-Daten:**
  * **Benutzer:** `admin`
  * **Passwort:** Zu finden in `/opt/jaanos/.env` unter dem Key `BUNDLED_TRYTON_ADMIN_PASSWORD`.
  * **Datenbank:** `tryton` (muss im Login-Dialog ausgewählt/eingegeben werden).
* **⚠️ Sicherheitshinweis:**
  Ein direkt geöffneter Port stellt eine zusätzliche Angriffsfläche im Internet dar. Die Verbindung erfolgt standardmäßig unverschlüsselt (HTTP). Verwenden Sie diesen direkten Port nur für temporäre Testzwecke oder im lokalen Netzwerk. Für den dauerhaften Betrieb im Internet wird dringend empfohlen, den Port geschlossen zu halten (Zugriff nur über JaanOS) oder den Port mit SSL abzusichern, indem Sie ihn hinter Ihren bestehenden Webserver (z. B. nginx) als Reverse-Proxy legen (siehe nginx-Vorlage).

