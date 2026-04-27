/**
 * Inbound REST endpoint that SAP POSTs to in order to push records
 * into Salesforce. Cyrix-specific port of SAPGetData from the
 * reference project — only the productMaster branch is implemented;
 * the StockTransfer branch from the reference is intentionally
 * omitted, so any other ?value= falls into the else block.
 *
 * Endpoint: /services/apexrest/send/*
 * Auth:     ?key=<value of Custom Label API_Key>
 * Selector: ?value=productMaster
 * Body:     { "data": [ {Product2 fields...}, ... ] }
 *
 * Schema differences vs the reference:
 *   - Reference Product__c              -> standard Product2 here.
 *   - Reference prd.Product_Code__c     -> Product2.ProductCode here.
 *   - Reference Log__c.Status_Code__c   -> same field, but Text in this
 *                                          org, so res.statusCode is
 *                                          cast to String on log write.
 *   - Reference Log__c.RecordId__c      -> not present here; omitted.
 */
@RestResource(urlMapping='/send/*')
global class SAPGetData {

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String url = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
        String key = RestContext.request.params.get('key');
        String value = RestContext.request.params.get('value');

        String data = req.requestBody.toString();

        System.debug('data:' + data);

        String postfix = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
        if (Label.API_Key == key) {

            Map<String, Object> prodMap  = (Map<String, Object>) JSON.deserializeUntyped(data);
            Map<String, Object> prodMap2 = (Map<String, Object>) JSON.deserializeUntyped(data);

            for (String key2 : prodMap2.keySet()) {
                if (prodMap2.get(key2) == null) {
                    prodMap2.remove(key2);
                }
            }

            List<String> finalJsonString = new List<String>();
            List<Map<String, Object>> datalist = new List<Map<String, Object>>();

            for (Object instance : (List<Object>) prodMap.get('data')) {
                finalJsonString.add(JSON.serialize(instance));
                datalist.add((Map<String, Object>) instance);
            }

            System.debug('finalJsonString:' + finalJsonString);

            Map<String, Object> succMap = new Map<String, Object>();
            Map<String, Object> errMap  = new Map<String, Object>();

            if (value == 'productMaster') {

                List<Response> lstResponse = new List<Response>();

                // Pre-pass: deserialize every incoming row into Product2 and
                // collect the ProductCodes so we can match against existing
                // records before the upsert. Without this, upsert acts as
                // insert-only (Product2 has no External Id by default) and
                // re-sending the same ProductCode hits unique-constraint
                // errors on fields like SAP_Item_Code__c.
                List<Product2> prdlist = new List<Product2>();
                Set<String> productCodes = new Set<String>();
                for (String s : finalJsonString) {
                    s = s.replaceFirst('\\{', '{"attributes" : {"type" : "Product2", "referenceId" : "ref1"},');
                    Product2 prd = (Product2) JSON.deserialize(s, Sobject.class);
                    System.debug('prd ' + prd);
                    prdlist.add(prd);
                    if (String.isNotBlank(prd.ProductCode)) {
                        productCodes.add(prd.ProductCode);
                    }
                }

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

                for (Product2 prd : prdlist) {
                    if (String.isNotBlank(prd.ProductCode)
                        && existingByCode.containsKey(prd.ProductCode)) {
                        prd.Id = existingByCode.get(prd.ProductCode);
                    }
                    try {
                        upsert prd;
                        lstResponse.add(new Response('Success', prd.ProductCode));
                    } catch (DmlException ex) {
                        lstResponse.add(new Response('Failure', prd.ProductCode, ex.getMessage()));
                    }
                }
                res.statusCode = 200;
                res.addHeader('Content-Type', 'application/json');
                res.responseBody = Blob.valueOf(JSON.serialize(lstResponse));

                if (Label.Enable_Logs == 'TRUE') {
                    String reqsizeString = data;
                    Integer maxSize = 32000;
                    if (reqsizeString.length() > maxSize) {
                        reqsizeString = reqsizeString.substring(0, maxSize);
                    }
                    String ressizeString = JSON.serialize(lstResponse);
                    if (ressizeString.length() > maxSize) {
                        ressizeString = ressizeString.substring(0, maxSize);
                    }
                    Log__c getLogs = new Log__c();
                    getLogs.Request__c     = reqsizeString;
                    getLogs.Response__c    = ressizeString;
                    getLogs.Object__c      = 'Product';
                    getLogs.Status_Code__c = String.valueOf(res.statusCode);
                    insert getLogs;
                }

            }
            // StockTransfer branch from the reference intentionally omitted.
            else {
                List<Response> lstResponse = new List<Response>();
                lstResponse.add(new Response('Failure', 'Invalid Parameter Value.', false));
                res.statusCode = 403;
                res.addHeader('Content-Type', 'application/json');
                res.responseBody = Blob.valueOf(JSON.serialize(lstResponse));
            }

        } else {
            List<Response> lstResponse = new List<Response>();
            lstResponse.add(new Response('Failure', 'Invalid Key.', false));
            res.statusCode = 401;
            res.addHeader('Content-Type', 'application/json');
            res.responseBody = Blob.valueOf(JSON.serialize(lstResponse));
        }
    }

    public class Response {
        public String Status;
        public String Message;
        public String ID;

        public Response(String Status, String ID) {
            this.Status = Status;
            this.ID = ID;
        }
        public Response(String Status, String Message, Boolean noIds) {
            this.Status = Status;
            this.Message = Message;
        }
        public Response(String Status, String ID, String Message) {
            this.Status = Status;
            this.ID = ID;
            this.Message = Message;
        }
    }
}
