@RestResource(urlMapping='/sapapi/*')
global class sapApiController {

    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String key = req.params.get('key');
        String objectName = req.params.get('value');
        String orderCustomerCode = req.params.get('customerCode');
        String orderCode = req.params.get('orderCode');

        List<SObject> records = new List<SObject>();
        String jsonString = '';

        if (Label.API_Key != key) {
            res.statusCode = 401;
            res.responseBody = Blob.valueOf('{"message":"Unauthorized"}');
            return;
        }

        if (objectName == 'customer' || String.isBlank(objectName)) {
            List<Account> aList = [
                SELECT Id, Name, Status__c, Customer_Type__c, Customer_Category__c,
                    Speciality__c, Business_Vertical__c, Region__c,
                    Purchase_Value_Life_Time__c, Previous_History__c,
                    Bank_Name__c, Branch_Name__c, Beneficiary_Name__c, Branch_Address__c,
                    IFSC_CODE__c, GST_Number__c, PAN_Number__c,
                    Email__c, Country_Code_Phone__c, Phone, Website,
                    BillingCity, BillingCountryCode, BillingStateCode, BillingStreet, BillingPostalCode,
                    SAP_Customer_Code__c, Customer_Code__c,
                    (SELECT Id, Address_Code__c,
                        Address__City__s, Address__Street__s, Address__StateCode__s,
                        Address__PostalCode__s, Address__CountryCode__s
                     FROM Shipping_Addresses__r)
                FROM Account
                LIMIT 200
            ];
            records.addAll((List<SObject>) aList);
        } else if (objectName == 'order') {
            List<Order> oList;
            if (String.isNotBlank(orderCode)) {
                oList = [
                    SELECT Id, Name, EffectiveDate, EndDate, OrderId__c, Status,
                        BillingCity, BillingCountryCode, BillingStateCode, BillingStreet, BillingPostalCode,
                        ShippingCity, ShippingCountryCode, ShippingStateCode, ShippingStreet, ShippingPostalCode,
                        CurrencyIsoCode, Customer_Code__c, Business_Vertical__c, Sub_Vertical__c,
                        Delivery__c, Contract_Period_From_Date__c, Contract_Period_End_Date__c,
                        Description, Employee_Code__c, TotalAmount,
                        (SELECT Id, OrderItemNumber, Order.OrderId__c, Product2.ProductCode,
                            Quantity, UnitPrice, Tax__c, Tax_Amount__c, TotalPrice
                         FROM OrderItems),
                        (SELECT Id, OrderId__c, Name, Payment_Term__c, Percentage__c
                         FROM Payment_Terms__r)
                    FROM Order
                    WHERE OrderId__c = :orderCode
                    LIMIT 200
                ];
            } else if (String.isNotBlank(orderCustomerCode)) {
                oList = [
                    SELECT Id, Name, EffectiveDate, EndDate, OrderId__c, Status,
                        BillingCity, BillingCountryCode, BillingStateCode, BillingStreet, BillingPostalCode,
                        ShippingCity, ShippingCountryCode, ShippingStateCode, ShippingStreet, ShippingPostalCode,
                        CurrencyIsoCode, Customer_Code__c, Business_Vertical__c, Sub_Vertical__c,
                        Delivery__c, Contract_Period_From_Date__c, Contract_Period_End_Date__c,
                        Description, Employee_Code__c, TotalAmount,
                        (SELECT Id, OrderItemNumber, Order.OrderId__c, Product2.ProductCode,
                            Quantity, UnitPrice, Tax__c, Tax_Amount__c, TotalPrice
                         FROM OrderItems),
                        (SELECT Id, OrderId__c, Name, Payment_Term__c, Percentage__c
                         FROM Payment_Terms__r)
                    FROM Order
                    WHERE Customer_Code__c = :orderCustomerCode
                    LIMIT 200
                ];
            } else {
                oList = [
                    SELECT Id, Name, EffectiveDate, EndDate, OrderId__c, Status,
                        BillingCity, BillingCountryCode, BillingStateCode, BillingStreet, BillingPostalCode,
                        ShippingCity, ShippingCountryCode, ShippingStateCode, ShippingStreet, ShippingPostalCode,
                        CurrencyIsoCode, Customer_Code__c, Business_Vertical__c, Sub_Vertical__c,
                        Delivery__c, Contract_Period_From_Date__c, Contract_Period_End_Date__c,
                        Description, Employee_Code__c, TotalAmount,
                        (SELECT Id, OrderItemNumber, Order.OrderId__c, Product2.ProductCode,
                            Quantity, UnitPrice, Tax__c, Tax_Amount__c, TotalPrice
                         FROM OrderItems),
                        (SELECT Id, OrderId__c, Name, Payment_Term__c, Percentage__c
                         FROM Payment_Terms__r)
                    FROM Order
                    LIMIT 200
                ];
            }
            records.addAll((List<SObject>) oList);
        }

        Object raw = JSON.deserializeUntyped(JSON.serialize(records));
        Object cleaned = clean(raw);
        jsonString = JSON.serialize(cleaned);

        res.addHeader('Content-Type', 'application/json');
        res.statusCode = 200;
        res.responseBody = Blob.valueOf(jsonString);
    }

    @HttpPost
    global static response doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        response result = new response();

        String key = req.params.get('key');
        if (Label.API_Key != key) {
            res.statusCode = 401;
            result.Status = 'Failure';
            result.Message = 'Unauthorized';
            return result;
        }

        customerStatusPayload payload;
        try {
            payload = (customerStatusPayload) JSON.deserialize(
                req.requestBody.toString(), customerStatusPayload.class
            );
        } catch (Exception e) {
            res.statusCode = 400;
            result.Status = 'Failure';
            result.Message = 'Invalid payload: ' + e.getMessage();
            return result;
        }

        if (String.isBlank(payload.CustomerCode)) {
            res.statusCode = 400;
            result.Status = 'Failure';
            result.Message = 'CustomerCode is required';
            return result;
        }

        List<Account> matches = [
            SELECT Id, Customer_Code__c, SAP_Customer_Code__c, SAP_Response__c
            FROM Account
            WHERE Customer_Code__c = :payload.CustomerCode
            LIMIT 1
        ];
        if (matches.isEmpty()) {
            res.statusCode = 404;
            result.Status = 'Failure';
            result.Message = 'No Account found for CustomerCode ' + payload.CustomerCode;
            return result;
        }

        Account acc = matches[0];
        acc.SAP_Response__c = payload.SAPResponse;
        if (payload.Status == 'Success') {
            acc.SAP_Customer_Code__c = payload.CustomerCode;
        }

        try {
            update acc;
        } catch (DmlException e) {
            res.statusCode = 500;
            result.SF_RecordId = acc.Id;
            result.Status = 'Failure';
            result.Message = e.getMessage();
            return result;
        }

        res.statusCode = 200;
        result.SF_RecordId = acc.Id;
        result.Status = 'Success';
        result.Message = 'Account updated';
        return result;
    }

    global class customerStatusPayload {
        public String CustomerCode;
        public String SAPResponse;
        public String Status;
    }

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
        public String TallyUniqueId;
        public String Status;
        public String Message;
    }
}
