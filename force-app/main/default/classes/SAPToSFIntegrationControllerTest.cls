@isTest
private class SAPToSFIntegrationControllerTest {

    @TestSetup
    static void setupTestData() {
        Account acc = new Account(
            Name = 'Test Hospital',
            Phone = '1234567890',
            Website = 'www.testhospital.com',
            Industry = 'Healthcare',
            BillingStreet = '123 Main St',
            BillingCity = 'Mumbai',
            BillingState = 'Maharashtra',
            BillingPostalCode = '400001',
            BillingCountry = 'India',
            ShippingStreet = '456 Ship St',
            ShippingCity = 'Delhi',
            ShippingState = 'Delhi',
            ShippingPostalCode = '110001',
            ShippingCountry = 'India'
        );
        insert acc;

        Contact con = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john@testhospital.com',
            Phone = '9876543210',
            Title = 'Manager',
            Department = 'Procurement',
            AccountId = acc.Id
        );
        insert con;

        Product2 prod = new Product2(
            Name = 'Test Product',
            ProductCode = 'PROD-001',
            Item_Code__c = 'PROD-001',
            SAP_Item_Code__c = 'SAP-001',
            IsActive = true,
            Description = 'Test product description'
        );
        insert prod;
    }

    // --- POST Tests ---

    @isTest
    static void testPostProductMasterSuccess() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SAPToSF';
        req.httpMethod = 'POST';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'productMaster');

        String jsonBody = '{"data":[{"ProductCode":"TEST-001","Name":"New Product","SAP_Item_Code__c":"SAP-TEST-001","IsActive":"true"}]}';
        req.requestBody = Blob.valueOf(jsonBody);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        SAPToSFIntegrationController.doPost();
        Test.stopTest();

        System.assert(res.statusCode == 200 || res.statusCode == 207, 'Expected 200 or 207');
    }

    @isTest
    static void testPostProductMasterMultipleItems() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SAPToSF';
        req.httpMethod = 'POST';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'productMaster');

        String jsonBody = '{"data":[' +
            '{"ProductCode":"MULTI-001","Name":"Product One","SAP_Item_Code__c":"SAP-M1","IsActive":"true"},' +
            '{"ProductCode":"MULTI-002","Name":"Product Two","SAP_Item_Code__c":"SAP-M2","IsActive":"false",' +
            '"Tax__c":"18","Quantity_Pack_Size__c":"10","Description":"Desc","Remarks__c":"Note",' +
            '"Product_Image_URL__c":"http://img1.png","Product_Image_URL_2__c":"http://img2.png",' +
            '"Product_Image_URL_3__c":"http://img3.png","Any_Other_Levies__c":"5% cess"}' +
            ']}';
        req.requestBody = Blob.valueOf(jsonBody);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        SAPToSFIntegrationController.doPost();
        Test.stopTest();

        System.assert(res.statusCode == 200 || res.statusCode == 207, 'Expected 200 or 207');
    }

    @isTest
    static void testPostInvalidKey() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SAPToSF';
        req.httpMethod = 'POST';
        req.params.put('key', 'WRONG_KEY');
        req.params.put('value', 'productMaster');
        req.requestBody = Blob.valueOf('{"data":[]}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        SAPToSFIntegrationController.doPost();
        Test.stopTest();

        System.assertEquals(401, res.statusCode, 'Expected 401 for invalid key');
    }

    @isTest
    static void testPostBlankKey() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SAPToSF';
        req.httpMethod = 'POST';
        req.params.put('key', '');
        req.params.put('value', 'productMaster');
        req.requestBody = Blob.valueOf('{"data":[]}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        SAPToSFIntegrationController.doPost();
        Test.stopTest();

        System.assertEquals(401, res.statusCode, 'Expected 401 for blank key');
    }

    @isTest
    static void testPostInvalidValue() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SAPToSF';
        req.httpMethod = 'POST';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'invalidRoute');
        req.requestBody = Blob.valueOf('{"data":[]}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        SAPToSFIntegrationController.doPost();
        Test.stopTest();

        System.assertEquals(403, res.statusCode, 'Expected 403 for invalid value');
    }

    @isTest
    static void testPostEmptyData() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SAPToSF';
        req.httpMethod = 'POST';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'productMaster');
        req.requestBody = Blob.valueOf('{"data":[]}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        SAPToSFIntegrationController.doPost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Expected 400 for empty data');
    }

    @isTest
    static void testPostUpsertExistingProduct() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SAPToSF';
        req.httpMethod = 'POST';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'productMaster');

        String jsonBody = '{"data":[{"ProductCode":"PROD-001","Name":"Updated Product","SAP_Item_Code__c":"SAP-001","IsActive":"true"}]}';
        req.requestBody = Blob.valueOf(jsonBody);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        SAPToSFIntegrationController.doPost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Expected 200 for successful upsert');
    }

    // --- GET Product Tests ---

    @isTest
    static void testGetProductMaster() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SAPToSF';
        req.httpMethod = 'GET';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'productMaster');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        SAPToSFIntegrationController.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Expected 200');
    }

    @isTest
    static void testGetProductMasterByCode() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SAPToSF';
        req.httpMethod = 'GET';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'productMaster');
        req.params.put('productCode', 'PROD-001');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        SAPToSFIntegrationController.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Expected 200');
    }

    @isTest
    static void testGetInvalidKey() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SAPToSF';
        req.httpMethod = 'GET';
        req.params.put('key', 'BAD_KEY');
        req.params.put('value', 'productMaster');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        SAPToSFIntegrationController.doGet();
        Test.stopTest();

        System.assertEquals(401, res.statusCode, 'Expected 401');
    }

    @isTest
    static void testGetInvalidValue() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SAPToSF';
        req.httpMethod = 'GET';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'badValue');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        SAPToSFIntegrationController.doGet();
        Test.stopTest();

        System.assertEquals(403, res.statusCode, 'Expected 403');
    }

    // --- GET Customer Details Tests ---

    @isTest
    static void testGetCustomerDetailsByName() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Hospital' LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SAPToSF';
        req.httpMethod = 'GET';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'customerDetails');
        req.params.put('accountId', acc.Id);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        SAPToSFIntegrationController.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Expected 200');
        String body = res.responseBody.toString();
        System.assert(body.contains('Test Hospital'), 'Should contain account name');
        System.assert(body.contains('Contacts'), 'Should contain contacts');
    }

    @isTest
    static void testGetCustomerDetailsBySAPCode() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SAPToSF';
        req.httpMethod = 'GET';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'customerDetails');
        req.params.put('sapCustomerCode', 'NONEXISTENT');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        SAPToSFIntegrationController.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Expected 200');
        String body = res.responseBody.toString();
        System.assertEquals('[]', body, 'Should return empty array');
    }

    @isTest
    static void testGetCustomerDetailsWithStatus() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SAPToSF';
        req.httpMethod = 'GET';
        req.params.put('key', Label.SAP_API);
        req.params.put('value', 'customerDetails');
        req.params.put('status', 'Active');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        SAPToSFIntegrationController.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Expected 200');
    }
}
