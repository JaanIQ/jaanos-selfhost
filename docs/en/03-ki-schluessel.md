# AI Keys & BYOK (Bring Your Own Key)

JaanOS Core operates on a "Bring Your Own Key" (BYOK) model. This means you supply your own API credentials for the language models.

## Why BYOK?

* **Absolute Cost Control:** You pay only for what you consume, billed directly by your chosen provider. JaanOS does not charge any usage markup or transaction fees.
* **Data Sovereignty:** You decide which provider receives your natural language prompts.
* **Flexibility:** You can switch between providers at any time or run multiple integrations in parallel.

---

## Supported AI Providers & APIs

JaanOS Core provides native integration for the following APIs and platforms:

* **Gemini (Google):** Direct integration with Google AI Studio. Verified using the `gemini-2.5-flash:countTokens` endpoint.
* **Mistral AI:** Access to models developed by the European provider Mistral.
* **OpenAI:** Integration for all standard GPT models.
* **Anthropic:** Access to the Claude model family.
* **DeepSeek:** Cost-efficient integration via the DeepSeek API.
* **xAI (Grok):** Access to Grok models from x.ai.
* **OpenRouter:** An aggregator service providing access to various open-source and proprietary models.
* **HuggingFace:** Access to hosted models on the HuggingFace infrastructure.
* **Google Vertex AI (Enterprise):** Connects to GCP projects. Configured using the GCP Project ID, Location, and Service Account (JSON key) for enterprise security architectures.
* **Ollama (Local & Offline):** Runs a local Ollama instance inside your private intranet. Ideal for fully air-gapped deployments where no data is permitted to leave the local network. Set up via `ollama_base_url` (e.g., `http://host:11434/v1`) and optionally an `ollama_api_key`.

---

## How to Configure Your Keys

1. Open the **Settings** menu in JaanOS.
2. Navigate to the **AI Interfaces** section.
3. Select your provider and paste your API key.
4. Click **Save** or **Test Connection** to verify that your key is valid and working.

---

## Security of Your Keys

The storage and handling of your credentials follow strict security protocols:
* **Encryption:** All configured API keys (except Google Vertex AI, which is stored as encrypted attachments inside your Tryton database) are stored as encrypted **HttpOnly cookies** in the client.
* **Secure Transit:** Cookies are processed strictly server-side. The keys are never exposed in plain text to the frontend or the browser, preventing Cross-Site Scripting (XSS) access.
* **Decryption:** The backend decrypts the cookies on-the-fly using the `ENCRYPTION_KEY` (AES-256-GCM) configured in your `.env` file.
