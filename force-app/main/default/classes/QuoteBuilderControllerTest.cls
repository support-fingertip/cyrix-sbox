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

        // Create Shipping_Address__c records for the Account
        Shipping_Address__c shipAddr1 = new Shipping_Address__c(
            Account__c = acc.Id,
            Name = 'Main Warehouse',
            Address__Street__s = '789 Industrial Area',
            Address__City__s = 'Kochi',
            Address__PostalCode__s = '682002'
        );
        Shipping_Address__c shipAddr2 = new Shipping_Address__c(
            Account__c = acc.Id,
            Name = 'Branch Office',
            Address__Street__s = '100 Tech Park',
            Address__City__s = 'Trivandrum',
            Address__PostalCode__s = '695002'
        );
        insert new List<Shipping_Address__c>{ shipAddr1, shipAddr2 };

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
        // Verify billing address pre-population
        System.assertEquals('Test Hospital', ctx.billingName);
        System.assertEquals('123 MG Road', ctx.billingStreet);
        System.assertEquals('Kochi', ctx.billingCity);
        System.assertEquals('Kerala', ctx.billingState);
        System.assertEquals('682001', ctx.billingPostalCode);
        System.assertEquals('India', ctx.billingCountry);
    }

    @isTest
    static void testGetShippingAddresses() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<QuoteBuilderController.ShippingAddressResult> results =
            QuoteBuilderController.getShippingAddresses(acc.Id);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should find 2 shipping addresses');
        // Verify display label is populated
        for (QuoteBuilderController.ShippingAddressResult addr : results) {
            System.assertNotEquals(null, addr.displayLabel);
            System.assertNotEquals(null, addr.name);
        }
    }

    @isTest
    static void testGetShippingAddressesNullAccount() {
        Test.startTest();
        List<QuoteBuilderController.ShippingAddressResult> results =
            QuoteBuilderController.getShippingAddresses(null);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty for null account');
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
    static void testSaveQuoteLineItems() {
        Opportunity opp = [SELECT Id, Pricebook2Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe1 = [SELECT Id, Product2Id FROM PricebookEntry WHERE Product2.ProductCode = 'USG-500' LIMIT 1];
        PricebookEntry pbe2 = [SELECT Id, Product2Id FROM PricebookEntry WHERE Product2.ProductCode = 'PM-200' LIMIT 1];

        Quote q = new Quote(
            Name = 'Test Hospital Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = opp.Pricebook2Id,
            Status = 'Draft',
            Price_Status__c = 'Draft'
        );
        insert q;

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

        Test.startTest();
        QuoteBuilderController.saveQuoteLineItems(q.Id, lineItemsJSON);
        Test.stopTest();

        List<QuoteLineItem> items = [SELECT Id, Quantity, UnitPrice, Discount, Tax_Type__c, Price_Status__c
                                     FROM QuoteLineItem WHERE QuoteId = :q.Id ORDER BY UnitPrice DESC];
        System.assertEquals(2, items.size(), 'Should have 2 line items');
        System.assertEquals(2, items[0].Quantity);
        System.assertEquals(150000, items[0].UnitPrice);
        System.assertEquals(5, items[0].Discount);
        System.assertEquals('GST', items[0].Tax_Type__c);
        System.assertEquals('Standard', items[0].Price_Status__c);
    }

    @isTest
    static void testSaveQuoteLineItemsEmpty() {
        Opportunity opp = [SELECT Id, Pricebook2Id FROM Opportunity LIMIT 1];

        Quote q = new Quote(
            Name = 'Empty Line Items Test',
            OpportunityId = opp.Id,
            Pricebook2Id = opp.Pricebook2Id
        );
        insert q;

        Test.startTest();
        try {
            QuoteBuilderController.saveQuoteLineItems(q.Id, '[]');
            System.assert(false, 'Should have thrown exception for empty line items');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('line item'), 'Error should mention line items');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetQuoteForEdit() {
        Opportunity opp = [SELECT Id, AccountId, Pricebook2Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id, Product2Id FROM PricebookEntry WHERE Product2.ProductCode = 'USG-500' LIMIT 1];

        Quote q = new Quote(
            Name = 'Edit Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = opp.Pricebook2Id
        );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            Product2Id = pbe.Product2Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 150000,
            Discount = 5,
            Tax_Type__c = 'GST'
        );
        insert qli;

        Test.startTest();
        QuoteBuilderController.QuoteEditContext ctx = QuoteBuilderController.getQuoteForEdit(q.Id);
        Test.stopTest();

        System.assertEquals(q.Id, ctx.quoteId);
        System.assertEquals(opp.Pricebook2Id, ctx.pricebookId);
        System.assertEquals(opp.Id, ctx.opportunityId);
        System.assertEquals(opp.AccountId, ctx.accountId);
        System.assertEquals(1, ctx.lineItems.size());
        System.assertEquals(2, ctx.lineItems[0].quantity);
        System.assertEquals(150000, ctx.lineItems[0].unitPrice);
    }

    @isTest
    static void testUpdateQuoteLineItems() {
        Opportunity opp = [SELECT Id, Pricebook2Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe1 = [SELECT Id, Product2Id FROM PricebookEntry WHERE Product2.ProductCode = 'USG-500' LIMIT 1];
        PricebookEntry pbe2 = [SELECT Id, Product2Id FROM PricebookEntry WHERE Product2.ProductCode = 'PM-200' LIMIT 1];

        Quote q = new Quote(
            Name = 'Update Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = opp.Pricebook2Id
        );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            Product2Id = pbe1.Product2Id,
            PricebookEntryId = pbe1.Id,
            Quantity = 1,
            UnitPrice = 150000,
            Discount = 0,
            Tax_Type__c = 'GST'
        );
        insert qli;

        String lineItemsJSON = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId' => pbe2.Product2Id,
                'pricebookEntryId' => pbe2.Id,
                'quantity' => 5,
                'unitPrice' => 85000,
                'discount' => 10,
                'taxType' => 'IGST',
                'lineDescription' => 'Updated monitor',
                'detailedDescription' => 'PM-200 updated'
            }
        });

        Test.startTest();
        QuoteBuilderController.updateQuoteLineItems(q.Id, lineItemsJSON);
        Test.stopTest();

        List<QuoteLineItem> items = [SELECT Id, Quantity, UnitPrice, Discount, Tax_Type__c
                                     FROM QuoteLineItem WHERE QuoteId = :q.Id];
        System.assertEquals(1, items.size(), 'Should have replaced with 1 new line item');
        System.assertEquals(5, items[0].Quantity);
        System.assertEquals(85000, items[0].UnitPrice);
        System.assertEquals(10, items[0].Discount);
        System.assertEquals('IGST', items[0].Tax_Type__c);
    }

    @isTest
    static void testUpdateQuoteLineItemsEmpty() {
        Opportunity opp = [SELECT Id, Pricebook2Id FROM Opportunity LIMIT 1];

        Quote q = new Quote(
            Name = 'Empty Update Test',
            OpportunityId = opp.Id,
            Pricebook2Id = opp.Pricebook2Id
        );
        insert q;

        Test.startTest();
        try {
            QuoteBuilderController.updateQuoteLineItems(q.Id, '[]');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('line item'), 'Error should mention line items');
        }
        Test.stopTest();
    }
}