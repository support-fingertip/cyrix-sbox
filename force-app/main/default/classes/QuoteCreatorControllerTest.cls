@isTest
private class QuoteCreatorControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create Account
        Account acc = new Account(Name = 'Test Hospital');
        insert acc;

        // Create standard pricebook entry
        Id stdPbId = Test.getStandardPricebookId();

        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = stdPbId
        );
        insert opp;

        // Create Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            ProductCode = 'TP-001',
            Make__c = 'TestMake',
            Model__c = 'TestModel',
            IsActive = true
        );
        insert prod;

        // Create PricebookEntry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 50000,
            IsActive = true
        );
        insert pbe;

        // Create a Quote with line items
        Quote qt = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = stdPbId,
            Quote_Date__c = Date.today(),
            Valid_Till__c = Date.today().addDays(30),
            Status = 'Draft',
            Price_Status__c = 'Draft',
            is_Active__c = true
        );
        insert qt;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = qt.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 50000,
            Discount = 5,
            Tax_Type__c = 'GST',
            Price_Status__c = 'Standard',
            Product_Line_Description__c = 'Test line item'
        );
        insert qli;
    }

    @isTest
    static void testGetOpportunityDetails() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        QuoteCreatorController.OpportunityWrapper result = QuoteCreatorController.getOpportunityDetails(opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Test Opportunity', result.opportunityName);
        System.assertNotEquals(null, result.accountId);
    }

    @isTest
    static void testGetQuotesForOpportunity() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        List<QuoteCreatorController.QuoteListWrapper> quotes = QuoteCreatorController.getQuotesForOpportunity(opp.Id);
        Test.stopTest();

        System.assertEquals(1, quotes.size());
        System.assertEquals('Test Quote', quotes[0].quoteName);
        System.assertEquals(1, quotes[0].lineItemCount);
    }

    @isTest
    static void testSearchProducts() {
        Test.startTest();
        List<QuoteCreatorController.ProductWrapper> results = QuoteCreatorController.searchProducts('Test', Test.getStandardPricebookId());
        Test.stopTest();

        System.assert(results.size() > 0, 'Should find at least one product');
        System.assertEquals('Test Product', results[0].productName);
        System.assertEquals('TP-001', results[0].productCode);
    }

    @isTest
    static void testSearchProductsWithNullPricebook() {
        Test.startTest();
        List<QuoteCreatorController.ProductWrapper> results = QuoteCreatorController.searchProducts('Test', null);
        Test.stopTest();

        System.assert(results.size() >= 0);
    }

    @isTest
    static void testCreateQuoteWithLineItems() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id, Product2Id FROM PricebookEntry LIMIT 1];

        String quoteJSON = JSON.serialize(new Map<String, Object>{
            'name' => 'New Test Quote',
            'opportunityId' => opp.Id,
            'pricebookId' => Test.getStandardPricebookId(),
            'quoteDate' => String.valueOf(Date.today()),
            'validTill' => String.valueOf(Date.today().addDays(30)),
            'billingAddress' => 'Test Billing',
            'shippingAddress' => 'Test Shipping',
            'shippingMode' => 'By Road',
            'vertical' => 'Medical Equipment'
        });

        String lineItemsJSON = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId' => pbe.Product2Id,
                'pricebookEntryId' => pbe.Id,
                'quantity' => 3,
                'unitPrice' => 45000,
                'discount' => 10,
                'taxType' => 'GST',
                'lineDescription' => 'Test line',
                'detailedDescription' => 'Detailed desc'
            }
        });

        Test.startTest();
        Id quoteId = QuoteCreatorController.createQuoteWithLineItems(quoteJSON, lineItemsJSON);
        Test.stopTest();

        System.assertNotEquals(null, quoteId);
        Quote createdQuote = [SELECT Name, Price_Status__c, Status FROM Quote WHERE Id = :quoteId];
        System.assertEquals('New Test Quote', createdQuote.Name);
        System.assertEquals('Draft', createdQuote.Price_Status__c);

        List<QuoteLineItem> items = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :quoteId];
        System.assertEquals(1, items.size());
    }

    @isTest
    static void testGetQuoteDetails() {
        Quote qt = [SELECT Id FROM Quote LIMIT 1];

        Test.startTest();
        QuoteCreatorController.QuoteDetailWrapper result = QuoteCreatorController.getQuoteDetails(qt.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.quote);
        System.assertEquals(1, result.lineItems.size());
        System.assertEquals('Test Product', result.lineItems[0].productName);
    }

    @isTest
    static void testDeleteLineItem() {
        QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];

        Test.startTest();
        QuoteCreatorController.deleteLineItem(qli.Id);
        Test.stopTest();

        List<QuoteLineItem> remaining = [SELECT Id FROM QuoteLineItem WHERE Id = :qli.Id];
        System.assertEquals(0, remaining.size());
    }

    @isTest
    static void testAddLineItemsToQuote() {
        Quote qt = [SELECT Id FROM Quote LIMIT 1];
        PricebookEntry pbe = [SELECT Id, Product2Id FROM PricebookEntry LIMIT 1];

        String lineItemsJSON = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId' => pbe.Product2Id,
                'pricebookEntryId' => pbe.Id,
                'quantity' => 5,
                'unitPrice' => 40000,
                'discount' => 0,
                'taxType' => 'IGST',
                'lineDescription' => 'Additional item',
                'detailedDescription' => ''
            }
        });

        Test.startTest();
        QuoteCreatorController.addLineItemsToQuote(qt.Id, lineItemsJSON);
        Test.stopTest();

        List<QuoteLineItem> items = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :qt.Id];
        System.assertEquals(2, items.size());
    }

    @isTest
    static void testSearchProductsByMake() {
        Test.startTest();
        List<QuoteCreatorController.ProductWrapper> results = QuoteCreatorController.searchProducts('TestMake', Test.getStandardPricebookId());
        Test.stopTest();

        System.assert(results.size() > 0, 'Should find products by make');
    }

    @isTest
    static void testSearchProductsByModel() {
        Test.startTest();
        List<QuoteCreatorController.ProductWrapper> results = QuoteCreatorController.searchProducts('TestModel', Test.getStandardPricebookId());
        Test.stopTest();

        System.assert(results.size() > 0, 'Should find products by model');
    }
}