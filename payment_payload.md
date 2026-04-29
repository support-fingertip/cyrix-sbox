# Payment REST Endpoint — Payload Structure

Inbound POST endpoint for the SAP → Salesforce payment integration. Lets SAP push one or more Payment headers, each with its allocated invoice line items, in a single request.

---

## Endpoint

```
POST  https://<my-domain>.my.salesforce.com/services/apexrest/payment
```

| Environment | URL |
| --- | --- |
| Sandbox (sbox1) | `https://cyrix-healthcare--sbox1.sandbox.my.salesforce.com/services/apexrest/payment` |
| Production | `https://cyrix-healthcare.my.salesforce.com/services/apexrest/payment` |

---

## Authentication

Connected App OAuth 2.0 — Client Credentials Flow.

```http
Authorization: Bearer <access_token>
Content-Type:  application/json
```

How to mint the bearer:

```http
POST /services/oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&client_id=<CONSUMER_KEY>
&client_secret=<CONSUMER_SECRET>
```

The `Label.API_Key` query-param check used on the legacy public-site path is **not** required and not honoured.

---

## Top-level request shape

```json
{
  "data": [
    { …PaymentRecord… },
    { …PaymentRecord… }
  ]
}
```

| Key | Type | Required | Notes |
| --- | --- | --- | --- |
| `data` | `PaymentRecord[]` | yes | Array of payment headers. Empty / missing → `400`. |

---

## `PaymentRecord` (header)

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `PaymentId__c` | string (≤ 80) | **yes** | SAP-side payment identifier. Upsert key — the same `PaymentId__c` posted twice updates the existing record, never duplicates. |
| `Document_Date__c` | date `YYYY-MM-DD` | no | Date on the source-system document. ISO-8601 with a time component is also accepted (the time portion is stripped). |
| `Document_No__c` | string (≤ 80) | no | Receipt / document number printed on the source document. |
| `Customer_Code__c` | string (≤ 80) | no | Customer code that ties the payment back to `Account.Customer_Code__c`. |
| `Customer_Name__c` | string (≤ 255) | no | Customer display name as it appears on the source document. Denormalised — survives Account renames. |
| `Reference_Number__c` | string (≤ 80) | no | Channel-specific identifier — UTR (NEFT/RTGS), cheque no (Cheque), txn id (UPI), last-4 (Card), etc. |
| `Remarks__c` | string (≤ 32 000) | no | Free-form note. Multi-line supported (LongTextArea). |
| `PaymentLineItems` | `LineItem[]` | no | Per-invoice allocations. May be empty / omitted for header-only payments. |

---

## `LineItem`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `PaymentId__c` | string (≤ 80) | yes (recommended) | Parent payment's SAP id. If omitted, the parser inherits it from the enclosing `PaymentRecord.PaymentId__c`. Stored for reverse traceability. |
| `Payment_Mode__c` | enum | no | One of `Cash` / `Cheque` / `DD` / `NEFT` / `RTGS` / `UPI` / `Card` / `Bank Transfer`. Restricted picklist — any other value rejected. |
| `Invoice_Id__c` | string (≤ 80) | no | SAP-side invoice identifier the line settles against. |
| `Invoice_Document_No__c` | string (≤ 80) | no | Printed invoice number (e.g. `INV/2026/0021`). |
| `Invoice_Date__c` | date `YYYY-MM-DD` | no | Original invoice date. |
| `Invoice_Amount__c` | number (16, 2) | no | Original invoice total. |
| `Amount__c` | number (16, 2) | no | Portion of the parent payment applied to this invoice. May be less than `Invoice_Amount__c` for partial settlements. |

---

## Sample payloads

### Minimal — single payment, single line, full settlement

```json
{
  "data": [
    {
      "PaymentId__c": "SAP-PMT-50001",
      "Document_Date__c": "2026-04-28",
      "Document_No__c": "RC/2026/0091",
      "Customer_Code__c": "CUST-1001",
      "Customer_Name__c": "Acme Industries",
      "Reference_Number__c": "UTR-AXIS-78451239",
      "Remarks__c": "Settlement against invoice INV/2026/0021",
      "PaymentLineItems": [
        {
          "PaymentId__c": "SAP-PMT-50001",
          "Payment_Mode__c": "NEFT",
          "Invoice_Id__c": "SAP-INV-30021",
          "Invoice_Document_No__c": "INV/2026/0021",
          "Invoice_Date__c": "2026-04-15",
          "Invoice_Amount__c": 18500.00,
          "Amount__c": 18500.00
        }
      ]
    }
  ]
}
```

### Multi-line — one payment splits across three invoices, partial on the last

```json
{
  "data": [
    {
      "PaymentId__c": "SAP-PMT-50002",
      "Document_Date__c": "2026-04-29",
      "Document_No__c": "RC/2026/0092",
      "Customer_Code__c": "CUST-1042",
      "Customer_Name__c": "Northwind Pvt Ltd",
      "Reference_Number__c": "UTR-HDFC-99001122",
      "Remarks__c": "Apr settlement — partial on INV-30023",
      "PaymentLineItems": [
        {
          "PaymentId__c": "SAP-PMT-50002",
          "Payment_Mode__c": "NEFT",
          "Invoice_Id__c": "SAP-INV-30021",
          "Invoice_Document_No__c": "INV/2026/0021",
          "Invoice_Date__c": "2026-04-15",
          "Invoice_Amount__c": 18500.00,
          "Amount__c": 18500.00
        },
        {
          "PaymentId__c": "SAP-PMT-50002",
          "Payment_Mode__c": "NEFT",
          "Invoice_Id__c": "SAP-INV-30022",
          "Invoice_Document_No__c": "INV/2026/0022",
          "Invoice_Date__c": "2026-04-18",
          "Invoice_Amount__c": 6400.00,
          "Amount__c": 6400.00
        },
        {
          "PaymentId__c": "SAP-PMT-50002",
          "Payment_Mode__c": "NEFT",
          "Invoice_Id__c": "SAP-INV-30023",
          "Invoice_Document_No__c": "INV/2026/0023",
          "Invoice_Date__c": "2026-04-22",
          "Invoice_Amount__c": 3200.00,
          "Amount__c": 1900.00
        }
      ]
    }
  ]
}
```

### Multi-payment — bulk batch of two payments in one request

```json
{
  "data": [
    {
      "PaymentId__c": "SAP-PMT-50101",
      "Document_Date__c": "2026-05-01",
      "Document_No__c": "RC/2026/0101",
      "Customer_Code__c": "CUST-1001",
      "Customer_Name__c": "Acme Industries",
      "Reference_Number__c": "CHQ-485712",
      "Remarks__c": "Cheque deposit",
      "PaymentLineItems": [
        {
          "PaymentId__c": "SAP-PMT-50101",
          "Payment_Mode__c": "Cheque",
          "Invoice_Id__c": "SAP-INV-30100",
          "Invoice_Document_No__c": "INV/2026/0100",
          "Invoice_Date__c": "2026-03-12",
          "Invoice_Amount__c": 95000.00,
          "Amount__c": 50000.00
        }
      ]
    },
    {
      "PaymentId__c": "SAP-PMT-50102",
      "Document_Date__c": "2026-05-01",
      "Document_No__c": "RC/2026/0102",
      "Customer_Code__c": "CUST-1078",
      "Customer_Name__c": "Globex Hospital",
      "Reference_Number__c": "TXN-PAYTM-9981",
      "Remarks__c": "UPI clearance",
      "PaymentLineItems": [
        {
          "PaymentId__c": "SAP-PMT-50102",
          "Payment_Mode__c": "UPI",
          "Invoice_Id__c": "SAP-INV-30201",
          "Invoice_Document_No__c": "INV/2026/0201",
          "Invoice_Date__c": "2026-04-25",
          "Invoice_Amount__c": 4500.00,
          "Amount__c": 4500.00
        },
        {
          "PaymentId__c": "SAP-PMT-50102",
          "Payment_Mode__c": "UPI",
          "Invoice_Id__c": "SAP-INV-30202",
          "Invoice_Document_No__c": "INV/2026/0202",
          "Invoice_Date__c": "2026-04-26",
          "Invoice_Amount__c": 1200.00,
          "Amount__c": 1200.00
        }
      ]
    }
  ]
}
```

### Header-only — payment received with no allocations yet

```json
{
  "data": [
    {
      "PaymentId__c": "SAP-PMT-50300",
      "Document_Date__c": "2026-05-05",
      "Document_No__c": "RC/2026/0103",
      "Customer_Code__c": "CUST-1099",
      "Customer_Name__c": "Initech",
      "Reference_Number__c": "ADV-DEPOSIT",
      "Remarks__c": "Advance — to be applied later",
      "PaymentLineItems": []
    }
  ]
}
```

---

## Response shape

### `200 OK`

```json
{
  "status": "SUCCESS",
  "paymentsProcessed": 2,
  "lineItemsProcessed": 4
}
```

| Field | Type | Notes |
| --- | --- | --- |
| `status` | string | Always `"SUCCESS"` for `200`. |
| `paymentsProcessed` | int | Number of `Payment__c` rows upserted in this call. |
| `lineItemsProcessed` | int | Number of `Payment_Line_Item__c` rows inserted. |

### `500 ERROR`

```json
{
  "status": "ERROR",
  "message": "Each payment record must carry PaymentId__c (SAP id)."
}
```

`message` is verbatim what the platform / parser threw — examples include:

- `"Payload missing \"data\" array."` — top-level shape is wrong.
- `"Each payment record must carry PaymentId__c (SAP id)."` — `PaymentId__c` is blank or missing.
- `"Invalid date \"…\" — expected YYYY-MM-DD."` — date couldn't be parsed.
- `"INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST"` — `Payment_Mode__c` value isn't on the picklist.
- `"DUPLICATE_VALUE"` — a `PaymentId__c` collision (shouldn't happen on upsert; flag for investigation).

---

## Behaviour notes

1. **Idempotency** — repeating the same payload updates rather than duplicates. `Payment__c.PaymentId__c` is the upsert key, so SAP retries are safe.
2. **Replace-children semantics** — every time a `Payment__c` is upserted, its existing `Payment_Line_Item__c` rows are deleted and re-inserted from the inbound `PaymentLineItems` array. Send the full picture each time, not deltas. (Lines without explicit `PaymentId__c` inherit it from the enclosing header.)
3. **Date format** — `YYYY-MM-DD` is the canonical shape. ISO-8601 with `T<time>` (e.g. `2026-04-28T00:00:00Z`) is accepted; the time component is dropped.
4. **Currency precision** — `Decimal(16, 2)`. Send numbers, not strings (`18500.00`, not `"18500.00"`).
5. **`Reference_Number__c`** — free-form text, ≤ 80 chars. Whatever the channel (UTR / cheque no / UPI txn id / card last-4) — pass it through as-is; we don't parse it.
6. **`Customer_Code__c` linkage** — the value is stored as-is. To resolve to an Account, query `[SELECT Id FROM Account WHERE Customer_Code__c = :customerCode]`. The endpoint does **not** auto-link (so a partial-match SAP code can't accidentally bind to the wrong Account).
7. **Logging** — every request writes a `Log__c` row with `Object__c = 'Payment Inbound'`, the raw request body, the response body, and the HTTP status code. Useful for SAP-side debugging.
8. **Bulk size** — the endpoint trusts the caller's batch sizing. Stay under Salesforce's per-DML governor limits (≈ 10 000 rows for SOQL, ~150 DMLs per transaction). For large back-fills, send batches of ≤ 100 payments per request.

---

## End-to-end test (curl)

```bash
# 1. Mint a token
TOKEN=$(curl -s -X POST \
  "https://cyrix-healthcare--sbox1.sandbox.my.salesforce.com/services/oauth2/token" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CONSUMER_KEY" \
  -d "client_secret=$CONSUMER_SECRET" \
  | jq -r .access_token)

# 2. Post a payment
curl -X POST \
  "https://cyrix-healthcare--sbox1.sandbox.my.salesforce.com/services/apexrest/payment" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @payment_payload.json

# Expected:
# {"status":"SUCCESS","paymentsProcessed":1,"lineItemsProcessed":1}
```

---

## Postman quick-start

1. **Authorization** tab → Type **OAuth 2.0**.
2. **Get New Access Token**:
   - Grant Type: **Client Credentials**
   - Access Token URL: `https://<my-domain>.my.salesforce.com/services/oauth2/token`
   - Client ID / Client Secret: from the Connected App.
   - Client Authentication: **Send client credentials in body**.
3. Click **Use Token**.
4. **Body** → raw / JSON → paste any of the sample payloads above.
5. **Send**.

Postman caches the token and refreshes on `401`, so subsequent requests don't need step 2 re-run.
