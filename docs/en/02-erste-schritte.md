# Getting Started

Once you have successfully installed JaanOS and the container is active, you can begin the initial configuration.

## Initial Login (Admin Registration)

Since JaanOS Core runs in decentralized self-hosted mode, there is no predefined default password.
1. Access your instance URL in your browser (e.g., `https://jaanos.your-domain.com`).
2. You will be automatically redirected to the setup registration page.
3. Create the first user account using the input form.
   * **Important Note:** The first registered user is automatically designated as the system administrator (admin account) with full system privileges.
   * **Security:** After the first account is created, the registration form for new administrative accounts is locked. Any subsequent accounts must be created or approved by the existing administrator.

---

## Setup Wizard (First-Boot Setup Wizard)

After signing in, the onboarding wizard starts automatically to guide you step-by-step:
* **Step 1: Welcome** – Introduction and confirmation of administrative status.
* **Step 2: ERP Connection** – Connecting to your ERP backend (Tryton ERP or Lexware Office).
* **Step 3: Finish** – Complete setup and start using the dashboard.

---

## ERP Connection

JaanOS Core acts as an intelligent interface and requires connection to a data source to process metrics and compile actions.

### Required Fields per System

#### 1. Tryton ERP
To connect a Tryton instance, supply the following details:
* **Server URL:** The full address of your Tryton server (e.g., `http://127.0.0.1:8069` or `https://tryton.your-domain.com`).
* **Database Name:** The exact database name of your Tryton PostgreSQL database.
* **Username & Password:** Valid credentials of a user in Tryton. The permissions of this user dictate the actions JaanOS can execute.

#### 2. Lexware Office
To connect Lexware Office, configure it using an API key:
* **API Key:** The authorization token (Bearer Token) generated from your Lexware developer portal.

---

## Testing Connections & Troubleshooting

During configuration, you can verify the settings by clicking **Test Connection**. The system will make a test request (JSON-RPC to `common.db.login`) and display the results.

### Diagnostic Messages and Root Causes

If the connection test fails, the interface returns specific diagnostic messages:

| UI Error Message | Technical Cause & Resolution |
| :--- | :--- |
| **RPC endpoint not found (404) — is the URL correct and pointing to a Tryton server?** | The URL is reachable, but no Tryton JSON-RPC service is listening at the specified path. Check the URL and database name. |
| **The ERP server responded with an error (HTTP [Status]) — check server logs.** | The server is reachable but encountered an internal error (e.g., HTTP 500 or 503). Check the logs of the Tryton instance. |
| **Unexpected response (HTTP [Status]).** | The server returned a non-standard HTTP status code. |
| **Database does not exist — please check the database name.** | The Tryton server is running, but the specified database does not exist. |
| **Timeout — server unreachable. Check firewall/port (Tryton is usually 8000) and URL.** | The request timed out (5-second limit). Verify that firewalls are not blocking the port and that the server is online. Tryton defaults to port `8000` or `8069`. |
| **Host not found — please check URL/domain and DNS.** | The hostname could not be resolved (`ENOTFOUND`). Verify the DNS entries and spelling of the domain. |
| **Connection refused — is the ERP service running and is the port open?** | The connection was actively rejected by the target server (`ECONNREFUSED`). The service may be offline or listening on a different port. |
| **SSL/TLS error — check the ERP URL certificate (valid? correct hostname?).** | A secure connection could not be established. The Tryton server certificate is either expired, self-signed (without the issuer being trusted), or issued for a different hostname. |
| **Server unreachable — check URL, port, and network connection.** | General network failure encountered when trying to establish a connection. |
