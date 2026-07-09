# Security & Privacy

JaanOS Core is designed around the principle of "Privacy by Design." As a self-hosted platform, you retain complete sovereignty over your business data and the way it is processed.

## Data Storage & Encryption

### 1. Local PostgreSQL Database
All operational data for JaanOS Core is stored exclusively in the PostgreSQL database running on your server. No synchronization is performed with external cloud environments managed by JaanIQ.
* **Host Location:** Database files are stored within the isolated Docker volume `postgres_data` (located under `/var/lib/docker/volumes/`).

### 2. Encryption of Credentials (AES-256-GCM)
All credentials used to connect to your ERP systems (such as passwords and API tokens) are encrypted before being written to the database.
* **Standard:** Industry-standard AES-256-GCM encryption is enforced.
* **Key Management:** The decryption key (`ENCRYPTION_KEY`) is generated during the initial setup by the installation script and stored in `/opt/jaanos/.env` on your server.
* **Access Control:** The `.env` file is protected with `600` permissions (read/write access restricted strictly to root/owner).

---

## Exclusion of Telemetry and Tracking

JaanOS Core does **not contain any telemetry, call-home connections, or tracking scripts**.
* **Zero Usage Data:** No statistics regarding usage patterns, user count, or system load are transmitted to JaanIQ.
* **Network Transparency:** The application only initiates outbound network connections to data sources (e.g., your Tryton ERP) and AI API endpoints that you have explicitly configured.

---

## AI Data Handling (No Model Training)

A core security aspect of JaanOS Core is protecting your confidential financial and customer records when interacting with artificial intelligence:

* **Bring Your Own Key (BYOK):** By supplying your own API keys, your usage is subject to your direct agreement with the respective AI provider.
* **No Unauthorized Training:** Leading API providers (such as Google Vertex AI, Anthropic API, or OpenAI commercial APIs) guarantee in their developer terms that data transmitted via APIs is **never** used to train public models.
* **Geographical Control (EU Hosting):** You can configure endpoints located within the European Union (such as Google Vertex AI in Frankfurt or Mistral AI in Paris) to maintain compliance with GDPR guidelines.
* **100% Offline Deployments (Ollama):** For maximum security, JaanOS Core can run fully offline by connecting to a local Ollama instance within your intranet. In this configuration, no data leaves your internal network.
