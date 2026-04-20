@isTest
private class QuoteLineItemTriggerHandlerTest {

    // Creates Account + Opportunity on Standard Pricebook, one tiered product
    // with the requested tier list prices, and returns the objects the tests
    // need. Price list5 is always included unless explicitly skipped via
    // skipTier5 = true (used by the "no Price list5 -> block" test).
    private static Map<String, Object> setupContext(Map<String, Decimal> tierPrices, Boolean skipTier5) {
        Account acc = new Account(Name = 'Trigger Test Hospital');
        insert acc;

        Id stdPbId = Test.getStandardPricebookId();

        Opportunity opp = new Opportunity(
            Name = 'Trigger Test Deal',
            AccountId = acc.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(60),
            Pricebook2Id = stdPbId
        );
        insert opp;

        Product2 prod = new Product2(
            Name = 'Trigger Test Product',
            ProductCode = 'TRG-1',
            IsActive = true,
            Tax__c = 18,
            Service_Item__c = 'No'
        );
        insert prod;

        // Standard pricebook entry is mandatory - QLI.PricebookEntryId lives here.
        PricebookEntry stdEntry = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = tierPrices.containsKey('Price list5') ? tierPrices.get('Price list5') : 1000,
            IsActive = true
        );
        insert stdEntry;

        List<Pricebook2> pbs = new List<Pricebook2>();
        for (String t : tierPrices.keySet()) {
            if (skipTier5 && t == 'Price list5') continue;
            pbs.add(new Pricebook2(Name = t + ' ' + prod.Id, IsActive = true, Price_Book_Type__c = t));
        }
        insert pbs;

        List<PricebookEntry> entries = new List<PricebookEntry>();
        for (Pricebook2 pb : pbs) {
            entries.add(new PricebookEntry(
                Pricebook2Id = pb.Id,
                Product2Id = prod.Id,
                UnitPrice = tierPrices.get(pb.Price_Book_Type__c),
                IsActive = true,
                UseStandardPrice = false
            ));
        }
        insert entries;

        Quote q = new Quote(
            Name = 'Trigger Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = stdPbId,
            Status = 'Draft',
            Price_Status__c = 'Draft'
        );
        insert q;

        return new Map<String, Object>{
            'product' => prod,
            'stdEntry' => stdEntry,
            'quote' => q,
            'pricebooks' => pbs
        };
    }

    private static QuoteLineItem buildQli(Map<String, Object> ctx, Decimal unitPrice, Decimal discount) {
        Product2 p = (Product2) ctx.get('product');
        PricebookEntry pbe = (PricebookEntry) ctx.get('stdEntry');
        Quote q = (Quote) ctx.get('quote');
        return new QuoteLineItem(
            QuoteId = q.Id,
            Product2Id = p.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = unitPrice,
            Discount = discount
        );
    }

    @isTest
    static void insert_nonService_stampsTierAndTax() {
        Map<String, Object> ctx = setupContext(new Map<String, Decimal>{
            'Price list5' => 1000, 'Price list3' => 600, 'Price list1' => 200
        }, false);

        Test.startTest();
        // 30% discount -> discounted = 700. Tightest fit >= 700 is Price list5 (1000).
        QuoteLineItem qli = buildQli(ctx, 1000, 30);
        insert qli;
        Test.stopTest();

        QuoteLineItem saved = [
            SELECT Tax__c, Price_Status__c,
                   Source_Pricebook_Ref__c, Source_Pricebook_Ref__r.Price_Book_Type__c
            FROM QuoteLineItem WHERE Id = :qli.Id
        ];
        System.assertEquals(18, saved.Tax__c, 'Tax stamped from Product2.Tax__c');
        System.assertEquals('Price list5', saved.Source_Pricebook_Ref__r.Price_Book_Type__c);
        // final_unit_price 700 < standardPrice 1000 -> Approval Required
        System.assertEquals('Approval Required', saved.Price_Status__c);
    }

    @isTest
    static void insert_zeroDiscount_notRequired() {
        Map<String, Object> ctx = setupContext(new Map<String, Decimal>{
            'Price list5' => 1000, 'Price list1' => 200
        }, false);

        Test.startTest();
        QuoteLineItem qli = buildQli(ctx, 1000, 0);
        insert qli;
        Test.stopTest();

        QuoteLineItem saved = [SELECT Price_Status__c FROM QuoteLineItem WHERE Id = :qli.Id];
        System.assertEquals('Not Required', saved.Price_Status__c);
    }

    @isTest
    static void insert_missingTier5_blocked() {
        Map<String, Object> ctx = setupContext(new Map<String, Decimal>{
            'Price list5' => 1000, 'Price list3' => 600
        }, true);  // skipTier5 = true

        Test.startTest();
        Boolean threw = false;
        try {
            QuoteLineItem qli = buildQli(ctx, 1000, 0);
            insert qli;
        } catch (DmlException e) {
            threw = true;
            System.assert(
                e.getMessage().containsIgnoreCase('price list5') ||
                e.getMessage().containsIgnoreCase('tier pricebookentry'),
                'Error should mention Price list5 / tier requirement. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'Insert must be blocked when Price list5 is missing');
    }

    @isTest
    static void insert_salesPriceBelowStandard_blocked() {
        Map<String, Object> ctx = setupContext(new Map<String, Decimal>{
            'Price list5' => 1000, 'Price list1' => 200
        }, false);

        Test.startTest();
        Boolean threw = false;
        try {
            // UnitPrice 800 is below Price list5 (1000) - must be rejected.
            QuoteLineItem qli = buildQli(ctx, 800, 0);
            insert qli;
        } catch (DmlException e) {
            threw = true;
            System.assert(
                e.getMessage().containsIgnoreCase('sales price') ||
                e.getMessage().containsIgnoreCase('standard list price'),
                'Error should mention Sales Price floor. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'Sales Price below standard must be blocked');
    }

    @isTest
    static void insert_discountBelowTier1_approvalRequired_underFloor() {
        Map<String, Object> ctx = setupContext(new Map<String, Decimal>{
            'Price list5' => 1000, 'Price list1' => 200
        }, false);

        Test.startTest();
        // 90% discount -> discounted = 100. 100 < every existing tier (200, 1000).
        QuoteLineItem qli = buildQli(ctx, 1000, 90);
        insert qli;
        Test.stopTest();

        QuoteLineItem saved = [
            SELECT Price_Status__c, Source_Pricebook_Ref__r.Price_Book_Type__c
            FROM QuoteLineItem WHERE Id = :qli.Id
        ];
        System.assertEquals('Approval Required', saved.Price_Status__c);
        System.assertEquals('Price list1', saved.Source_Pricebook_Ref__r.Price_Book_Type__c,
            'Below-floor discount should land on lowest existing tier');
    }

    @isTest
    static void insert_salesPriceAboveStandard_notRequired() {
        Map<String, Object> ctx = setupContext(new Map<String, Decimal>{
            'Price list5' => 1000, 'Price list1' => 200
        }, false);

        Test.startTest();
        // UnitPrice 1200 (above standard), zero discount -> final 1200 >= 1000 -> Not Required
        QuoteLineItem qli = buildQli(ctx, 1200, 0);
        insert qli;
        Test.stopTest();

        QuoteLineItem saved = [SELECT Price_Status__c FROM QuoteLineItem WHERE Id = :qli.Id];
        System.assertEquals('Not Required', saved.Price_Status__c,
            'Raising Sales Price above standard does not need approval');
    }

    @isTest
    static void serviceItem_skipsTierLogic_andApproval() {
        // Set up a service product (no pricebook tiers needed - user picks any PBE).
        Account acc = new Account(Name = 'Svc Test'); insert acc;
        Id stdPbId = Test.getStandardPricebookId();
        Opportunity opp = new Opportunity(
            Name = 'Svc Deal', AccountId = acc.Id, StageName = 'Qualified',
            CloseDate = Date.today().addDays(30), Pricebook2Id = stdPbId
        );
        insert opp;

        Product2 svc = new Product2(
            Name = 'Calibration Visit', ProductCode = 'SVC-VISIT', IsActive = true,
            Service_Item__c = 'Yes', Tax__c = 5
        );
        insert svc;
        // Any valid PricebookEntry on the Quote's pricebook is acceptable for service items.
        PricebookEntry svcPbe = new PricebookEntry(
            Pricebook2Id = stdPbId, Product2Id = svc.Id, UnitPrice = 0, IsActive = true
        );
        insert svcPbe;

        Quote q = new Quote(
            Name = 'Svc Quote', OpportunityId = opp.Id, Pricebook2Id = stdPbId,
            Status = 'Draft', Price_Status__c = 'Draft'
        );
        insert q;

        Test.startTest();
        // User enters their own price and tax. Trigger must not overwrite Tax__c
        // with Product2.Tax__c, and must not enforce a floor.
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id, Product2Id = svc.Id, PricebookEntryId = svcPbe.Id,
            Quantity = 1, UnitPrice = 3000, Discount = 50, Tax__c = 12
        );
        insert qli;
        Test.stopTest();

        QuoteLineItem saved = [SELECT Tax__c, UnitPrice, Discount, Price_Status__c, Source_Pricebook_Ref__c
                               FROM QuoteLineItem WHERE Id = :qli.Id];
        System.assertEquals(12, saved.Tax__c, 'Service-line tax must not be overwritten from Product2');
        System.assertEquals(3000, saved.UnitPrice, 'Service-line Sales Price is user-entered');
        System.assertEquals('Not Required', saved.Price_Status__c,
            'Service items always return Not Required regardless of discount');
        System.assertEquals(null, saved.Source_Pricebook_Ref__c,
            'Service lines do not carry a resolved tier');
    }

    @isTest
    static void quoteRollup_promotesAndReverts() {
        Map<String, Object> ctx = setupContext(new Map<String, Decimal>{
            'Price list5' => 1000, 'Price list1' => 200
        }, false);
        Quote q = (Quote) ctx.get('quote');

        // Insert a line that requires approval
        QuoteLineItem approvalQli = buildQli(ctx, 1000, 50); // final 500 < 1000 -> Approval Required
        insert approvalQli;
        Quote afterInsert = [SELECT Price_Status__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals('Approval Required', afterInsert.Price_Status__c,
            'Quote must roll up to Approval Required when any line needs approval');

        // Delete that line - Quote rolls back to Draft
        Test.startTest();
        delete approvalQli;
        Test.stopTest();
        Quote afterDelete = [SELECT Price_Status__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals('Draft', afterDelete.Price_Status__c,
            'Quote rolls back to Draft when no lines need approval');
    }

    @isTest
    static void quoteRollup_doesNotRegressApproved() {
        Map<String, Object> ctx = setupContext(new Map<String, Decimal>{
            'Price list5' => 1000
        }, false);
        Quote q = (Quote) ctx.get('quote');
        q.Price_Status__c = 'Approved';
        update q;

        Test.startTest();
        QuoteLineItem qli = buildQli(ctx, 1000, 0);
        insert qli;
        Test.stopTest();

        Quote reread = [SELECT Price_Status__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals('Approved', reread.Price_Status__c,
            'Approved quotes must not regress when a new non-approval line is added');
    }

    @isTest
    static void update_unitPrice_recomputesStatus() {
        Map<String, Object> ctx = setupContext(new Map<String, Decimal>{
            'Price list5' => 1000, 'Price list1' => 200
        }, false);

        QuoteLineItem qli = buildQli(ctx, 1000, 0); // zero discount -> Not Required
        insert qli;
        System.assertEquals('Not Required',
            [SELECT Price_Status__c FROM QuoteLineItem WHERE Id = :qli.Id].Price_Status__c);

        Test.startTest();
        // Apply a 20% discount via update -> final 800 < 1000 -> Approval Required
        qli.Discount = 20;
        update qli;
        Test.stopTest();

        QuoteLineItem reread = [SELECT Price_Status__c FROM QuoteLineItem WHERE Id = :qli.Id];
        System.assertEquals('Approval Required', reread.Price_Status__c);
    }

    @isTest
    static void bypass_flagSkipsStamping() {
        Map<String, Object> ctx = setupContext(new Map<String, Decimal>{
            'Price list5' => 1000
        }, false);

        Test.startTest();
        QuoteLineItemTriggerHandler.bypass = true;
        try {
            // With bypass, the trigger must not stamp Tax__c or Price_Status__c.
            // UnitPrice below floor is normally blocked; bypass lets it through.
            QuoteLineItem qli = buildQli(ctx, 500, 0);
            qli.Tax__c = 99;
            qli.Price_Status__c = 'Not Required';
            insert qli;
            QuoteLineItem saved = [SELECT Tax__c, Price_Status__c FROM QuoteLineItem WHERE Id = :qli.Id];
            System.assertEquals(99, saved.Tax__c, 'Bypass must preserve caller-supplied Tax__c');
        } finally {
            QuoteLineItemTriggerHandler.bypass = false;
        }
        Test.stopTest();
    }
}
