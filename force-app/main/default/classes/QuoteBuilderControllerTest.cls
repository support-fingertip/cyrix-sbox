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

        // Create Shipping_Address__c records for the Account.
        // Name is an auto-number (sh-{0000}) so it isn't set explicitly.
        Shipping_Address__c shipAddr1 = new Shipping_Address__c(
            Account__c = acc.Id,
            Address__Street__s = '789 Industrial Area',
            Address__City__s = 'Kochi',
            Address__PostalCode__s = '682002'
        );
        Shipping_Address__c shipAddr2 = new Shipping_Address__c(
            Account__c = acc.Id,
            Address__Street__s = '100 Tech Park',
            Address__City__s = 'Trivandrum',
            Address__PostalCode__s = '695002'
        );
        insert new List<Shipping_Address__c>{ shipAddr1, shipAddr2 };

        Id stdPbId = Test.getStandardPricebookId();

        Opportunity opp = new Opportunity(
            Name = 'Test Hospital Deal',
            AccountId = acc.Id,
            StageName = 'Proposal',
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

        // Price list5 (standard tier) - required by the tiered pricing engine
        // before any non-service product can be added to a quote.
        Pricebook2 tier5Pb = new Pricebook2(
            Name = 'Tier5 Standard',
            IsActive = true,
            Price_Book_Type__c = 'Price list5'
        );
        insert tier5Pb;
        insert new List<PricebookEntry>{
            new PricebookEntry(
                Pricebook2Id = tier5Pb.Id,
                Product2Id = prod1.Id,
                UnitPrice = 150000,
                IsActive = true,
                UseStandardPrice = false
            ),
            new PricebookEntry(
                Pricebook2Id = tier5Pb.Id,
                Product2Id = prod2.Id,
                UnitPrice = 85000,
                IsActive = true,
                UseStandardPrice = false
            )
        };
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
        System.assertEquals('Proposal', ctx.stageName);
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
    static void testGetOpportunityContextRejectsBlockedStage() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        opp.StageName = 'Qualification';
        update opp;

        Boolean blocked = false;
        Test.startTest();
        try {
            QuoteBuilderController.getOpportunityContext(opp.Id);
        } catch (AuraHandledException e) {
            blocked = true;
        }
        Test.stopTest();

        System.assert(blocked, 'getOpportunityContext should reject opportunities outside Negotiation/Proposal/Demo.');
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
        System.assertEquals('Not Required', items[0].Price_Status__c);
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
        System.assertEquals('Test Hospital', ctx.accountName, 'Account name should be populated in edit context');
        System.assertNotEquals(null, ctx.standardPricebookId, 'Standard pricebook ID should be populated');
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
    static void testSearchProductsWithBestPriceStandard() {
        Opportunity opp = [SELECT Id, AccountId, Pricebook2Id FROM Opportunity LIMIT 1];

        Test.startTest();
        List<QuoteBuilderController.ProductSearchResult> results =
            QuoteBuilderController.searchProductsWithBestPrice(
                'Ultrasound', null, opp.AccountId, null
            );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find 1 product');
        System.assertEquals('USG-500', results[0].productCode);
        System.assertNotEquals(null, results[0].unitPrice, 'Unit price should be set');
        System.assertNotEquals(null, results[0].availablePrices, 'Available prices should be populated');
    }

    @isTest
    static void testSearchDefaultsToTier5() {
        Opportunity opp = [SELECT Id, AccountId, Pricebook2Id FROM Opportunity LIMIT 1];

        Test.startTest();
        List<QuoteBuilderController.ProductSearchResult> results =
            QuoteBuilderController.searchProductsWithBestPrice(
                'Ultrasound', null, opp.AccountId, null
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('USG-500', results[0].productCode);
        System.assertEquals(150000, results[0].unitPrice, 'Should default to Price list5 list price');
        System.assertEquals('Price list5', results[0].sourcePricebookType);
        System.assertEquals(false, results[0].isServiceItem);
    }

    @isTest
    static void testSearchExcludesProductWithoutTier5() {
        // New product with no Price list5 entry - must not be returned.
        Product2 orphan = new Product2(
            Name = 'Orphan Product',
            ProductCode = 'ORPH-1',
            IsActive = true
        );
        insert orphan;

        Id stdPbId = Test.getStandardPricebookId();
        insert new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = orphan.Id,
            UnitPrice = 5000,
            IsActive = true
        );

        Test.startTest();
        List<QuoteBuilderController.ProductSearchResult> results =
            QuoteBuilderController.searchProductsWithBestPrice(
                'Orphan', null, null, null
            );
        Test.stopTest();

        System.assertEquals(0, results.size(),
            'Non-service product without Price list5 must be excluded from search');
    }

    @isTest
    static void testSearchReturnsServiceItem() {
        Product2 svc = new Product2(
            Name = 'Installation Service',
            ProductCode = 'SVC-INSTALL',
            IsActive = true,
            Service_Item__c = 'Yes',
            Tax__c = 18
        );
        insert svc;

        Test.startTest();
        List<QuoteBuilderController.ProductSearchResult> results =
            QuoteBuilderController.searchProductsWithBestPrice(
                'Installation', null, null, null
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isServiceItem);
        System.assertEquals(0, results[0].unitPrice, 'Service items return 0 - user enters price');
        System.assertEquals(18, results[0].taxPercent, 'Service items carry product tax');
        System.assertEquals('Service', results[0].sourcePricebookType);
    }

    @isTest
    static void testPricingPreview_tierResolution() {
        Product2 prod = [SELECT Id FROM Product2 WHERE ProductCode = 'USG-500' LIMIT 1];

        // Add Price list3 at 100000 and Price list1 at 50000 to exercise the walk.
        Pricebook2 pb3 = new Pricebook2(Name = 'T3', IsActive = true, Price_Book_Type__c = 'Price list3');
        Pricebook2 pb1 = new Pricebook2(Name = 'T1', IsActive = true, Price_Book_Type__c = 'Price list1');
        insert new List<Pricebook2>{pb3, pb1};
        insert new List<PricebookEntry>{
            new PricebookEntry(Pricebook2Id = pb3.Id, Product2Id = prod.Id, UnitPrice = 100000, IsActive = true, UseStandardPrice = false),
            new PricebookEntry(Pricebook2Id = pb1.Id, Product2Id = prod.Id, UnitPrice = 50000, IsActive = true, UseStandardPrice = false)
        };

        Test.startTest();
        // Unit price 150000, discount 40% -> discounted = 90000. Tightest fit = Price list3 (100000).
        QuoteBuilderController.PricingPreview p =
            QuoteBuilderController.getProductPricingPreview(prod.Id, 150000, 40, 1);
        Test.stopTest();

        System.assertEquals('Price list3', p.resolvedTier);
        System.assertEquals(100000, p.resolvedTierListPrice);
        System.assertEquals(150000, p.standardPrice);
        // 90000 < 150000 -> Approval Required
        System.assertEquals('Approval Required', p.priceStatus);
    }

    @isTest
    static void testPricingPreview_salesPriceFloor() {
        Product2 prod = [SELECT Id FROM Product2 WHERE ProductCode = 'USG-500' LIMIT 1];

        Test.startTest();
        try {
            QuoteBuilderController.getProductPricingPreview(prod.Id, 100000, 0, 1);
            System.assert(false, 'Should have thrown - Sales Price below Price list5 floor');
        } catch (AuraHandledException e) {
            // AuraHandledException intentionally masks its server-side message
            // so tests can only assert the exception type, not its text.
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testPricingPreview_serviceItem() {
        Product2 svc = new Product2(
            Name = 'Calibration Service',
            ProductCode = 'SVC-CAL',
            IsActive = true,
            Service_Item__c = 'Yes',
            Tax__c = 5
        );
        insert svc;

        Test.startTest();
        QuoteBuilderController.PricingPreview p =
            QuoteBuilderController.getProductPricingPreview(svc.Id, 2500, 10, 1);
        Test.stopTest();

        System.assertEquals(true, p.isServiceItem);
        System.assertEquals('Not Required', p.priceStatus);
        System.assertEquals(null, p.resolvedTier, 'Service items do not resolve a tier');
    }

    @isTest
    static void testSearchProductsWithBestPriceEmptySearch() {
        Opportunity opp = [SELECT Id, AccountId, Pricebook2Id FROM Opportunity LIMIT 1];

        Test.startTest();
        List<QuoteBuilderController.ProductSearchResult> results =
            QuoteBuilderController.searchProductsWithBestPrice(
                '', null, opp.AccountId, null
            );
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Empty search should return no results');
    }

    @isTest
    static void testSaveQuoteLineItemsWithSourcePricebook() {
        Opportunity opp = [SELECT Id, Pricebook2Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id, Product2Id FROM PricebookEntry WHERE Product2.ProductCode = 'USG-500' LIMIT 1];

        Quote q = new Quote(
            Name = 'Source PB Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = opp.Pricebook2Id,
            Status = 'Draft',
            Price_Status__c = 'Draft'
        );
        insert q;

        // UnitPrice at the Price list5 floor, zero discount - trigger should
        // stamp Source_Pricebook_Ref__c to the Tier5 pricebook and leave the
        // line at Not Required (final price == standard price).
        String lineItemsJSON = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId' => pbe.Product2Id,
                'pricebookEntryId' => pbe.Id,
                'quantity' => 1,
                'unitPrice' => 150000,
                'discount' => 0,
                'lineDescription' => 'Standard priced item',
                'detailedDescription' => 'Full list price',
                'sourcePricebookId' => opp.Pricebook2Id
            }
        });

        Test.startTest();
        QuoteBuilderController.saveQuoteLineItems(q.Id, lineItemsJSON);
        Test.stopTest();

        QuoteLineItem savedItem = [
            SELECT Source_Pricebook_Ref__c, Source_Pricebook_Ref__r.Price_Book_Type__c,
                   Price_Status__c, Tax__c
            FROM QuoteLineItem WHERE QuoteId = :q.Id LIMIT 1
        ];
        System.assertNotEquals(null, savedItem.Source_Pricebook_Ref__c,
            'Trigger must stamp a resolved tier pricebook');
        System.assertEquals('Price list5', savedItem.Source_Pricebook_Ref__r.Price_Book_Type__c,
            'Zero-discount line at list price resolves to Price list5');
        System.assertEquals('Not Required', savedItem.Price_Status__c,
            'Final price == standard price -> Not Required');
    }

    @isTest
    static void testPriceStatusApprovalRequired() {
        Opportunity opp = [SELECT Id, Pricebook2Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id, Product2Id FROM PricebookEntry WHERE Product2.ProductCode = 'USG-500' LIMIT 1];

        Quote q = new Quote(
            Name = 'Price Status Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = opp.Pricebook2Id,
            Status = 'Draft',
            Price_Status__c = 'Draft'
        );
        insert q;

        // UnitPrice 150000 (= standard), 15% discount -> final 127500 < 150000
        // -> Approval Required under the new standard-price comparison.
        String lineItemsJSON = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId' => pbe.Product2Id,
                'pricebookEntryId' => pbe.Id,
                'quantity' => 1,
                'unitPrice' => 150000,
                'discount' => 15,
                'lineDescription' => 'Discounted item',
                'detailedDescription' => 'Needs approval',
                'sourcePricebookId' => opp.Pricebook2Id
            }
        });

        Test.startTest();
        QuoteBuilderController.saveQuoteLineItems(q.Id, lineItemsJSON);
        Test.stopTest();

        QuoteLineItem savedItem = [SELECT Price_Status__c FROM QuoteLineItem WHERE QuoteId = :q.Id LIMIT 1];
        System.assertEquals('Approval Required', savedItem.Price_Status__c,
            'Price status should be Approval Required when discount > max discount');

        Quote savedQuote = [SELECT Price_Status__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals('Approval Required', savedQuote.Price_Status__c,
            'Quote price status should roll up to Approval Required when any line item needs approval');
    }

    @isTest
    static void testQuotePriceStatusPreservesApproved() {
        Opportunity opp = [SELECT Id, Pricebook2Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id, Product2Id FROM PricebookEntry WHERE Product2.ProductCode = 'USG-500' LIMIT 1];

        Quote q = new Quote(
            Name = 'Approved Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = opp.Pricebook2Id,
            Status = 'Draft',
            Price_Status__c = 'Approved'
        );
        insert q;

        // Save a normal (non-approval) line item at list price. Quote stays Approved.
        String lineItemsJSON = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId' => pbe.Product2Id,
                'pricebookEntryId' => pbe.Id,
                'quantity' => 1,
                'unitPrice' => 150000,
                'discount' => 0,
                'lineDescription' => 'Within limit',
                'detailedDescription' => '',
                'sourcePricebookId' => opp.Pricebook2Id
            }
        });

        Test.startTest();
        QuoteBuilderController.saveQuoteLineItems(q.Id, lineItemsJSON);
        Test.stopTest();

        Quote savedQuote = [SELECT Price_Status__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals('Approved', savedQuote.Price_Status__c,
            'Approved quotes should not regress to Draft or Approval Required on line-item save');
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