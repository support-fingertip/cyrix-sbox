// Test class for SAPProductController
/****************************************************************
* Class Name   : SAPProductControllerTest
* Company      : Fingertipplus
* Created Date : 30-03-2026
* @description : Test class for SAPProductController REST API
**************************************************************/
@isTest
private class SAPProductControllerTest {

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

    @isTest
    static void testPostUpsertProducts() {
        String jsonBody = '{"data":[{"Company_Id__c":"Dev","Product_Code__c":"F01707","SKU__c":"F01707","Item_Description__c":"Wireless Mouse Logitech","Name":"Wireless Mouse Logitech","Brand__c":"Logitech","Sales_Tax__c":"18","Purchase_Tax__c":"18","HSN_Code__c":"8471","GST__c":"18","Fixed_Price_Item__c":"N"}]}';

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/SAPProduct';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPProductController.upsertProducts();
        Test.stopTest();

        System.assertNotEquals(null, RestContext.response.responseBody);
        Product2 created = [SELECT Name, Item_Code__c, Brand__c FROM Product2 WHERE Item_Code__c = 'F01707'];
        System.assertEquals('Wireless Mouse Logitech', created.Name);
        System.assertEquals('Logitech', created.Brand__c);
    }

    @isTest
    static void testPostUpsertMultipleProducts() {
        String jsonBody = '{"data":[' +
            '{"Company_Id__c":"Dev","Product_Code__c":"F01708","SKU__c":"F01708","Item_Description__c":"Product A","Name":"Product A","Brand__c":"BrandA","Sales_Tax__c":"18","Purchase_Tax__c":"18","HSN_Code__c":"9018","GST__c":"18","Fixed_Price_Item__c":"N"},' +
            '{"Company_Id__c":"Dev","Product_Code__c":"F01709","SKU__c":"F01709","Item_Description__c":"Product B","Name":"Product B","Brand__c":"BrandB","Sales_Tax__c":"12","Purchase_Tax__c":"12","HSN_Code__c":"8471","GST__c":"12","Fixed_Price_Item__c":"Y"}' +
            ']}';

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/SAPProduct';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPProductController.upsertProducts();
        Test.stopTest();

        List<Product2> products = [SELECT Id FROM Product2 WHERE Item_Code__c IN ('F01708', 'F01709')];
        System.assertEquals(2, products.size(), 'Should create 2 products');
    }

    @isTest
    static void testPostEmptyData() {
        String jsonBody = '{"data":[]}';

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/SAPProduct';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPProductController.upsertProducts();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @isTest
    static void testPostUpdateExisting() {
        String jsonBody = '{"data":[{"Company_Id__c":"Dev","Product_Code__c":"F01706","SKU__c":"F01706","Item_Description__c":"Updated Speaker","Name":"Updated Speaker Zebronics","Brand__c":"Zebronics","Sales_Tax__c":"18","Purchase_Tax__c":"18","HSN_Code__c":"8518","GST__c":"18","Fixed_Price_Item__c":"N"}]}';

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/SAPProduct';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPProductController.upsertProducts();
        Test.stopTest();

        Product2 updated = [SELECT Name FROM Product2 WHERE Item_Code__c = 'F01706'];
        System.assertEquals('Updated Speaker Zebronics', updated.Name);
    }

    @isTest
    static void testGetAllProducts() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/SAPProduct';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPProductController.getProducts();
        Test.stopTest();

        System.assertNotEquals(null, RestContext.response.responseBody);
        String responseStr = RestContext.response.responseBody.toString();
        System.assert(responseStr.contains('F01706'), 'Response should contain product code');
    }

    @isTest
    static void testGetProductByCode() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/SAPProduct';
        req.httpMethod = 'GET';
        req.params.put('productCode', 'F01706');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPProductController.getProducts();
        Test.stopTest();

        System.assertNotEquals(null, RestContext.response.responseBody);
        String responseStr = RestContext.response.responseBody.toString();
        System.assert(responseStr.contains('Zebronics'), 'Response should contain brand');
    }

    @isTest
    static void testGetProductByCategory() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/SAPProduct';
        req.httpMethod = 'GET';
        req.params.put('category', 'NonExistent');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPProductController.getProducts();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }

    @isTest
    static void testPostInvalidJson() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/SAPProduct';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('invalid json');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        SAPProductController.upsertProducts();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode);
    }
}
