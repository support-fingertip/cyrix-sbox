/**
 * Inbound REST endpoint that SAP POSTs to in order to push records
 * into Salesforce. Cyrix-specific port of SAPGetData from the
 * reference project — only the productMaster branch is implemented;
 * any other ?value= falls into the else branch and returns 403.
 *
 * Endpoint: /services/apexrest/send/*
 * Auth: ?key=<value of Custom Label API_Key>
 * Selector: ?value=productMaster
 * Body: { "data": [ {Product2 fields...}, ... ] }
 *
 * Schema differences vs the reference:
 *   - Reference's Product__c -> standard Product2 in this org.
 *   - Match key: Product2.ProductCode (no custom external id field
 *     exists on Product2 here, so we resolve the existing record by
 *     querying ProductCode and stamping Id before upsert).
 *   - Log__c fields used: Request__c, Response__c, Object__c,
 *     Status_Code__c (Text in this org, so res.statusCode is cast
 *     to String).
 */
@RestResource(urlMapping='/send/*')
global class SAPGetData {

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String key   = req.params.get('key');
        String value = req.params.get('value');
        String data  = req.requestBody != null ? req.requestBody.toString() : '';

        // Auth gate — same Custom Label as the GET endpoint.
        if (Label.API_Key != key) {
            List<Response> err = new List<Response>{
                new Response('Failure', 'Invalid Key.', false)
            };
            res.statusCode = 401;
            res.addHeader('Content-Type', 'application/json');
            res.responseBody = Blob.valueOf(JSON.serialize(err));
            return;
        }

        if (value != 'productMaster') {
            List<Response> err = new List<Response>{
                new Response('Failure', 'Invalid Parameter Value.', false)
            };
            res.statusCode = 403;
            res.addHeader('Content-Type', 'application/json');
            res.responseBody = Blob.valueOf(JSON.serialize(err));
            return;
        }

        // ---- productMaster ----
        List<Response> lstResponse = new List<Response>();

        // 1. Parse incoming JSON into a list of plain maps so we can
        //    inspect ProductCode before deserializing into Product2.
        List<Map<String, Object>> incoming = new List<Map<String, Object>>();
        Set<String> productCodes = new Set<String>();
        try {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(data);
            for (Object item : (List<Object>) body.get('data')) {
                Map<String, Object> m = (Map<String, Object>) item;
                incoming.add(m);
                Object code = m.get('ProductCode');
                if (code != null) {
                    productCodes.add(String.valueOf(code));
                }
            }
        } catch (Exception parseEx) {
            List<Response> err = new List<Response>{
                new Response('Failure', 'Invalid JSON body: ' + parseEx.getMessage(), false)
            };
            res.statusCode = 400;
            res.addHeader('Content-Type', 'application/json');
            res.responseBody = Blob.valueOf(JSON.serialize(err));
            return;
        }

        // 2. Look up existing Product2 records by ProductCode so the
        //    upsert acts as an update for known codes and an insert
        //    for new ones (Product2 has no external-id field here).
        Map<String, Id> existingByCode = new Map<String, Id>();
        if (!productCodes.isEmpty()) {
            for (Product2 ex : [
                SELECT Id, ProductCode
                FROM Product2
                WHERE ProductCode IN :productCodes
            ]) {
                existingByCode.put(ex.ProductCode, ex.Id);
            }
        }

        // 3. Build Product2 instances and upsert one at a time so a
        //    single bad row doesn't block the rest of the batch.
        for (Map<String, Object> m : incoming) {
            String code = m.get('ProductCode') != null
                ? String.valueOf(m.get('ProductCode'))
                : null;
            try {
                Map<String, Object> typedMap = new Map<String, Object>(m);
                typedMap.put('attributes', new Map<String, String>{
                    'type' => 'Product2',
                    'referenceId' => 'ref1'
                });
                Product2 p = (Product2) JSON.deserialize(
                    JSON.serialize(typedMap),
                    Sobject.class
                );

                if (String.isNotBlank(code) && existingByCode.containsKey(code)) {
                    p.Id = existingByCode.get(code);
                }

                upsert p;
                lstResponse.add(new Response('Success', p.ProductCode));
            } catch (Exception ex) {
                lstResponse.add(new Response('Failure', code, ex.getMessage()));
            }
        }

        res.statusCode = 200;
        res.addHeader('Content-Type', 'application/json');
        res.responseBody = Blob.valueOf(JSON.serialize(lstResponse));

        // 4. Audit log (same convention as other classes in this org).
        if (Label.Enable_Logs == 'TRUE') {
            writeLog(data, JSON.serialize(lstResponse), 'Product', String.valueOf(res.statusCode));
        }
    }

    /**
     * Append a Log__c row with the truncated request/response bodies.
     * Failure to log is non-fatal — the API response stays as-is.
     */
    private static void writeLog(String requestBody, String responseBody,
                                  String objectName, String statusCode) {
        try {
            Integer maxSize = 32000;
            if (requestBody != null && requestBody.length() > maxSize) {
                requestBody = requestBody.substring(0, maxSize);
            }
            if (responseBody != null && responseBody.length() > maxSize) {
                responseBody = responseBody.substring(0, maxSize);
            }

            Log__c rec = new Log__c();
            rec.Request__c     = requestBody;
            rec.Response__c    = responseBody;
            rec.Object__c      = objectName;
            rec.Status_Code__c = statusCode;
            insert rec;
        } catch (Exception e) {
            System.debug('SAPGetData logging failed: ' + e.getMessage());
        }
    }

    /**
     * Per-row response envelope returned to SAP. Three constructors
     * cover: success-with-id, error-with-id, and parameter/auth errors
     * that don't have a per-row id.
     */
    public class Response {
        public String Status;
        public String Message;
        public String ID;

        public Response(String status, String id) {
            this.Status = status;
            this.ID     = id;
        }
        public Response(String status, String message, Boolean noIds) {
            this.Status  = status;
            this.Message = message;
        }
        public Response(String status, String id, String message) {
            this.Status  = status;
            this.ID      = id;
            this.Message = message;
        }
    }
}
