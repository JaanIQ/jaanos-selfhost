# Daily Usage

JaanOS Core replaces nested menu structures with a minimalist, text-based user interface (Zero UI). The core of the system is the **Neural Core**, which translates your natural language directives into secure ERP actions.

## The Central Input Field (Neural Core)

You control your connected system through the central input field. Simply type what you want to find or accomplish using everyday language. The Neural Core analyzes the prompt, identifies the target tables, and executes the database operations.

---

## Example Directives

Here are typical examples of natural language commands you can use (taken from the interactive preview):

### 1. Querying Data
* **Input:** `Show all open invoices above €10,000`
  * **Result:** Executes a query on `account.invoice` filtering for a status of `posted` and amounts greater than €10,000, displaying the matching records.
* **Input:** `Show open sales orders above €15,000`
  * **Result:** Searches `sale.order` for orders with a status of `processing` and a total value above €15,000.

### 2. Creating Records
* **Input:** `Create lead for Müller GmbH`
  * **Result:** Creates a new entry in `sale.opportunity` (sales opportunity) linked to the party.
* **Input:** `Create new contact: TechCorp GmbH, Munich`
  * **Result:** Inserts a partner record in `party.party` named `TechCorp GmbH` with a shipping or billing address in `Munich`.

---

## Metrics & KPI Dashboard

In addition to text input, JaanOS Core visualizes key performance indicators (KPIs) directly on the dashboard. These metrics are retrieved in real-time from your ERP backend.
* **Live Data:** No permanent caching or data aggregation is performed on third-party systems. The values reflect the exact, current state of your ERP database.
* **Dynamic Correlation:** The Neural Core correlates open items and project states to proactively display warnings (e.g., in case of impending payment delays).

---

## Limitations and Duty of Care (Important Notice)

Although the Neural Core compiles commands deterministically, it remains an AI-assisted system. Adhere to the following operational guidelines:

* **Verification Obligation:** Generative AI models can occasionally misinterpret instructions or generate incorrect ORM queries. Always review proposed actions and draft postings carefully before confirming them.
* **No Liability for Incorrect Postings:** The user bears sole responsibility for the accuracy of database entries and business transactions. In accordance with the EULA, JaanIQ assumes no liability for corrupted records or financial damages resulting from the use of the AI interface.
* **Complex Edge Cases:** Complex fiscal transactions or bulk operations should still be executed directly within the native Tryton or Lexware interfaces.
