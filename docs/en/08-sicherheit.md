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

JaanOS Core does **not contain any telemetry or tracking scripts** — no usage or business data is ever transmitted to us. The stack's only regular outbound connection is Watchtower's update check against the public container registry (which can be disabled).
* **Zero Usage Data:** No statistics regarding usage patterns, user count, or system load are transmitted to JaanIQ.
* **Network Transparency:** The application only initiates outbound network connections to data sources (e.g., your Tryton ERP) and AI API endpoints that you have explicitly configured.

---

## AI Data Handling (No Model Training)

A core security aspect of JaanOS Core is protecting your confidential financial and customer records when interacting with artificial intelligence:

* **Bring Your Own Key (BYOK):** By supplying your own API keys, your usage is subject to your direct agreement with the respective AI provider.
* **No Training by JaanOS:** JaanOS itself never uses your data for AI training. With BYOK, requests go only to the providers you choose — how they handle API data is governed by their respective terms (many commercial API offerings exclude training on customer data; review your provider's terms).
* **Geographical Control (EU Hosting):** You can configure endpoints located within the European Union (such as Google Vertex AI in Frankfurt or Mistral AI in Paris) which supports you in meeting GDPR requirements for third-country transfers.
* **Local AI Processing (Ollama):** For maximum security, connect a local Ollama instance within your network — AI processing of your business data then stays entirely inside your internal network. (Note: automatic updates and SSL certificates still require internet access unless you disable those features.)
