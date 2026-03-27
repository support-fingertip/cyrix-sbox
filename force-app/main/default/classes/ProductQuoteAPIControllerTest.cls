@isTest
private class ProductQuoteAPIControllerTest {

    @TestSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Test Hospital');
        insert acc;

        Product2 prod = new Product2(
            Name = 'Test SPO2 Probe',
            Item_Code__c = 'IA-TEST-001',
            ProductCode = 'SPO2-001',
            SAP_Item_No__c = 'I-999999',
            Product_Category__c = 'Critical Care',
            Product_Type__c = 'Accessories',
            Make__c = 'Mindray',
            Model__c = 'MEC1000',
            Equipment_Name__c = 'Multipara Monitor',
            Standard_Price__c = 5000,
            Tax__c = 18,
            UOM__c = 'Nos',
            HSN_Code__c = '9018',
            IsActive = true
        );
        insert prod;

        Id stdPricebookId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 5000,
            IsActive = true
        );
        insert pbe;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            AccountId = acc.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(30),
            Amount = 50000,
            Pricebook2Id = stdPricebookId
        );
        insert opp;

        Quote qt = new Quote(
            Name = 'Test Quote API',
            OpportunityId = opp.Id,
            Pricebook2Id = stdPricebookId,
            Quote_Date__c = Date.today(),
            Valid_Till__c = Date.today().addDays(30)
        );
        insert qt;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = qt.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 4500
        );
        insert qli;
    }

    @isTest
    static void testGetProducts() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/ProductQuote';
        req.httpMethod = 'GET';
        req.params.put('key', Label.API_Key);
        req.params.put('type', 'products');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ProductQuoteAPIController.getRecords();
        Test.stopTest();

        System.assertNotEquals(null, RestContext.response.responseBody);
    }

    @isTest
    static void testGetProductById() {
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/ProductQuote';
        req.httpMethod = 'GET';
        req.params.put('key', Label.API_Key);
        req.params.put('type', 'product');
        req.params.put('productId', prod.Id);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ProductQuoteAPIController.getRecords();
        Test.stopTest();

        System.assertNotEquals(null, RestContext.response.responseBody);
    }

    @isTest
    static void testGetProductByItemCode() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/ProductQuote';
        req.httpMethod = 'GET';
        req.params.put('key', Label.API_Key);
        req.params.put('type', 'product');
        req.params.put('itemCode', 'IA-TEST-001');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ProductQuoteAPIController.getRecords();
        Test.stopTest();

        System.assertNotEquals(null, RestContext.response.responseBody);
    }

    @isTest
    static void testGetPriceBook() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/ProductQuote';
        req.httpMethod = 'GET';
        req.params.put('key', Label.API_Key);
        req.params.put('type', 'pricebook');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ProductQuoteAPIController.getRecords();
        Test.stopTest();

        System.assertNotEquals(null, RestContext.response.responseBody);
    }

    @isTest
    static void testGetQuote() {
        Quote qt = [SELECT Id FROM Quote LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/ProductQuote';
        req.httpMethod = 'GET';
        req.params.put('key', Label.API_Key);
        req.params.put('type', 'quote');
        req.params.put('quoteId', qt.Id);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ProductQuoteAPIController.getRecords();
        Test.stopTest();

        System.assertNotEquals(null, RestContext.response.responseBody);
    }

    @isTest
    static void testGetInvalidType() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/ProductQuote';
        req.httpMethod = 'GET';
        req.params.put('key', Label.API_Key);
        req.params.put('type', 'invalid');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ProductQuoteAPIController.getRecords();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @isTest
    static void testUnauthorized() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/ProductQuote';
        req.httpMethod = 'GET';
        req.params.put('key', 'INVALID_KEY');
        req.params.put('type', 'products');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ProductQuoteAPIController.getRecords();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode);
    }

    @isTest
    static void testUpsertProduct() {
        String productJson = JSON.serialize(new Map<String, Object>{
            'itemCode' => 'IA-TEST-002',
            'name' => 'New ECG Probe',
            'productCode' => 'ECG-002',
            'category' => 'Critical Care',
            'productType' => 'Accessories',
            'make' => 'Mindray',
            'standardPrice' => 3000,
            'taxPercent' => 18,
            'uom' => 'Nos',
            'hsnCode' => '9018',
            'isActive' => true
        });

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/ProductQuote';
        req.httpMethod = 'POST';
        req.params.put('key', Label.API_Key);
        req.params.put('type', 'product');
        req.requestBody = Blob.valueOf(productJson);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ProductQuoteAPIController.createRecords();
        Test.stopTest();

        Product2 created = [SELECT Name, Item_Code__c FROM Product2 WHERE Item_Code__c = 'IA-TEST-002'];
        System.assertEquals('New ECG Probe', created.Name);
    }

    @isTest
    static void testCreateQuote() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id LIMIT 1];
        Id stdPricebookId = Test.getStandardPricebookId();

        String quoteJson = JSON.serialize(new Map<String, Object>{
            'name' => 'API Test Quote',
            'opportunityId' => opp.Id,
            'pricebookId' => stdPricebookId,
            'quoteDate' => String.valueOf(Date.today()),
            'validTill' => String.valueOf(Date.today().addDays(30)),
            'shippingMode' => 'By Road',
            'lineItems' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'productId' => prod.Id,
                    'pricebookEntryId' => pbe.Id,
                    'quantity' => 3,
                    'unitPrice' => 4800,
                    'taxType' => 'GST'
                }
            }
        });

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/ProductQuote';
        req.httpMethod = 'POST';
        req.params.put('key', Label.API_Key);
        req.params.put('type', 'quote');
        req.requestBody = Blob.valueOf(quoteJson);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ProductQuoteAPIController.createRecords();
        Test.stopTest();

        List<Quote> quotes = [SELECT Id FROM Quote WHERE Name = 'API Test Quote'];
        System.assertEquals(1, quotes.size());
    }

    @isTest
    static void testPostUnauthorized() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/ProductQuote';
        req.httpMethod = 'POST';
        req.params.put('key', 'BAD_KEY');
        req.params.put('type', 'product');
        req.requestBody = Blob.valueOf('{}');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ProductQuoteAPIController.createRecords();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode);
    }
}
