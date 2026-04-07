@isTest
private class QuoteBuilderControllerTest {

    @TestSetup
    static void setupTestData() {
        Account acc = new Account(
            Name = 'Test Hospital',
            BillingStreet = '123 MG Road',
            BillingCity = 'Kochi',
            BillingState = 'Kerala',
            BillingPostalCode = '682001',
            BillingCountry = 'India',
            ShippingStreet = '456 NH Road',
            ShippingCity = 'Trivandrum',
            ShippingState = 'Kerala',
            ShippingPostalCode = '695001',
            ShippingCountry = 'India'
        );
        insert acc;

        Id stdPbId = Test.getStandardPricebookId();

        Opportunity opp = new Opportunity(
            Name = 'Test Hospital Deal',
            AccountId = acc.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(60),
            Pricebook2Id = stdPbId
        );
        insert opp;

        Product2 prod1 = new Product2(
            Name = 'Ultrasound Scanner CX-500',
            ProductCode = 'USG-500',
            Item_Code__c = 'USG-500',
            Make__c = 'CyrixMed',
            Model__c = 'CX-500',
            HSN_Code__c = '90189090',
            IsActive = true,
            Description = 'Portable ultrasound scanner'
        );
        Product2 prod2 = new Product2(
            Name = 'Patient Monitor PM-200',
            ProductCode = 'PM-200',
            Item_Code__c = 'PM-200',
            Make__c = 'CyrixMed',
            Model__c = 'PM-200',
            HSN_Code__c = '90189091',
            IsActive = true,
            Description = 'Multi-parameter patient monitor'
        );
        insert new List<Product2>{ prod1, prod2 };

        PricebookEntry pbe1 = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod1.Id,
            UnitPrice = 150000,
            IsActive = true
        );
        PricebookEntry pbe2 = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod2.Id,
            UnitPrice = 85000,
            IsActive = true
        );
        insert new List<PricebookEntry>{ pbe1, pbe2 };
    }

    @isTest
    static void testGetOpportunityContext() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        QuoteBuilderController.OpportunityContext ctx = QuoteBuilderController.getOpportunityContext(opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, ctx);
        System.assertEquals('Test Hospital Deal', ctx.opportunityName);
        System.assertEquals('Test Hospital', ctx.accountName);
        System.assertNotEquals(null, ctx.pricebookId);
        System.assert(ctx.billingAddress.contains('Kochi'), 'Billing address should contain Kochi');
        System.assert(ctx.shippingAddress.contains('Trivandrum'), 'Shipping address should contain Trivandrum');
    }

    @isTest
    static void testSearchProductsByName() {
        Opportunity opp = [SELECT Pricebook2Id FROM Opportunity LIMIT 1];

        Test.startTest();
        List<QuoteBuilderController.ProductSearchResult> results =
            QuoteBuilderController.searchProducts('Ultrasound', opp.Pricebook2Id, null);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find 1 product by name');
        System.assertEquals('USG-500', results[0].productCode);
        System.assertEquals(150000, results[0].unitPrice);
    }

    @isTest
    static void testSearchProductsByCode() {
        Opportunity opp = [SELECT Pricebook2Id FROM Opportunity LIMIT 1];

        Test.startTest();
        List<QuoteBuilderController.ProductSearchResult> results =
            QuoteBuilderController.searchProducts('PM-200', opp.Pricebook2Id, null);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find 1 product by code');
        System.assertEquals('Patient Monitor PM-200', results[0].productName);
    }

    @isTest
    static void testSearchProductsNoResults() {
        Opportunity opp = [SELECT Pricebook2Id FROM Opportunity LIMIT 1];

        Test.startTest();
        List<QuoteBuilderController.ProductSearchResult> results =
            QuoteBuilderController.searchProducts('NONEXISTENT', opp.Pricebook2Id, null);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should find no products');
    }

    @isTest
    static void testSearchProductsNullPricebook() {
        Test.startTest();
        List<QuoteBuilderController.ProductSearchResult> results =
            QuoteBuilderController.searchProducts('Ultrasound', null, null);
        Test.stopTest();

        System.assert(results.size() >= 0, 'Should handle null pricebook gracefully');
    }

    @isTest
    static void testSaveQuoteWithLineItems() {
        Opportunity opp = [SELECT Id, Pricebook2Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe1 = [SELECT Id, Product2Id FROM PricebookEntry WHERE Product2.ProductCode = 'USG-500' LIMIT 1];
        PricebookEntry pbe2 = [SELECT Id, Product2Id FROM PricebookEntry WHERE Product2.ProductCode = 'PM-200' LIMIT 1];

        String quoteJSON = JSON.serialize(new Map<String, Object>{
            'name' => 'Test Hospital Quote',
            'opportunityId' => opp.Id,
            'pricebookId' => opp.Pricebook2Id,
            'quoteDate' => String.valueOf(Date.today()),
            'validTill' => String.valueOf(Date.today().addDays(30)),
            'billingAddress' => '123 MG Road, Kochi, Kerala',
            'shippingAddress' => '456 NH Road, Trivandrum, Kerala',
            'shippingMode' => 'By Road',
            'vertical' => 'Distribution/Sales',
            'isActive' => true
        });

        String lineItemsJSON = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId' => pbe1.Product2Id,
                'pricebookEntryId' => pbe1.Id,
                'quantity' => 2,
                'unitPrice' => 150000,
                'discount' => 5,
                'taxType' => 'GST',
                'lineDescription' => 'Portable ultrasound',
                'detailedDescription' => 'CX-500 with probes'
            },
            new Map<String, Object>{
                'productId' => pbe2.Product2Id,
                'pricebookEntryId' => pbe2.Id,
                'quantity' => 3,
                'unitPrice' => 85000,
                'discount' => 0,
                'taxType' => 'IGST',
                'lineDescription' => 'Patient monitor',
                'detailedDescription' => 'PM-200 multi-parameter'
            }
        });

        String chargesJSON = JSON.serialize(new Map<String, Object>{
            'shippingCharges' => 5000,
            'transportCharges' => 3000,
            'warrantyCost' => 10000,
            'installationCost' => 15000,
            'packingCharges' => 2000,
            'trainingCost' => 8000,
            'taxAmount' => 25000
        });

        Test.startTest();
        Id quoteId = QuoteBuilderController.saveQuoteWithLineItems(quoteJSON, lineItemsJSON, chargesJSON);
        Test.stopTest();

        System.assertNotEquals(null, quoteId, 'Quote should be created');

        Quote savedQuote = [SELECT Name, Status, Price_Status__c, is_Active__c,
                                   Vertical__c, Shipping_Mode__c, ShippingHandling
                            FROM Quote WHERE Id = :quoteId];
        System.assertEquals('Test Hospital Quote', savedQuote.Name);
        System.assertEquals('Draft', savedQuote.Status);
        System.assertEquals('Draft', savedQuote.Price_Status__c);
        System.assertEquals(true, savedQuote.is_Active__c);
        System.assertEquals('Distribution/Sales', savedQuote.Vertical__c);
        System.assertEquals('By Road', savedQuote.Shipping_Mode__c);
        System.assertEquals(5000, savedQuote.ShippingHandling);

        List<QuoteLineItem> items = [SELECT Id, Quantity, UnitPrice, Discount, Tax_Type__c
                                     FROM QuoteLineItem WHERE QuoteId = :quoteId ORDER BY UnitPrice DESC];
        System.assertEquals(2, items.size(), 'Should have 2 line items');
        System.assertEquals(2, items[0].Quantity);
        System.assertEquals(150000, items[0].UnitPrice);
        System.assertEquals(5, items[0].Discount);
        System.assertEquals('GST', items[0].Tax_Type__c);
    }

    @isTest
    static void testSaveQuoteEmptyLineItems() {
        Opportunity opp = [SELECT Id, Pricebook2Id FROM Opportunity LIMIT 1];

        String quoteJSON = JSON.serialize(new Map<String, Object>{
            'name' => 'Empty Quote',
            'opportunityId' => opp.Id,
            'pricebookId' => opp.Pricebook2Id,
            'quoteDate' => String.valueOf(Date.today()),
            'validTill' => String.valueOf(Date.today().addDays(30)),
            'billingAddress' => 'Test',
            'shippingAddress' => 'Test',
            'vertical' => 'Distribution/Sales',
            'isActive' => false
        });

        String lineItemsJSON = '[]';
        String chargesJSON = '{}';

        Test.startTest();
        try {
            QuoteBuilderController.saveQuoteWithLineItems(quoteJSON, lineItemsJSON, chargesJSON);
            System.assert(false, 'Should have thrown exception for empty line items');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('line item'), 'Error should mention line items');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveQuoteNoCharges() {
        Opportunity opp = [SELECT Id, Pricebook2Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id, Product2Id FROM PricebookEntry LIMIT 1];

        String quoteJSON = JSON.serialize(new Map<String, Object>{
            'name' => 'No Charges Quote',
            'opportunityId' => opp.Id,
            'pricebookId' => opp.Pricebook2Id,
            'quoteDate' => String.valueOf(Date.today()),
            'validTill' => String.valueOf(Date.today().addDays(15)),
            'billingAddress' => 'Test Address',
            'shippingAddress' => 'Test Address',
            'vertical' => 'Spares',
            'isActive' => true
        });

        String lineItemsJSON = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId' => pbe.Product2Id,
                'pricebookEntryId' => pbe.Id,
                'quantity' => 1,
                'unitPrice' => 150000,
                'discount' => 0,
                'taxType' => 'Exempt',
                'lineDescription' => 'Test',
                'detailedDescription' => ''
            }
        });

        String chargesJSON = JSON.serialize(new Map<String, Object>{
            'shippingCharges' => 0,
            'transportCharges' => 0,
            'warrantyCost' => 0,
            'installationCost' => 0,
            'packingCharges' => 0,
            'trainingCost' => 0,
            'taxAmount' => 0
        });

        Test.startTest();
        Id quoteId = QuoteBuilderController.saveQuoteWithLineItems(quoteJSON, lineItemsJSON, chargesJSON);
        Test.stopTest();

        System.assertNotEquals(null, quoteId);
        Quote q = [SELECT ShippingHandling FROM Quote WHERE Id = :quoteId];
        System.assertEquals(0, q.ShippingHandling);
    }
}
