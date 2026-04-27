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

                // Build Product2 instances from the incoming JSON. SAP sends
                // its product identifier in ProductCode; mirror that into
                // SAP_Item_Code__c (a unique External Id field on Product2),
                // then upsert using SAP_Item_Code__c as the match key. That
                // gives true insert-or-update semantics natively — no
                // pre-query needed, no duplicate-value errors on retries.
                List<Product2> prdlist = new List<Product2>();
                for (String s : finalJsonString) {
                    s = s.replaceFirst('\\{', '{"attributes" : {"type" : "Product2", "referenceId" : "ref1"},');
                    Product2 prd = (Product2) JSON.deserialize(s, Sobject.class);
                    if (String.isNotBlank(prd.ProductCode)) {
                        prd.SAP_Item_Code__c = prd.ProductCode;
                    }
                    System.debug('prd ' + prd);
                    prdlist.add(prd);
                }

                for (Product2 prd : prdlist) {
                    try {
                        upsert prd Product2.SAP_Item_Code__c;
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