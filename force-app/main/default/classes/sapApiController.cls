@RestResource(urlMapping='/sapapi/*')
global class sapApiController {

    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String key = req.params.get('key');
        String objectName = req.params.get('value');
        String customerCode = req.params.get('customerCode');
        String orderCode = req.params.get('orderCode');

        getResponse g = new getResponse();
        String jsonString = '';

        if (Label.API_Key != key) {
            res.statusCode = 401;
            res.responseBody = Blob.valueOf('{"message":"Unauthorized"}');
            return;
        }

        if (objectName == 'customer' || String.isBlank(objectName)) {
            List<Account> aList;
            if (String.isNotBlank(customerCode)) {
                aList = [
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
                    WHERE SAP_Customer_Code__c = :customerCode OR Customer_Code__c = :customerCode
                    LIMIT 200
                ];
            } else {
                aList = [
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
            }
            customerResponseWrapper cw = new customerResponseWrapper();
            cw.data = aList;
            g = cw;
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
            } else if (String.isNotBlank(customerCode)) {
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
                    WHERE Customer_Code__c = :customerCode
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
            orderResponseWrapper ow = new orderResponseWrapper();
            ow.data = oList;
            g = ow;
        }

        Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(g));
        Map<String, Object> responseMap = removeAttributes(dataMap);
        jsonString = JSON.serialize(responseMap);
        jsonString = jsonString.replace('{"records":', '').replace('"done":true},', '');

        res.addHeader('Content-Type', 'application/json');
        res.statusCode = 200;
        res.responseBody = Blob.valueOf(jsonString);
    }

    private static Map<String, Object> removeAttributes(Map<String, Object> jsonObj) {
        Set<String> keysToRemove = new Set<String>();
        for (String key : jsonObj.keySet()) {
            Object val = jsonObj.get(key);
            if (key == 'attributes' || key == 'totalSize' || val == null) {
                keysToRemove.add(key);
                continue;
            }
            if (val instanceof Map<String, Object>) {
                removeAttributes((Map<String, Object>) val);
            } else if (val instanceof List<Object>) {
                for (Object item : (List<Object>) val) {
                    if (item instanceof Map<String, Object>) {
                        removeAttributes((Map<String, Object>) item);
                    }
                }
            }
        }
        for (String k : keysToRemove) {
            jsonObj.remove(k);
        }
        return jsonObj;
    }

    global class customerResponseWrapper extends getResponse {
        public List<Account> data = new List<Account>();
    }

    global class orderResponseWrapper extends getResponse {
        public List<Order> data = new List<Order>();
    }

    public class response {
        public String SF_RecordId;
        public String TallyUniqueId;
        public String Status;
        public String Message;
    }

    global virtual class getResponse {
    }
}
