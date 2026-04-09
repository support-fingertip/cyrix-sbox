@isTest
private class SFToSAPIntegrationControllerTest {

    // Mock for successful SAP response
    private class SAPSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"success","message":"Data received"}');
            return res;
        }
    }

    // Mock for failed SAP response
    private class SAPFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"status":"error","message":"Internal Server Error"}');
            return res;
        }
    }

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

    @isTest
    static void testSendCustomerToSAPSuccess() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Hospital' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new SAPSuccessMock());

        Test.startTest();
        SFToSAPIntegrationController.SAPResponse result = SFToSAPIntegrationController.sendCustomerToSAP(acc.Id);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Should be successful');
        System.assertEquals(200, result.statusCode, 'Should return 200');
    }

    @isTest
    static void testSendCustomerToSAPFailure() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Hospital' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new SAPFailureMock());

        Test.startTest();
        SFToSAPIntegrationController.SAPResponse result = SFToSAPIntegrationController.sendCustomerToSAP(acc.Id);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should not be successful');
        System.assertEquals(500, result.statusCode, 'Should return 500');
    }

    @isTest
    static void testSendProductToSAPSuccess() {
        Product2 prod = [SELECT Id FROM Product2 WHERE ProductCode = 'PROD-001' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new SAPSuccessMock());

        Test.startTest();
        SFToSAPIntegrationController.SAPResponse result = SFToSAPIntegrationController.sendProductToSAP(prod.Id);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Should be successful');
        System.assertEquals(200, result.statusCode, 'Should return 200');
    }

    @isTest
    static void testSendProductToSAPFailure() {
        Product2 prod = [SELECT Id FROM Product2 WHERE ProductCode = 'PROD-001' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new SAPFailureMock());

        Test.startTest();
        SFToSAPIntegrationController.SAPResponse result = SFToSAPIntegrationController.sendProductToSAP(prod.Id);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should not be successful');
        System.assertEquals(500, result.statusCode, 'Should return 500');
    }

    @isTest
    static void testSendCustomerToSAPAsync() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Hospital' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new SAPSuccessMock());

        Test.startTest();
        SFToSAPIntegrationController.sendCustomerToSAPAsync(acc.Id);
        Test.stopTest();
    }

    @isTest
    static void testSendProductToSAPAsync() {
        Product2 prod = [SELECT Id FROM Product2 WHERE ProductCode = 'PROD-001' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new SAPSuccessMock());

        Test.startTest();
        SFToSAPIntegrationController.sendProductToSAPAsync(prod.Id);
        Test.stopTest();
    }
}