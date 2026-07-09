# KI-Schlüssel & BYOK (Bring Your Own Key)

JaanOS Core nutzt ein „Bring Your Own Key“-Modell (BYOK). Das bedeutet, dass Sie Ihre eigenen API-Schlüssel für künstliche Intelligenz mitbringen. 

## Warum BYOK?

* **Volle Kostenkontrolle:** Sie zahlen nur das, was Sie tatsächlich verbrauchen – direkt an den jeweiligen Provider. Es gibt keine Nutzungsgebühren oder versteckten Margen von JaanOS.
* **Datensouveränität:** Sie entscheiden, an welchen Provider Ihre natürlichsprachlichen Anfragen gesendet werden.
* **Flexibilität:** Sie können jederzeit zwischen verschiedenen Anbietern wechseln oder diese parallel betreiben.

---

## Unterstützte KI-Provider & Schnittstellen

JaanOS Core unterstützt die folgenden APIs und Integrationen out-of-the-box:

* **Gemini (Google):** Anbindung an Google AI Studio. Validierung erfolgt über den Endpunkt `gemini-2.5-flash:countTokens`.
* **Mistral AI:** Schnittstelle zu Modellen des europäischen Anbieters Mistral.
* **OpenAI:** Integration aller standardmäßigen GPT-Modelle.
* **Anthropic:** Anbindung der Claude-Modellfamilie.
* **DeepSeek:** Kosteneffiziente Anbindung über die DeepSeek-API.
* **xAI (Grok):** Nutzung der Grok-Modelle von x.ai.
* **OpenRouter:** Aggregator-Dienst für den Zugriff auf eine Vielzahl quelloffener und proprietärer Modelle.
* **HuggingFace:** Zugriff auf gehostete Modelle der HuggingFace-Infrastruktur.
* **Google Vertex AI (Enterprise):** Ermöglicht die Anbindung von GCP-Projekten. Konfiguriert über GCP Projekt-ID, Standort und Service-Account (JSON-Schlüssel) für höchste Enterprise-Anforderungen.
* **Ollama (Lokal & Offline):** Ermöglicht den Betrieb einer lokalen Ollama-Instanz in Ihrem Intranet. Ideal für vollständig luftdichte (Air-Gapped) Installationen, bei denen keine Daten das Firmennetzwerk verlassen dürfen. Hierzu werden die `ollama_base_url` (z. B. `http://host:11434/v1`) und optional ein `ollama_api_key` hinterlegt.

---

## Wo werden die Schlüssel eingetragen?

1. Öffnen Sie in JaanOS die **Einstellungen**.
2. Navigieren Sie zur Karte **KI-Schnittstellen**.
3. Wählen Sie den gewünschten Provider aus und tragen Sie Ihren API-Schlüssel ein.
4. Klicken Sie auf **Speichern** beziehungsweise **Verbindung testen**, um die Funktionsfähigkeit des Keys direkt zu überprüfen.

---

## Sicherheit der Schlüssel

Die Speicherung Ihrer Schlüssel folgt höchsten Sicherheitsstandards:
* **Verschlüsselung:** Alle eingetragenen API-Schlüssel (mit Ausnahme von Google Vertex AI, welches über verschlüsselte Anhänge in der Tryton-Datenbank hinterlegt wird) werden in verschlüsselten **HttpOnly-Cookies** auf dem Client abgelegt.
* **Sicherer Transport:** Die Cookies werden ausschließlich serverseitig verarbeitet. Die Schlüssel werden zu keinem Zeitpunkt im Klartext an das Frontend oder den Browser übergeben und sind vor Cross-Site-Scripting (XSS) geschützt.
* **Entschlüsselung:** Die Entschlüsselung erfolgt im Backend mithilfe des in Ihrer `.env` definierten `ENCRYPTION_KEY` (AES-256-GCM).
