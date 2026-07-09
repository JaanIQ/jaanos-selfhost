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

JaanOS Core enthält **keinerlei Telemetriefunktionen, Call-Home-Verbindungen oder Tracking-Skripte**.
* **Keine Nutzungsdaten:** Es werden keine Statistiken über Ihr Nutzungsverhalten, die Anzahl der Benutzer oder die Auslastung Ihres Systems an JaanIQ übermittelt.
* **Netzwerk-Transparenz:** Die Anwendung baut nur ausgehende Verbindungen zu den von Ihnen explizit konfigurierten Datenquellen (z. B. Tryton ERP) und den KI-API-Endpunkten auf.

---

## Datennutzung im Kontext von KI (Kein Modelltraining)

Ein zentraler Sicherheitsaspekt von JaanOS Core betrifft den Schutz Ihrer vertraulichen Finanz- und Kundendaten bei der Verwendung von künstlicher Intelligenz:

* **Bring Your Own Key (BYOK):** Durch die Nutzung Ihrer eigenen API-Schlüssel sind Sie Vertragspartner des jeweiligen KI-Providers.
* **Kein unbefugtes Training:** Die führenden API-Anbieter (wie Google Vertex AI, Anthropic API, OpenAI API für kommerzielle Zwecke) garantieren in ihren Enterprise-Richtlinien, dass über APIs übermittelte Daten **nicht** zum Trainieren öffentlicher Modelle verwendet werden.
* **Geografische Kontrolle (EU-Hosting):** Sie können gezielt Provider wählen, die eine Datenverarbeitung innerhalb der Europäischen Union garantieren (z. B. Google Vertex AI mit dem Standort Frankfurt oder Mistral AI mit dem Standort Paris). Dadurch bleibt die DSGVO-Konformität vollständig gewahrt.
* **100% Offline-Betrieb (Ollama):** Für maximale Datensicherheit können Sie JaanOS Core komplett offline betreiben, indem Sie eine lokale Ollama-Instanz in Ihrem Intranet anbinden. In diesem Fall verlässt kein einziges Byte Ihr internes Netzwerk.
