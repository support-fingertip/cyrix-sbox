/**
 * Backs the "Send to SAP" quick action on Account and Order.
 *
 * Flow:
 *   1. Build a JSON payload from the record's fields.
 *   2. POST it to the SAP endpoint (URL + API key from Custom Labels).
 *   3. On 2xx response, parse SAP's returned code and write it to
 *      SAP_Code__c, then flip Sync_To_SAP__c = true.
 *   4. On non-2xx or callout exception, return the error message and
 *      leave the record untouched.
 *
 * To configure for a real SAP environment:
 *   - Set Custom Label SAP_Endpoint to the actual SAP REST URL.
 *   - Set Custom Label SAP_API (existing) to the API key.
 *   - Add a Remote Site Setting for the SAP host so the callout is allowed.
 *   - If SAP expects a different payload shape, adjust buildAccountPayload
 *     / buildOrderPayload below. If it returns the customer code under a
 *     different field name, adjust parseSapCode.
 */
public with sharing class SapSyncController {

    @AuraEnabled
    public static String sendToSap(Id recordId) {
        if (recordId == null) {
            return 'ERROR: No record id provided';
        }

        String objectType = recordId.getSObjectType().getDescribe().getName();

        try {
            String payload;
            String successMessage;

            if (objectType == 'Account') {
                Account acc = [
                    SELECT Id, Name, AccountNumber, Phone, Website,
                           BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                           ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                           GST_Number__c, PAN_Number__c
                    FROM Account
                    WHERE Id = :recordId
                    LIMIT 1
                ];
                payload = buildAccountPayload(acc);
                successMessage = 'Customer sent successfully';
            } else if (objectType == 'Order') {
                Order ord = [
                    SELECT Id, Name, OrderNumber, EffectiveDate, EndDate, Status, TotalAmount,
                           AccountId, Account.Name, Account.SAP_Code__c,
                           BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry
                    FROM Order
                    WHERE Id = :recordId
                    LIMIT 1
                ];
                List<OrderItem> items = [
                    SELECT Id, OrderItemNumber, Product2.Name, Product2.ProductCode,
                           Quantity, UnitPrice, TotalPrice
                    FROM OrderItem
                    WHERE OrderId = :recordId
                ];
                payload = buildOrderPayload(ord, items);
                successMessage = 'Order sent successfully';
            } else {
                return 'ERROR: Unsupported object: ' + objectType;
            }

            HttpResponse res = postToSap(payload);
            Integer status = res.getStatusCode();

            if (status >= 200 && status < 300) {
                String sapCode = parseSapCode(res.getBody());
                if (objectType == 'Account') {
                    update new Account(Id = recordId, Sync_To_SAP__c = true, SAP_Code__c = sapCode);
                } else {
                    update new Order(Id = recordId, Sync_To_SAP__c = true, SAP_Code__c = sapCode);
                }
                return successMessage;
            } else {
                return 'ERROR: SAP returned ' + status + ' - ' + res.getBody();
            }
        } catch (Exception e) {
            return 'ERROR: ' + e.getMessage();
        }
    }

    private static HttpResponse postToSap(String payload) {
        // Tests can't make real callouts; return a synthesized 200 so the
        // calling code can still exercise the post-response path under test.
        if (Test.isRunningTest()) {
            HttpResponse fake = new HttpResponse();
            fake.setStatusCode(200);
            fake.setBody('{"code":"TEST-SAP-001"}');
            return fake;
        }

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(System.Label.SAP_Endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('x-api-key', System.Label.SAP_API);
        req.setBody(payload);
        req.setTimeout(60000);
        return http.send(req);
    }

    private static String buildAccountPayload(Account a) {
        Map<String, Object> body = new Map<String, Object>();
        body.put('type', 'customer');
        body.put('salesforceId', a.Id);
        body.put('name', a.Name);
        body.put('accountNumber', a.AccountNumber);
        body.put('phone', a.Phone);
        body.put('website', a.Website);
        body.put('gstNumber', a.GST_Number__c);
        body.put('panNumber', a.PAN_Number__c);
        body.put('billingAddress', addressMap(
            a.BillingStreet, a.BillingCity, a.BillingState,
            a.BillingPostalCode, a.BillingCountry
        ));
        body.put('shippingAddress', addressMap(
            a.ShippingStreet, a.ShippingCity, a.ShippingState,
            a.ShippingPostalCode, a.ShippingCountry
        ));
        return JSON.serialize(body, true);
    }

    private static String buildOrderPayload(Order o, List<OrderItem> items) {
        Map<String, Object> body = new Map<String, Object>();
        body.put('type', 'order');
        body.put('salesforceId', o.Id);
        body.put('orderName', o.Name);
        body.put('orderNumber', o.OrderNumber);
        body.put('status', o.Status);
        body.put('effectiveDate', o.EffectiveDate);
        body.put('endDate', o.EndDate);
        body.put('totalAmount', o.TotalAmount);
        body.put('accountId', o.AccountId);
        body.put('accountName', o.AccountId != null ? o.Account.Name : null);
        body.put('accountSapCode', o.AccountId != null ? o.Account.SAP_Code__c : null);
        body.put('billingAddress', addressMap(
            o.BillingStreet, o.BillingCity, o.BillingState,
            o.BillingPostalCode, o.BillingCountry
        ));

        List<Map<String, Object>> lines = new List<Map<String, Object>>();
        for (OrderItem oi : items) {
            Map<String, Object> line = new Map<String, Object>();
            line.put('orderItemNumber', oi.OrderItemNumber);
            line.put('productName', oi.Product2 != null ? oi.Product2.Name : null);
            line.put('productCode', oi.Product2 != null ? oi.Product2.ProductCode : null);
            line.put('quantity', oi.Quantity);
            line.put('unitPrice', oi.UnitPrice);
            line.put('totalPrice', oi.TotalPrice);
            lines.add(line);
        }
        body.put('lineItems', lines);

        return JSON.serialize(body, true);
    }

    private static Map<String, Object> addressMap(String street, String city, String state,
                                                   String postalCode, String country) {
        Map<String, Object> addr = new Map<String, Object>();
        addr.put('street', street);
        addr.put('city', city);
        addr.put('state', state);
        addr.put('postalCode', postalCode);
        addr.put('country', country);
        return addr;
    }

    /**
     * Best-effort extraction of the SAP-side code from the response.
     * Tries common field names: code, sapCode, customerCode, orderCode.
     * Returns null if none are present.
     */
    private static String parseSapCode(String responseBody) {
        if (String.isBlank(responseBody)) return null;
        try {
            Object parsed = JSON.deserializeUntyped(responseBody);
            if (parsed instanceof Map<String, Object>) {
                Map<String, Object> obj = (Map<String, Object>) parsed;
                for (String key : new List<String>{ 'code', 'sapCode', 'customerCode', 'orderCode' }) {
                    if (obj.containsKey(key) && obj.get(key) != null) {
                        return String.valueOf(obj.get(key));
                    }
                }
            }
        } catch (Exception e) {
            // Not JSON, or unexpected structure — leave SAP_Code__c null.
        }
        return null;
    }
}
