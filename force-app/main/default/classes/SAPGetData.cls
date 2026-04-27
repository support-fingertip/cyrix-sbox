/**
 * Inbound REST endpoint that SAP POSTs to in order to push records
 * into Salesforce. Handles two ?value= selectors:
 *
 *   productMaster  -> upsert Product2 by SAP_Item_Code__c
 *   invoice        -> upsert Invoice__c by Invoice_Id__c, plus its
 *                     Invoice_Item__c children by lineItemId__c,
 *                     resolving Customer / Order / Owner / Product /
 *                     OrderItem lookups from incoming codes.
 *
 * Endpoint: /services/apexrest/send/*
 * Auth:     ?key=<value of Custom Label API_Key>
 * Body:     { "data": [ {fields...}, ... ] }
 *
 * On every successful upsert we also stamp SAP_Sync_Status__c = true
 * and Last_ERP_Sync_Date__c = now() so the record clearly shows it
 * was last touched by the SAP integration.
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
                DateTime nowStamp = DateTime.now();
                for (String s : finalJsonString) {
                    s = s.replaceFirst('\\{', '{"attributes" : {"type" : "Product2", "referenceId" : "ref1"},');
                    Product2 prd = (Product2) JSON.deserialize(s, Sobject.class);
                    if (String.isNotBlank(prd.ProductCode)) {
                        prd.SAP_Item_Code__c = prd.ProductCode;
                    }
                    prd.SAP_Sync_Status__c = true;
                    prd.Last_ERP_Sync_Date__c = nowStamp;
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
                    writeLog(data, JSON.serialize(lstResponse), 'Product', String.valueOf(res.statusCode));
                }

            }
            else if (value == 'invoice') {

                List<Response> lstResponse = handleInvoice(datalist);

                res.statusCode = 200;
                res.addHeader('Content-Type', 'application/json');
                res.responseBody = Blob.valueOf(JSON.serialize(lstResponse));

                if (Label.Enable_Logs == 'TRUE') {
                    writeLog(data, JSON.serialize(lstResponse), 'Invoice', String.valueOf(res.statusCode));
                }
            }
            // Any other ?value= falls through to the parameter error.
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

    /**
     * Invoice handler.
     *
     * Each map in incoming represents one parent invoice; it may
     * carry a nested array under "Invoice_Items" of child line items.
     *
     * Lookup resolution (single SOQL per object across the whole batch):
     *   Customer__c (Account)         <- payload Customer_Code__c       -> Account.SAP_Code__c
     *   Order__c    (Order)           <- payload OrderId__c             -> Order.SAP_Code__c
     *   OwnerId     (User)            <- payload Employee_Code__c       -> User.Employee_Code__c
     *   Product__c  (Product2)        <- line ProductCode__c            -> Product2.ProductCode
     *   Order_Product__c (OrderItem)  <- line OrderItemId__c            -> OrderItem.SAP_OrderItem_Id__c
     *
     * Upsert keys:
     *   Invoice__c       by Invoice_Id__c
     *   Invoice_Item__c  by lineItemId__c
     *
     * SAP sync stamps (SAP_Sync_Status__c = true, Last_ERP_Sync_Date__c
     * = now) are written to the parent invoice on every successful
     * upsert.
     */
    private static List<Response> handleInvoice(List<Map<String, Object>> incoming) {
        List<Response> lstResponse = new List<Response>();
        DateTime nowStamp = DateTime.now();

        // ---- Pre-pass: collect all the codes we'll need to resolve ----
        Set<String> customerCodes = new Set<String>();
        Set<String> orderCodes    = new Set<String>();
        Set<String> employeeCodes = new Set<String>();
        Set<String> productCodes  = new Set<String>();
        Set<String> orderItemIds  = new Set<String>();

        for (Map<String, Object> inv : incoming) {
            addIfNotBlank(customerCodes, inv.get('Customer_Code__c'));
            addIfNotBlank(orderCodes,    inv.get('OrderId__c'));
            addIfNotBlank(employeeCodes, inv.get('Employee_Code__c'));

            Object items = inv.get('Invoice_Items');
            if (items instanceof List<Object>) {
                for (Object item : (List<Object>) items) {
                    if (item instanceof Map<String, Object>) {
                        Map<String, Object> li = (Map<String, Object>) item;
                        addIfNotBlank(productCodes, li.get('ProductCode__c'));
                        addIfNotBlank(orderItemIds, li.get('OrderItemId__c'));
                        addIfNotBlank(orderCodes,   li.get('OrderId__c'));
                    }
                }
            }
        }

        // ---- Resolve every lookup with one SOQL each ----
        Map<String, Id> accountByCode  = new Map<String, Id>();
        if (!customerCodes.isEmpty()) {
            for (Account a : [SELECT Id, SAP_Code__c FROM Account WHERE SAP_Code__c IN :customerCodes]) {
                accountByCode.put(a.SAP_Code__c, a.Id);
            }
        }

        Map<String, Id> orderByCode = new Map<String, Id>();
        if (!orderCodes.isEmpty()) {
            for (Order o : [SELECT Id, SAP_Code__c FROM Order WHERE SAP_Code__c IN :orderCodes]) {
                orderByCode.put(o.SAP_Code__c, o.Id);
            }
        }

        Map<String, Id> userByEmpCode = new Map<String, Id>();
        if (!employeeCodes.isEmpty()) {
            for (User u : [SELECT Id, Employee_Code__c FROM User WHERE Employee_Code__c IN :employeeCodes]) {
                userByEmpCode.put(u.Employee_Code__c, u.Id);
            }
        }

        Map<String, Id> productByCode = new Map<String, Id>();
        if (!productCodes.isEmpty()) {
            for (Product2 p : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN :productCodes]) {
                productByCode.put(p.ProductCode, p.Id);
            }
        }

        Map<String, Id> orderItemBySapId = new Map<String, Id>();
        if (!orderItemIds.isEmpty()) {
            for (OrderItem oi : [SELECT Id, SAP_OrderItem_Id__c FROM OrderItem WHERE SAP_OrderItem_Id__c IN :orderItemIds]) {
                orderItemBySapId.put(oi.SAP_OrderItem_Id__c, oi.Id);
            }
        }

        // ---- Upsert each invoice + its line items ----
        for (Map<String, Object> inv : incoming) {
            String invoiceId = stringOf(inv.get('Invoice_Id__c'));
            try {
                Map<String, Object> invMap = new Map<String, Object>(inv);
                invMap.remove('Invoice_Items');
                invMap.put('attributes', new Map<String, String>{
                    'type' => 'Invoice__c',
                    'referenceId' => 'ref1'
                });
                Invoice__c parent = (Invoice__c) JSON.deserialize(JSON.serialize(invMap), Sobject.class);

                String custCode = stringOf(inv.get('Customer_Code__c'));
                if (String.isNotBlank(custCode) && accountByCode.containsKey(custCode)) {
                    parent.Customer__c = accountByCode.get(custCode);
                }
                String ordCode = stringOf(inv.get('OrderId__c'));
                if (String.isNotBlank(ordCode) && orderByCode.containsKey(ordCode)) {
                    parent.Order__c = orderByCode.get(ordCode);
                }
                String empCode = stringOf(inv.get('Employee_Code__c'));
                if (String.isNotBlank(empCode) && userByEmpCode.containsKey(empCode)) {
                    parent.OwnerId = userByEmpCode.get(empCode);
                }

                parent.SAP_Sync_Status__c = true;
                parent.Last_ERP_Sync_Date__c = nowStamp;

                upsert parent Invoice__c.Invoice_Id__c;

                // ---- Children ----
                Object items = inv.get('Invoice_Items');
                if (items instanceof List<Object>) {
                    List<Invoice_Item__c> lineItems = new List<Invoice_Item__c>();
                    for (Object item : (List<Object>) items) {
                        if (!(item instanceof Map<String, Object>)) continue;
                        Map<String, Object> li = (Map<String, Object>) item;

                        Map<String, Object> liMap = new Map<String, Object>(li);
                        liMap.put('attributes', new Map<String, String>{
                            'type' => 'Invoice_Item__c',
                            'referenceId' => 'ref1'
                        });
                        Invoice_Item__c child = (Invoice_Item__c) JSON.deserialize(JSON.serialize(liMap), Sobject.class);

                        // Always link to the just-upserted parent.
                        child.Invoice__c = parent.Id;

                        String pcode = stringOf(li.get('ProductCode__c'));
                        if (String.isNotBlank(pcode) && productByCode.containsKey(pcode)) {
                            child.Product__c = productByCode.get(pcode);
                        }
                        String oiId = stringOf(li.get('OrderItemId__c'));
                        if (String.isNotBlank(oiId) && orderItemBySapId.containsKey(oiId)) {
                            child.Order_Product__c = orderItemBySapId.get(oiId);
                        }
                        String liOrdCode = stringOf(li.get('OrderId__c'));
                        if (String.isNotBlank(liOrdCode) && orderByCode.containsKey(liOrdCode)) {
                            child.Order__c = orderByCode.get(liOrdCode);
                        }
                        lineItems.add(child);
                    }
                    if (!lineItems.isEmpty()) {
                        upsert lineItems Invoice_Item__c.lineItemId__c;
                    }
                }

                lstResponse.add(new Response('Success', invoiceId));
            } catch (Exception ex) {
                lstResponse.add(new Response('Failure', invoiceId, ex.getMessage()));
            }
        }

        return lstResponse;
    }

    private static void addIfNotBlank(Set<String> target, Object val) {
        if (val == null) return;
        String s = String.valueOf(val);
        if (String.isNotBlank(s)) target.add(s);
    }

    private static String stringOf(Object val) {
        return val == null ? null : String.valueOf(val);
    }

    private static void writeLog(String reqBody, String resBody, String objectName, String statusCode) {
        try {
            Integer maxSize = 32000;
            if (reqBody != null && reqBody.length() > maxSize) {
                reqBody = reqBody.substring(0, maxSize);
            }
            if (resBody != null && resBody.length() > maxSize) {
                resBody = resBody.substring(0, maxSize);
            }
            Log__c rec = new Log__c();
            rec.Request__c     = reqBody;
            rec.Response__c    = resBody;
            rec.Object__c      = objectName;
            rec.Status_Code__c = statusCode;
            insert rec;
        } catch (Exception e) {
            System.debug('SAPGetData logging failed: ' + e.getMessage());
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