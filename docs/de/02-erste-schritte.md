# Erste Schritte

Nachdem Sie JaanOS erfolgreich installiert haben und der Container aktiv ist, können Sie mit der Ersteinrichtung beginnen.

## Erste Anmeldung (Admin-Registrierung)

Da JaanOS Core im dezentralen Self-Hosted-Modus betrieben wird, ist beim ersten Start kein Standard-Passwort vordefiniert.
1. Rufen Sie die URL Ihrer Instanz im Browser auf (z. B. `https://jaanos.ihre-domain.de`).
2. Sie werden automatisch auf die Einrichtungsseite weitergeleitet.
3. Erstellen Sie das erste Benutzerkonto über die Eingabemaske.
   * **Besonderheit:** Der erste registrierte Benutzer erhält automatisch die administrative Rolle (Admin-Konto) und vollen Zugriff auf das System.
   * **Sicherheit:** Nach der Erstellung des ersten Kontos ist die Registrierungsfunktion für neue administrative Konten gesperrt. Jedes weitere Konto muss durch den bestehenden Administrator freigegeben werden.

---

## Der Einrichtungs-Assistent (First-Boot Setup-Wizard)

Nach der Anmeldung startet der Onboarding-Wizard automatisch. Er führt Sie Schritt für Schritt durch die Konfiguration:
* **Schritt 1: Willkommen** – Begrüßung und Bestätigung des administrativen Status.
* **Schritt 2: ERP-Anbindung** – Verbindung zu Ihrem ERP-Backend (Tryton ERP oder Lexware Office).
* **Schritt 3: Fertig** – Abschluss der Konfiguration und Start des Dashboards.

---

## ERP-Anbindung

JaanOS Core fungiert als intelligentes Interface und benötigt Zugriff auf eine Datenquelle, um Metriken und Aktionen verarbeiten zu können.

### Benötigte Felder je System

#### 1. Tryton ERP
Für die Anbindung einer Tryton-Instanz werden folgende Angaben benötigt:
* **Server-URL:** Die vollständige Adresse Ihres Tryton-Servers (z. B. `http://127.0.0.1:8069` oder `https://tryton.ihre-domain.de`).
* **Datenbankname:** Der exakte Name der PostgreSQL-Datenbank Ihrer Tryton-Instanz.
* **Benutzername & Passwort:** Gültige Anmeldedaten eines Benutzers in Tryton. Die Rechte dieses Benutzers bestimmen die Ausführungsrechte in JaanOS.

#### 2. Lexware Office
Für Lexware Office binden Sie den Service per API-Schlüssel an:
* **API-Key:** Der Autorisierungs-Token (Bearer Token) aus Ihrem Lexware-Entwicklerportal.

---

## Verbindung testen & Fehlerdiagnose

Bei der Einrichtung können Sie die Verbindung über den Button **Verbindung testen** verifizieren. Das System führt eine Testabfrage (JSON-RPC an `common.db.login`) aus und meldet das Ergebnis direkt zurück.

### Diagnosemeldungen und Ursachen

Falls der Verbindungstest fehlschlägt, gibt das System spezifische Diagnosemeldungen aus:

| Fehlermeldung in der Benutzeroberfläche | Technische Ursache & Behebung |
| :--- | :--- |
| **RPC-Endpunkt nicht gefunden (404) — ist die URL korrekt und zeigt sie auf einen Tryton-Server?** | Die URL ist zwar erreichbar, aber unter dem angegebenen Pfad antwortet kein Tryton JSON-RPC-Dienst. Prüfen Sie die URL und den Datenbanknamen. |
| **Der ERP-Server antwortet mit einem Fehler (HTTP [Status]) — Server-Logs prüfen.** | Der Server ist erreichbar, hat aber ein internes Problem (z. B. HTTP 500 oder 503). Prüfen Sie die Logs der Tryton-Instanz. |
| **Unerwartete Antwort (HTTP [Status]).** | Der Server liefert eine nicht standardisierte HTTP-Antwort zurück. |
| **Datenbank existiert nicht — bitte den Datenbank-Namen prüfen.** | Der Tryton-Server läuft, aber die angegebene Datenbank existiert dort nicht. |
| **Zeitüberschreitung — Server nicht erreichbar. Firewall/Port (Tryton meist 8000) und URL prüfen.** | Die Anfrage lief in ein Timeout (5 Sekunden). Prüfen Sie, ob Firewalls den Port blockieren oder der Server offline ist. Tryton nutzt im Standard oft Port `8000` oder `8069`. |
| **Host nicht gefunden — bitte URL/Domain und DNS prüfen.** | Der Hostname konnte nicht aufgelöst werden (`ENOTFOUND`). Kontrollieren Sie die DNS-Einträge und die Schreibweise der Domain. |
| **Verbindung abgelehnt — läuft der ERP-Dienst und ist der Port offen?** | Die Verbindung zum Server wurde aktiv zurückgewiesen (`ECONNREFUSED`). Der Dienst läuft vermutlich nicht oder lauscht auf einem anderen Port. |
| **SSL/TLS-Fehler — Zertifikat der ERP-URL prüfen (gültig? richtiger Hostname?).** | Es konnte keine sichere Verbindung aufgebaut werden. Das Zertifikat des Tryton-Servers ist entweder abgelaufen, selbstsigniert (ohne dass dem Aussteller vertraut wird) oder lautet auf eine andere Domain. |
| **Server nicht erreichbar — URL, Port und Netzwerkverbindung prüfen.** | Allgemeiner Netzwerkfehler beim Verbindungsaufbau. |
