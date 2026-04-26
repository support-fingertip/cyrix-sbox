/**
 * Inbound REST endpoint that SAP polls to GET Salesforce data.
 * Mirrors the sapApiController pattern from the reference project,
 * but with the field set adapted to this org's Account / Order schema.
 *
 * URL:  /services/apexrest/sapapi/*
 * Auth: ?key=<value of Custom Label API_Key>
 * Selector: ?value=customer | order   (which entity to fetch)
 *
 * Optional filters:
 *   ?customerCode=<SAP_Code__c>   — fetch a specific Account by SAP code
 *   ?orderCode=<SAP_Code__c>      — fetch a specific Order by SAP code
 *
 * If no specific code is supplied, returns the first record that
 * still needs to be sent (Sync_To_SAP__c = false).
 */
@RestResource(urlMapping='/sapapi/*')
global class sapApiController {

    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String key          = req.params.get('key');
        String objectName   = req.params.get('value');
        String customerCode = req.params.get('customerCode');
        String orderCode    = req.params.get('orderCode');

        if (Label.API_Key != key) {
            res.statusCode = 401;
            res.responseBody = Blob.valueOf('{"message":"Unauthorized"}');
            return;
        }

        List<SObject> records = new List<SObject>();

        if (objectName == 'customer' || String.isBlank(objectName)) {
            List<Account> aList;
            if (String.isNotBlank(customerCode)) {
                aList = [
                    SELECT Id, Name, Phone, Website,
                           BillingStreet, BillingCity, BillingState, BillingStateCode,
                           BillingPostalCode, BillingCountry, BillingCountryCode,
                           ShippingStreet, ShippingCity, ShippingState, ShippingStateCode,
                           ShippingPostalCode, ShippingCountry, ShippingCountryCode,
                           GST_Number__c, PAN_Number__c,
                           SAP_Code__c, Sync_To_SAP__c
                    FROM Account
                    WHERE SAP_Code__c = :customerCode
                    LIMIT 1
                ];
            } else {
                aList = [
                    SELECT Id, Name, Phone, Website,
                           BillingStreet, BillingCity, BillingState, BillingStateCode,
                           BillingPostalCode, BillingCountry, BillingCountryCode,
                           ShippingStreet, ShippingCity, ShippingState, ShippingStateCode,
                           ShippingPostalCode, ShippingCountry, ShippingCountryCode,
                           GST_Number__c, PAN_Number__c,
                           SAP_Code__c, Sync_To_SAP__c
                    FROM Account
                    WHERE Sync_To_SAP__c = false
                    LIMIT 1
                ];
            }
            records.addAll((List<SObject>) aList);
        } else if (objectName == 'order') {
            List<Order> oList;
            if (String.isNotBlank(orderCode)) {
                oList = [
                    SELECT Id, Name, OrderNumber, EffectiveDate, EndDate, Status, TotalAmount,
                           CurrencyIsoCode, Description,
                           BillingStreet, BillingCity, BillingState, BillingStateCode,
                           BillingPostalCode, BillingCountry, BillingCountryCode,
                           ShippingStreet, ShippingCity, ShippingState, ShippingStateCode,
                           ShippingPostalCode, ShippingCountry, ShippingCountryCode,
                           Business_Vertical__c,
                           Contract_Period_From_Date__c, Contract_Period_End_Date__c,
                           Delivery__c,
                           SAP_Code__c, Sync_To_SAP__c,
                           AccountId, Account.Name, Account.SAP_Code__c,
                           (SELECT Id, OrderItemNumber, Product2.ProductCode,
                                   Quantity, UnitPrice, TotalPrice
                            FROM OrderItems),
                           (SELECT Id, Name, Payment_Term__c, Percentage__c
                            FROM Payment_Terms__r)
                    FROM Order
                    WHERE SAP_Code__c = :orderCode
                    LIMIT 1
                ];
            } else {
                oList = [
                    SELECT Id, Name, OrderNumber, EffectiveDate, EndDate, Status, TotalAmount,
                           CurrencyIsoCode, Description,
                           BillingStreet, BillingCity, BillingState, BillingStateCode,
                           BillingPostalCode, BillingCountry, BillingCountryCode,
                           ShippingStreet, ShippingCity, ShippingState, ShippingStateCode,
                           ShippingPostalCode, ShippingCountry, ShippingCountryCode,
                           Business_Vertical__c,
                           Contract_Period_From_Date__c, Contract_Period_End_Date__c,
                           Delivery__c,
                           SAP_Code__c, Sync_To_SAP__c,
                           AccountId, Account.Name, Account.SAP_Code__c,
                           (SELECT Id, OrderItemNumber, Product2.ProductCode,
                                   Quantity, UnitPrice, TotalPrice
                            FROM OrderItems),
                           (SELECT Id, Name, Payment_Term__c, Percentage__c
                            FROM Payment_Terms__r)
                    FROM Order
                    WHERE Sync_To_SAP__c = false
                    LIMIT 1
                ];
            }
            records.addAll((List<SObject>) oList);
        }

        Object cleaned = clean(JSON.deserializeUntyped(JSON.serialize(records)));
        String jsonString = JSON.serialize(cleaned);

        res.addHeader('Content-Type', 'application/json');
        res.statusCode = 200;
        res.responseBody = Blob.valueOf(jsonString);
    }

    /**
     * Recursively strips Salesforce-internal metadata (attributes,
     * totalSize, done) and unwraps the {records:[...]} envelope so SAP
     * receives a clean payload of plain field/value JSON.
     */
    private static Object clean(Object node) {
        if (node instanceof Map<String, Object>) {
            Map<String, Object> m = (Map<String, Object>) node;
            if (m.containsKey('records')) {
                return clean(m.get('records'));
            }
            Map<String, Object> result = new Map<String, Object>();
            for (String key : m.keySet()) {
                if (key == 'attributes' || key == 'totalSize' || key == 'done') {
                    continue;
                }
                Object val = m.get(key);
                if (val == null) {
                    continue;
                }
                result.put(key, clean(val));
            }
            return result;
        }
        if (node instanceof List<Object>) {
            List<Object> outList = new List<Object>();
            for (Object item : (List<Object>) node) {
                outList.add(clean(item));
            }
            return outList;
        }
        return node;
    }

    public class response {
        public String SF_RecordId;
        public String SAP_Code;
        public String Status;
        public String Message;
    }
}
