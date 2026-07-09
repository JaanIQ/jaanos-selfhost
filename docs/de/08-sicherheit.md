# Sicherheit und Datenschutz

JaanOS Core wurde nach dem Prinzip „Privacy by Design“ entwickelt. Als selbstgehostete Software behalten Sie die vollständige Souveränität über Ihre Geschäftsdaten und die Art der Verarbeitung.

## Datenspeicherung & Verschlüsselung

### 1. Lokale PostgreSQL-Datenbank
Alle Anwendungsdaten von JaanOS Core werden ausschließlich in der PostgreSQL-Datenbank auf Ihrem Server gespeichert. Es gibt keine Synchronisierung mit externen Cloud-Speichern von JaanIQ.
* **Pfad auf dem Host:** Die Datenbankdateien liegen sicher isoliert im Docker-Volume `postgres_data` (unter `/var/lib/docker/volumes/`).

### 2. Verschlüsselung von Zugangsdaten (AES-256-GCM)
Sämtliche Verbindungsparameter zu Ihren angebundenen ERP-Systemen (wie Passwörter und API-Keys) werden verschlüsselt in der Datenbank abgelegt.
* **Standard:** Es wird der Industriestandard AES-256-GCM verwendet.
* **Schlüsselverwaltung:** Der für die Verschlüsselung genutzte Schlüssel (`ENCRYPTION_KEY`) wird beim ersten Setup im Installationsskript erzeugt und in der Datei `/opt/jaanos/.env` auf Ihrem Server hinterlegt. 
* **Zugriffsschutz:** Die Datei `.env` wird mit den Rechten `600` (nur Lese- und Schreibrechte für den Besitzer/Root) geschützt.

---

## Ausschluss von Telemetrie und Tracking

JaanOS Core enthält **keinerlei Telemetriefunktionen oder Tracking-Skripte** — es werden keine Nutzungs- oder Geschäftsdaten an uns übermittelt. Die einzige regelmäßige ausgehende Verbindung des Stacks ist der Update-Check von Watchtower gegen die öffentliche Container-Registry (kann deaktiviert werden).
* **Keine Nutzungsdaten:** Es werden keine Statistiken über Ihr Nutzungsverhalten, die Anzahl der Benutzer oder die Auslastung Ihres Systems an JaanIQ übermittelt.
* **Netzwerk-Transparenz:** Die Anwendung baut nur ausgehende Verbindungen zu den von Ihnen explizit konfigurierten Datenquellen (z. B. Tryton ERP) und den KI-API-Endpunkten auf.

---

## Datennutzung im Kontext von KI (Kein Modelltraining)

Ein zentraler Sicherheitsaspekt von JaanOS Core betrifft den Schutz Ihrer vertraulichen Finanz- und Kundendaten bei der Verwendung von künstlicher Intelligenz:

* **Bring Your Own Key (BYOK):** Durch die Nutzung Ihrer eigenen API-Schlüssel sind Sie Vertragspartner des jeweiligen KI-Providers.
* **Kein Training durch JaanOS:** JaanOS selbst verwendet Ihre Daten zu keinem Zeitpunkt für KI-Training. Durch BYOK gehen Anfragen ausschließlich an die von Ihnen gewählten Anbieter — deren Umgang mit API-Daten regeln deren jeweilige Nutzungsbedingungen (viele kommerzielle API-Angebote schließen Training auf Kundendaten aus; prüfen Sie die Bedingungen Ihres Anbieters).
* **Geografische Kontrolle (EU-Hosting):** Sie können gezielt Provider wählen, die eine Datenverarbeitung innerhalb der Europäischen Union garantieren (z. B. Google Vertex AI mit dem Standort Frankfurt oder Mistral AI mit dem Standort Paris). Das unterstützt Sie dabei, die DSGVO-Anforderungen an Drittlandstransfers zu erfüllen.
* **Lokale KI-Verarbeitung (Ollama):** Für maximale Datensicherheit binden Sie eine lokale Ollama-Instanz in Ihrem Netz an — die KI-Verarbeitung Ihrer Geschäftsdaten bleibt dann vollständig in Ihrem internen Netzwerk. (Hinweis: Für automatische Updates und SSL-Zertifikate benötigt der Server weiterhin Internetzugang, sofern Sie diese Funktionen nicht deaktivieren.)
