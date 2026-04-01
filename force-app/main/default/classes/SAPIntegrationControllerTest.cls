// Test class for SAPIntegrationController.
/****************************************************************
* Class Name   : SAPIntegrationControllerTest
* Company      : Fingertipplus
* Created Date : 01-04-2026
* @description : Test class for SAPIntegrationController REST API
**************************************************************/
@isTest
private class SAPIntegrationControllerTest {

    @TestSetup
    static void setupTestData() {
        Product2 prod = new Product2(
            Name = 'Bluetooth Speaker Zebronics',
            Item_Code__c = 'F01706',
            ProductCode = 'F01706',
            SAP_Item_Code__c = 'SAP-F01706',
            Product_Category__c = 'General',
            Product_Vertical__c = 'Healthcare',
            Product_Type__c = 'Accessories',
            Source__c = 'SAP',
            Equipment_Name__c = 'Speaker',
            Make__c = 'Zebronics',
            Model__c = 'ZEB-100',
            Brand__c = 'Zebronics',
            HSN_Code__c = '8518',
            Tax__c = 18,
            Description = 'Bluetooth Speaker Zebronics',
            IsActive = true
        );
        insert prod;

        Account acc = new Account(
            Name = 'Test Hospital',
            Customer_Code__c = 'CUST-001',
            BillingStreet = '123 Main Street',
            BillingCity = 'Mumbai',
            BillingState = 'Maharashtra',
            BillingPostalCode = '400001',
            BillingCountry = 'India',
            ShippingStreet = '456 Branch Road',
            ShippingCity = 'Pune',
            ShippingState = 'Maharashtra',
            ShippingPostalCode = '411001',
            ShippingCountry = 'India'
        );
        insert acc;

        Shipping_Address__c sa = new Shipping_Address__c(
            Account__c = acc.Id,
            Same_as_BillingAddress__c = false
        );
        insert sa;
    }

    // ---- POST Tests ----

    @isTest
    static void testPostUpsertSuccess() {
        String jsonBody = '{"data":[{' +
            '"ProductCode":"F01707",' +
            '"Name":"Wireless Mouse Logitech",' +
            '"SAP_Item_Code__c":"SAP-F01707",' +
            '"Product_Category__c":"General",' +
            '"Product_Vertical__c":"Healthcare",' +
            '"Product_Type__c":"Accessories",' +
            '"Source__c":"SAP",' +
            '"Equipment_Name__c":"Mouse",' +
            '"Make__c":"Logitech",' +
            '"Model__c":"M235",' +
            '"OEM_Part_Number__c":"LOG-M235",' +
            '"QuantityUnitOfMeasure":"Each",' +
            '"Compatibility__c":"PC, Laptop",' +
            '"Specification__c":"Wireless 2.4GHz",' +
            '"HSN_Code__c":"8471",' +
            '"Tax__c":"18",' +
            '"IsActive":"true",' +
            '"Description":"Wireless Mouse Logitech M235",' +
            '"Remarks__c":"None",' +
            '"Any_Other_Levies__c":"No",' +
            '"Brand__c":"Logitech"' +
            '}]}';

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api';
        req.httpMethod = 'POST';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'productMaster');
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPIntegrationController.doPost();
        Test.stopTest();

        String responseStr = RestContext.response.responseBody.toString();
        System.assert(responseStr.contains('"Status":"Success"'), 'Response should indicate success');

        Product2 created = [SELECT Name, Make__c, Model__c, Remarks__c FROM Product2 WHERE Item_Code__c = 'F01707'];
        System.assertEquals('Wireless Mouse Logitech', created.Name);
        System.assertEquals('Logitech', created.Make__c);
        System.assertEquals('M235', created.Model__c);
        System.assertEquals('None', created.Remarks__c);
    }

    @isTest
    static void testPostUpsertMultiple() {
        String jsonBody = '{"data":[' +
            '{"ProductCode":"F01708","Name":"Product A","SAP_Item_Code__c":"SAP-A","Product_Category__c":"General","Make__c":"BrandA","HSN_Code__c":"9018","Tax__c":"18","IsActive":"true"},' +
            '{"ProductCode":"F01709","Name":"Product B","SAP_Item_Code__c":"SAP-B","Product_Category__c":"General","Make__c":"BrandB","HSN_Code__c":"8471","Tax__c":"12","IsActive":"true"}' +
            ']}';

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api';
        req.httpMethod = 'POST';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'productMaster');
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPIntegrationController.doPost();
        Test.stopTest();

        List<Product2> products = [SELECT Id FROM Product2 WHERE Item_Code__c IN ('F01708', 'F01709')];
        System.assertEquals(2, products.size());
    }

    @isTest
    static void testPostUpdateExisting() {
        String jsonBody = '{"data":[{"ProductCode":"F01706","Name":"Updated Speaker Zebronics","SAP_Item_Code__c":"SAP-F01706","HSN_Code__c":"8518","Tax__c":"18","IsActive":"true"}]}';

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api';
        req.httpMethod = 'POST';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'productMaster');
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPIntegrationController.doPost();
        Test.stopTest();

        Product2 updated = [SELECT Name FROM Product2 WHERE Item_Code__c = 'F01706'];
        System.assertEquals('Updated Speaker Zebronics', updated.Name);
        String responseStr = RestContext.response.responseBody.toString();
        System.assert(responseStr.contains('"Message":"Updated"'));
    }

    @isTest
    static void testPostEmptyData() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api';
        req.httpMethod = 'POST';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'productMaster');
        req.requestBody = Blob.valueOf('{"data":[]}');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPIntegrationController.doPost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @isTest
    static void testPostInvalidJson() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api';
        req.httpMethod = 'POST';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'productMaster');
        req.requestBody = Blob.valueOf('invalid json');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPIntegrationController.doPost();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode);
        String responseStr = RestContext.response.responseBody.toString();
        System.assert(responseStr.contains('"Status":"Failure"'));
    }

    @isTest
    static void testPostItemFailure() {
        String jsonBody = '{"data":[' +
            '{"ProductCode":"F01710","Name":"Good Product","HSN_Code__c":"9018","Tax__c":"18","IsActive":"true"},' +
            '{"ProductCode":"F01711","Name":"","HSN_Code__c":"","Tax__c":"18","IsActive":"true"}' +
            ']}';

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api';
        req.httpMethod = 'POST';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'productMaster');
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPIntegrationController.doPost();
        Test.stopTest();

        System.assertNotEquals(null, RestContext.response.responseBody);
    }

    // ---- API Key Tests ----

    @isTest
    static void testPostUnauthorized() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api';
        req.httpMethod = 'POST';
        req.params.put('key', 'INVALID_KEY');
        req.params.put('value', 'productMaster');
        req.requestBody = Blob.valueOf('{"data":[]}');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPIntegrationController.doPost();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode);
        String responseStr = RestContext.response.responseBody.toString();
        System.assert(responseStr.contains('Invalid Key'));
    }

    @isTest
    static void testPostMissingKey() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"data":[]}');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPIntegrationController.doPost();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode);
    }

    @isTest
    static void testPostInvalidValue() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api';
        req.httpMethod = 'POST';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'invalidValue');
        req.requestBody = Blob.valueOf('{"data":[]}');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPIntegrationController.doPost();
        Test.stopTest();

        System.assertEquals(403, RestContext.response.statusCode);
        String responseStr = RestContext.response.responseBody.toString();
        System.assert(responseStr.contains('Invalid Parameter'));
    }

    @isTest
    static void testGetUnauthorized() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api';
        req.httpMethod = 'GET';
        req.params.put('key', 'BAD_KEY');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPIntegrationController.doGet();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode);
        String responseStr = RestContext.response.responseBody.toString();
        System.assert(responseStr.contains('Invalid Key'));
    }

    @isTest
    static void testGetInvalidValue() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api';
        req.httpMethod = 'GET';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'invalidValue');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPIntegrationController.doGet();
        Test.stopTest();

        System.assertEquals(403, RestContext.response.statusCode);
    }

    // ---- GET Product Tests ----

    @isTest
    static void testGetAllProducts() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api';
        req.httpMethod = 'GET';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'productMaster');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPIntegrationController.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        String responseStr = RestContext.response.responseBody.toString();
        System.assert(responseStr.contains('F01706'), 'Should contain product code');
        System.assert(responseStr.contains('"Status":"Success"'));
    }

    @isTest
    static void testGetProductByCode() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api';
        req.httpMethod = 'GET';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'productMaster');
        req.params.put('productCode', 'F01706');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPIntegrationController.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        String responseStr = RestContext.response.responseBody.toString();
        System.assert(responseStr.contains('Bluetooth Speaker Zebronics'), 'Should contain product name');
    }

    @isTest
    static void testGetProductByCategory() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api';
        req.httpMethod = 'GET';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'productMaster');
        req.params.put('category', 'NonExistent');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPIntegrationController.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        String responseStr = RestContext.response.responseBody.toString();
        System.assertEquals('[]', responseStr);
    }

    // ---- GET Customer Address Tests ----

    @isTest
    static void testGetCustomerAddresses() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api';
        req.httpMethod = 'GET';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'customerAddress');
        req.params.put('customerCode', 'CUST-001');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPIntegrationController.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        String responseStr = RestContext.response.responseBody.toString();
        System.assert(responseStr.contains('Test Hospital'), 'Should contain account name');
        System.assert(responseStr.contains('BillingAddress'), 'Should contain billing address');
        System.assert(responseStr.contains('ShippingAddress'), 'Should contain shipping address');
        System.assert(responseStr.contains('Mumbai'), 'Should contain billing city');
        System.assert(responseStr.contains('Pune'), 'Should contain shipping city');
    }

    @isTest
    static void testGetCustomerAddressByAccountId() {
        Account acc = [SELECT Id FROM Account WHERE Customer_Code__c = 'CUST-001' LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api';
        req.httpMethod = 'GET';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'customerAddress');
        req.params.put('accountId', acc.Id);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPIntegrationController.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        String responseStr = RestContext.response.responseBody.toString();
        System.assert(responseStr.contains('CUST-001'), 'Should contain customer code');
        System.assert(responseStr.contains('AdditionalShippingAddresses'), 'Should contain additional shipping');
    }

    @isTest
    static void testGetCustomerAddressNoFilter() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api';
        req.httpMethod = 'GET';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'customerAddress');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPIntegrationController.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertNotEquals(null, RestContext.response.responseBody);
    }
}
