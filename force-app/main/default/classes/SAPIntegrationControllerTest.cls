// Test class for SAPIntegrationController.
/****************************************************************
* Class Name   : SAPIntegrationControllerTest
* Company      : Fingertipplus
* Created Date : 31-03-2026
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
            Brand__c = 'Zebronics',
            HSN_Code__c = '8518',
            Tax__c = 18,
            Standard_Price__c = 1500,
            Source__c = 'Dev',
            Line_Description__c = 'Bluetooth Speaker Zebronics',
            Product_Status__c = 'Active',
            IsActive = true
        );
        insert prod;
    }

    // ---- POST Tests ----

    @isTest
    static void testPostUpsertSuccess() {
        String jsonBody = '{"data":[{"Company_Id__c":"Dev","Product_Code__c":"F01707","SKU__c":"F01707","Item_Description__c":"Wireless Mouse Logitech","Name":"Wireless Mouse Logitech","Brand__c":"Logitech","Sales_Tax__c":"18","Purchase_Tax__c":"18","HSN_Code__c":"8471","GST__c":"18","Fixed_Price_Item__c":"N"}]}';

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

        Product2 created = [SELECT Name, Brand__c FROM Product2 WHERE Item_Code__c = 'F01707'];
        System.assertEquals('Wireless Mouse Logitech', created.Name);
        System.assertEquals('Logitech', created.Brand__c);
    }

    @isTest
    static void testPostUpsertMultiple() {
        String jsonBody = '{"data":[' +
            '{"Company_Id__c":"Dev","Product_Code__c":"F01708","SKU__c":"F01708","Item_Description__c":"Product A","Name":"Product A","Brand__c":"BrandA","Sales_Tax__c":"18","Purchase_Tax__c":"18","HSN_Code__c":"9018","GST__c":"18","Fixed_Price_Item__c":"N"},' +
            '{"Company_Id__c":"Dev","Product_Code__c":"F01709","SKU__c":"F01709","Item_Description__c":"Product B","Name":"Product B","Brand__c":"BrandB","Sales_Tax__c":"12","Purchase_Tax__c":"12","HSN_Code__c":"8471","GST__c":"12","Fixed_Price_Item__c":"Y"}' +
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
        String jsonBody = '{"data":[{"Company_Id__c":"Dev","Product_Code__c":"F01706","SKU__c":"F01706","Item_Description__c":"Updated Speaker","Name":"Updated Speaker Zebronics","Brand__c":"Zebronics","Sales_Tax__c":"18","Purchase_Tax__c":"18","HSN_Code__c":"8518","GST__c":"18","Fixed_Price_Item__c":"N"}]}';

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
    }

    @isTest
    static void testPostItemFailure() {
        // Send item with missing required Name to trigger partial failure
        String jsonBody = '{"data":[' +
            '{"Company_Id__c":"Dev","Product_Code__c":"F01710","SKU__c":"F01710","Item_Description__c":"Good Product","Name":"Good Product","Brand__c":"BrandX","Sales_Tax__c":"18","Purchase_Tax__c":"18","HSN_Code__c":"9018","GST__c":"18","Fixed_Price_Item__c":"N"},' +
            '{"Company_Id__c":"Dev","Product_Code__c":"F01711","SKU__c":"F01711","Item_Description__c":"Bad Product","Name":"","Brand__c":"BrandY","Sales_Tax__c":"18","Purchase_Tax__c":"18","HSN_Code__c":"","GST__c":"18","Fixed_Price_Item__c":"N"}' +
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

    // ---- GET Tests ----

    @isTest
    static void testGetAllProducts() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api';
        req.httpMethod = 'GET';
        req.params.put('key', Label.SAP_API);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPIntegrationController.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        String responseStr = RestContext.response.responseBody.toString();
        System.assert(responseStr.contains('F01706'), 'Should contain product code');
        System.assert(responseStr.contains('"success":true'));
    }

    @isTest
    static void testGetProductByCode() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api';
        req.httpMethod = 'GET';
        req.params.put('key', Label.SAP_API);
        req.params.put('productCode', 'F01706');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPIntegrationController.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        String responseStr = RestContext.response.responseBody.toString();
        System.assert(responseStr.contains('Zebronics'), 'Should contain brand');
    }

    @isTest
    static void testGetProductByCategory() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api';
        req.httpMethod = 'GET';
        req.params.put('key', Label.SAP_API);
        req.params.put('category', 'NonExistent');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPIntegrationController.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        String responseStr = RestContext.response.responseBody.toString();
        System.assert(responseStr.contains('0 product(s) found'));
    }
}
