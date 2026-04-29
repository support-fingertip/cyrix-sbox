/**
 * Inbound REST endpoint for SAP -> Salesforce Payment posting.
 *
 *   POST /services/apexrest/payment
 *   Authorization: Bearer <Connected App OAuth token>
 *   Body:
 *     {
 *       "data": [
 *         {
 *           "PaymentId__c": "SAP-PMT-50001",
 *           "Document_Date__c": "2026-04-28",
 *           "Document_No__c":   "RC/2026/0091",
 *           "Customer_Code__c": "CUST-1001",
 *           "Customer_Name__c": "Acme Industries",
 *           "Reference_Number__c": "UTR-AXIS-78451239",
 *           "Remarks__c": "Settlement against April 2026 invoices",
 *           "PaymentLineItems": [
 *             {
 *               "PaymentId__c":          "SAP-PMT-50001",
 *               "Payment_Mode__c":       "NEFT",
 *               "Invoice_Id__c":         "SAP-INV-30021",
 *               "Invoice_Document_No__c":"INV/2026/0021",
 *               "Invoice_Date__c":       "2026-04-15",
 *               "Invoice_Amount__c":     18500.00,
 *               "Amount__c":             18500.00
 *             }
 *           ]
 *         }
 *       ]
 *     }
 *
 * Behaviour:
 *   1. Each header is upserted on Payment__c.PaymentId__c so SAP
 *      retries are idempotent.
 *   2. Existing Payment_Line_Item__c children of every upserted
 *      header are deleted first, then the inbound lines are inserted
 *      with master-detail `Payment__c` resolved by the parent's
 *      newly-known Salesforce Id (no relationship-by-external-id
 *      gymnastics needed). Each line also carries the parent's
 *      `PaymentId__c` for reverse traceability.
 *   3. Each request gets a Log__c row capturing the raw request +
 *      response so SAP-side debugging matches the existing pattern
 *      WhatsAppQuoteSender / SAPGetData established.
 *
 * Auth is delegated entirely to the Connected App OAuth flow — no
 * Label.API_Key check, mirroring the recent sapApiController cut-over.
 */
@RestResource(urlMapping='/payment/*')
global with sharing class PaymentRestService {

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String rawBody = req.requestBody == null ? '' : req.requestBody.toString();
        Integer headerCount = 0;
        Integer lineCount   = 0;
        String responseBody = '';
        Integer statusCode  = 200;
        String errorMessage = '';

        try {
            Payload payload = (Payload) JSON.deserialize(rawBody, Payload.class);
            if (payload == null || payload.data == null || payload.data.isEmpty()) {
                throw new PaymentApiException('Payload missing "data" array.');
            }

            // --- Step 1: upsert headers ---
            List<Payment__c> headers = new List<Payment__c>();
            for (PaymentRecord pr : payload.data) {
                if (String.isBlank(pr.PaymentId__c)) {
                    throw new PaymentApiException(
                        'Each payment record must carry PaymentId__c (SAP id).'
                    );
                }
                Payment__c p = new Payment__c();
                p.PaymentId__c        = pr.PaymentId__c;
                p.Document_Date__c    = parseDate(pr.Document_Date__c);
                p.Document_No__c      = pr.Document_No__c;
                p.Customer_Code__c    = pr.Customer_Code__c;
                p.Customer_Name__c    = pr.Customer_Name__c;
                p.Reference_Number__c = pr.Reference_Number__c;
                p.Remarks__c          = pr.Remarks__c;
                headers.add(p);
            }
            Schema.SObjectField extId = Payment__c.PaymentId__c;
            Database.upsert(headers, extId, true);
            headerCount = headers.size();

            // Build SAP id -> Salesforce id lookup for the children.
            Map<String, Id> paymentIdToSfId = new Map<String, Id>();
            for (Payment__c h : headers) {
                paymentIdToSfId.put(h.PaymentId__c, h.Id);
            }

            // --- Step 2: replace children of every upserted header ---
            // Each SAP payment is a complete picture of its allocations,
            // so we delete the existing rows and reinsert from the
            // inbound payload. Avoids the composite-key headache of
            // upserting per-(payment, invoice) without a true unique
            // external id.
            Set<Id> parentSfIds = new Set<Id>(paymentIdToSfId.values());
            if (!parentSfIds.isEmpty()) {
                List<Payment_Line_Item__c> existing = [
                    SELECT Id FROM Payment_Line_Item__c
                    WHERE Payment__c IN :parentSfIds
                ];
                if (!existing.isEmpty()) delete existing;
            }

            List<Payment_Line_Item__c> children = new List<Payment_Line_Item__c>();
            for (PaymentRecord pr : payload.data) {
                if (pr.PaymentLineItems == null) continue;
                Id parentSfId = paymentIdToSfId.get(pr.PaymentId__c);
                if (parentSfId == null) continue; // shouldn't happen — defence in depth

                for (LineItem li : pr.PaymentLineItems) {
                    Payment_Line_Item__c c = new Payment_Line_Item__c();
                    c.Payment__c             = parentSfId;
                    c.PaymentId__c           = li.PaymentId__c != null
                                               ? li.PaymentId__c
                                               : pr.PaymentId__c;
                    c.Payment_Mode__c        = li.Payment_Mode__c;
                    c.Invoice_Id__c          = li.Invoice_Id__c;
                    c.Invoice_Document_No__c = li.Invoice_Document_No__c;
                    c.Invoice_Date__c        = parseDate(li.Invoice_Date__c);
                    c.Invoice_Amount__c      = li.Invoice_Amount__c;
                    c.Amount__c              = li.Amount__c;
                    children.add(c);
                }
            }
            if (!children.isEmpty()) insert children;
            lineCount = children.size();

            res.addHeader('Content-Type', 'application/json');
            statusCode = 200;
            responseBody = JSON.serialize(new Map<String, Object>{
                'status' => 'SUCCESS',
                'paymentsProcessed' => headerCount,
                'lineItemsProcessed' => lineCount
            });
            res.statusCode = statusCode;
            res.responseBody = Blob.valueOf(responseBody);

        } catch (Exception e) {
            errorMessage = e.getMessage();
            statusCode = 500;
            responseBody = JSON.serialize(new Map<String, Object>{
                'status' => 'ERROR',
                'message' => errorMessage
            });
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = statusCode;
            res.responseBody = Blob.valueOf(responseBody);
        } finally {
            // Always log the round-trip so SAP-side debugging matches
            // the WhatsApp / SAPGetData pattern in this org.
            writeLog(rawBody, responseBody, statusCode, errorMessage);
        }
    }

    private static Date parseDate(String iso) {
        if (String.isBlank(iso)) return null;
        try {
            return Date.valueOf(iso);
        } catch (Exception e) {
            // Strict ISO YYYY-MM-DD failed — try DateTime parse and
            // strip the time component so SAP can pass full ISO-8601.
            try {
                return DateTime.valueOfGmt(iso.replace('T', ' ').substring(0, 19)).date();
            } catch (Exception inner) {
                throw new PaymentApiException(
                    'Invalid date "' + iso + '" — expected YYYY-MM-DD.'
                );
            }
        }
    }

    private static void writeLog(String reqBody, String resBody,
                                  Integer statusCode, String errorMsg) {
        try {
            Integer maxSize = 32000;
            String trimmedReq = (reqBody != null && reqBody.length() > maxSize)
                ? reqBody.substring(0, maxSize) : reqBody;
            String trimmedRes = (errorMsg != null && errorMsg.length() > 0)
                ? 'ERROR: ' + errorMsg + (resBody != null ? '\n\nResponseBody: ' + resBody : '')
                : resBody;
            if (trimmedRes != null && trimmedRes.length() > maxSize) {
                trimmedRes = trimmedRes.substring(0, maxSize);
            }
            Log__c rec = new Log__c();
            rec.Object__c      = 'Payment Inbound';
            rec.Request__c     = trimmedReq;
            rec.Response__c    = trimmedRes;
            rec.Status_Code__c = String.valueOf(statusCode);
            insert rec;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'PaymentRestService log insert failed: ' + e.getMessage());
        }
    }

    public class PaymentApiException extends Exception {}

    // ===== Payload shape =====

    public class Payload {
        public List<PaymentRecord> data;
    }

    public class PaymentRecord {
        public String PaymentId__c;
        public String Document_Date__c;
        public String Document_No__c;
        public String Customer_Code__c;
        public String Customer_Name__c;
        public String Reference_Number__c;
        public String Remarks__c;
        public List<LineItem> PaymentLineItems;
    }

    public class LineItem {
        public String  PaymentId__c;
        public String  Payment_Mode__c;
        public String  Invoice_Id__c;
        public String  Invoice_Document_No__c;
        public String  Invoice_Date__c;
        public Decimal Invoice_Amount__c;
        public Decimal Amount__c;
    }
}
