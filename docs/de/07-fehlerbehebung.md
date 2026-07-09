# Fehlerbehebung

Diese Anleitung hilft Ihnen, gängige Probleme bei der Installation, DNS-Einrichtung, SSL-Zertifizierung oder ERP-Anbindung selbstständig zu diagnostizieren und zu lösen.

## Gängige Infrastruktur-Fehler

### 1. Ports 80/443 blockiert
Caddy benötigt die Ports `80` (für ACME HTTP-01-Challenges) und `443` (für HTTPS-Verkehr).
* **Symptom:** Die Installation bricht ab, läuft in ein Timeout, oder die Webseite ist im Browser nicht erreichbar.
* **Prüfung:** Führen Sie auf dem Server folgenden Befehl aus, um zu sehen, ob ein anderer Dienst (z. B. Apache oder Nginx) die Ports belegt:
  ```bash
  sudo ss -tulpn | grep -E ':(80|443)'
  ```
* **Lösung:** Stoppen und deaktivieren Sie den blockierenden Webserver oder konfigurieren Sie Ihre Firewall (z. B. `ufw allow 80/tcp` und `ufw allow 443/tcp`).

### 2. DNS-Einträge nicht korrekt oder verzögert
* **Symptom:** Caddy kann kein SSL-Zertifikat von Let's Encrypt beziehen (SSL-Handshake-Fehler im Browser).
* **Prüfung:** Prüfen Sie, ob Ihre Domain korrekt auf die IP des Servers zeigt:
  ```bash
  host jaanos.ihre-domain.de
  ```
* **Lösung:** Stellen Sie sicher, dass der A-Record (und ggf. AAAA-Record) Ihrer Domain auf die korrekte öffentliche IP-Adresse Ihres Servers zeigt. Bei neu registrierten Domains kann die weltweite Verteilung des DNS bis zu 24 Stunden dauern. Nutzen Sie im Zweifel die IP-basierte Fallback-Domain `[IP-ADRESSE].sslip.io`.

### 3. Docker oder Compose-Plugin fehlt
* **Symptom:** Das Skript meldet Fehler beim Ausführen von Docker-Kommandos.
* **Lösung:** Installieren Sie das Docker Compose Plugin nach den offiziellen Docker-Richtlinien Ihrer Distribution (z. B. `apt install docker-compose-plugin`).

---

## Diagnose von Verbindungsproblemen zum ERP

Wenn Sie in den Einstellungen die Verbindung zu Tryton oder Lexware testen, übersetzt JaanOS Fehlermeldungen in konkrete Handlungsempfehlungen:

* **„Verbindung abgelehnt“ (ECONNREFUSED)**
  * **Bedeutung:** Der Ziel-Server verweigert die Annahme der Verbindung.
  * **Lösung:** Prüfen Sie, ob der Tryton-Dienst auf dem Zielserver aktiv läuft und auf dem angegebenen Port lauscht. Standardmäßig lauscht Tryton auf Port `8069` oder `8000`.
* **„Zeitüberschreitung“ (TimeoutError / AbortError)**
  * **Bedeutung:** Die Anfrage wurde nach 5 Sekunden ohne Antwort abgebrochen.
  * **Lösung:** Überprüfen Sie, ob Firewalls (auf Ihrem Server oder dem ERP-Server) den Datenverkehr blockieren oder ob die eingegebene URL falsch ist.
* **„Host nicht gefunden“ (ENOTFOUND / EAI_AGAIN)**
  * **Bedeutung:** Die in der URL angegebene Domain konnte nicht aufgelöst werden.
  * **Lösung:** Prüfen Sie die Schreibweise der Server-URL in den Verbindungseinstellungen.
* **„SSL/TLS-Fehler“**
  * **Bedeutung:** Der sichere Verbindungsaufbau schlug fehl.
  * **Lösung:** Überprüfen Sie das Zertifikat des Tryton-Servers. Ist es abgelaufen? Passt der Name im Zertifikat zur eingegebenen URL? Selbstsignierte Zertifikate ohne vertrauenswürdige CA werden aus Sicherheitsgründen abgewiesen.

---

## Container-Logs analysieren

Die wichtigste Informationsquelle bei Fehlern im laufenden Betrieb sind die Logs der Container. Wechseln Sie in das Installationsverzeichnis (`/opt/jaanos`) und nutzen Sie folgende Befehle:

* **Logs aller Dienste anzeigen:**
  ```bash
  docker compose logs
  ```
* **Logs in Echtzeit mitverfolgen (Follow):**
  ```bash
  docker compose logs -f
  ```
* **Logs der Anwendung (`jaanos-suite`) einsehen:**
  ```bash
  docker compose logs jaanos-suite
  ```
* **Logs der Datenbank (`db`) einsehen:**
  ```bash
  docker compose logs db
  ```
* **Logs des Reverse-Proxys (`caddy`) einsehen:**
  ```bash
  docker compose logs caddy
  ```
  *(Hilfreich bei Problemen mit SSL-Zertifikaten).*
