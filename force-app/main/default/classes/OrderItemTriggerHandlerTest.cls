/**
 * Coverage for OrderItemTriggerHandler under the
 * discount-vs-Discount__c algorithm in PricebookTierService.evaluate.
 *
 * The trigger feeds each OrderItem through evaluate() and stamps
 * Price_Status__c, Source_Pricebook_Ref__c, and (re-fetched) UnitPrice.
 * After-insert/update rolls Price_Status up to the parent Order.
 */
@isTest
private class OrderItemTriggerHandlerTest {

    // Build a product with a Standard PBE plus tier PricebookEntries
    // (key = Price_Book_Type__c, value = [unitPrice, discountCap%]).
    private static Product2 setupProduct(Map<String, Decimal[]> tierSpecs) {
        Product2 p = new Product2(Name = 'OI Test ' + String.valueOf(Math.abs(Crypto.getRandomLong())), IsActive = true);
        insert p;

        Id stdPbId = Test.getStandardPricebookId();
        insert new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = p.Id,
            UnitPrice = 1000,
            IsActive = true
        );

        if (tierSpecs == null || tierSpecs.isEmpty()) return p;

        List<Pricebook2> pbs = new List<Pricebook2>();
        for (String tier : tierSpecs.keySet()) {
            pbs.add(new Pricebook2(
                Name = tier + ' ' + p.Id,
                IsActive = true,
                Price_Book_Type__c = tier
            ));
        }
        insert pbs;

        List<PricebookEntry> entries = new List<PricebookEntry>();
        for (Pricebook2 pb : pbs) {
            Decimal[] spec = tierSpecs.get(pb.Price_Book_Type__c);
            entries.add(new PricebookEntry(
                Pricebook2Id = pb.Id,
                Product2Id = p.Id,
                UnitPrice = spec[0],
                Discount__c = spec[1],
                IsActive = true,
                UseStandardPrice = false
            ));
        }
        insert entries;
        return p;
    }

    private static PricebookEntry stdPbeFor(Id productId) {
        return [
            SELECT Id FROM PricebookEntry
            WHERE Product2Id = :productId AND Pricebook2.IsStandard = true LIMIT 1
        ];
    }

    private static Order createOrder() {
        Account a = new Account(Name = 'Test Acct');
        insert a;
        Order o = new Order(
            AccountId      = a.Id,
            Pricebook2Id   = Test.getStandardPricebookId(),
            Status         = 'Draft',
            EffectiveDate  = Date.today()
        );
        insert o;
        return o;
    }

    @isTest
    static void discountWithinCeilingIsNotRequired() {
        // Generous ceiling (PL5 cap won't actually cover non-zero discount,
        // but PL4 covers 10% — by default Sales Engineer ceiling = PL4).
        Product2 p = setupProduct(new Map<String, Decimal[]>{
            'Price List 5' => new Decimal[]{1000, 0},
            'Price List 4' => new Decimal[]{1000, 10},
            'Price List 1' => new Decimal[]{1000, 30}
        });
        PricebookEntry pbe = stdPbeFor(p.Id);
        Order o = createOrder();

        Test.startTest();
        OrderItem oi = new OrderItem(
            OrderId = o.Id,
            Product2Id = p.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 1000,
            Discount__c = 5
        );
        insert oi;
        Test.stopTest();

        OrderItem refreshed = [SELECT Price_Status__c FROM OrderItem WHERE Id = :oi.Id];
        System.assertEquals('Not Required', refreshed.Price_Status__c,
            'Discount within the running user ceiling should be Not Required');
    }

    @isTest
    static void discountOverEveryTierFlipsApprovalRequired() {
        // 40% discount overruns even PL1 (30%). Falls back to PL1 with
        // Approval Required and exceedsAllTiers semantics.
        Product2 p = setupProduct(new Map<String, Decimal[]>{
            'Price List 5' => new Decimal[]{1000, 0},
            'Price List 4' => new Decimal[]{1000, 10},
            'Price List 1' => new Decimal[]{1000, 30}
        });
        PricebookEntry pbe = stdPbeFor(p.Id);
        Order o = createOrder();

        Test.startTest();
        OrderItem oi = new OrderItem(
            OrderId = o.Id,
            Product2Id = p.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 1000,
            Discount__c = 40
        );
        insert oi;
        Test.stopTest();

        OrderItem refreshed = [SELECT Price_Status__c FROM OrderItem WHERE Id = :oi.Id];
        System.assertEquals('Approval Required', refreshed.Price_Status__c,
            'Discount over the broadest tier should be Approval Required');

        Order parent = [SELECT Price_Status__c FROM Order WHERE Id = :o.Id];
        System.assertEquals('Approval Required', parent.Price_Status__c,
            'Parent Order rolls up to Approval Required when any line needs approval');
    }

    @isTest
    static void updateDiscountDownwardFlipsBackToNotRequired() {
        Product2 p = setupProduct(new Map<String, Decimal[]>{
            'Price List 5' => new Decimal[]{1000, 0},
            'Price List 4' => new Decimal[]{1000, 10},
            'Price List 1' => new Decimal[]{1000, 30}
        });
        PricebookEntry pbe = stdPbeFor(p.Id);
        Order o = createOrder();

        OrderItem oi = new OrderItem(
            OrderId = o.Id,
            Product2Id = p.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 1000,
            Discount__c = 40
        );
        insert oi;

        Order afterInsert = [SELECT Price_Status__c FROM Order WHERE Id = :o.Id];
        System.assertEquals('Approval Required', afterInsert.Price_Status__c);

        Test.startTest();
        oi.Discount__c = 5;
        update oi;
        Test.stopTest();

        OrderItem refreshed = [SELECT Price_Status__c FROM OrderItem WHERE Id = :oi.Id];
        System.assertEquals('Not Required', refreshed.Price_Status__c,
            'Bringing the discount back inside the ceiling reverts to Not Required');
    }

    @isTest
    static void mixedItemsRollUpToApprovalRequired() {
        Product2 p = setupProduct(new Map<String, Decimal[]>{
            'Price List 5' => new Decimal[]{1000, 0},
            'Price List 4' => new Decimal[]{1000, 10},
            'Price List 1' => new Decimal[]{1000, 30}
        });
        PricebookEntry pbe = stdPbeFor(p.Id);
        Order o = createOrder();

        Test.startTest();
        insert new List<OrderItem>{
            new OrderItem(
                OrderId = o.Id, Product2Id = p.Id, PricebookEntryId = pbe.Id,
                Quantity = 1, UnitPrice = 1000, Discount__c = 5
            ),
            new OrderItem(
                OrderId = o.Id, Product2Id = p.Id, PricebookEntryId = pbe.Id,
                Quantity = 1, UnitPrice = 1000, Discount__c = 45
            )
        };
        Test.stopTest();

        Order refreshed = [SELECT Price_Status__c FROM Order WHERE Id = :o.Id];
        System.assertEquals('Approval Required', refreshed.Price_Status__c,
            'One Approval Required child should push the parent Order to Approval Required');
    }

    @isTest
    static void serviceItemAlwaysNotRequired_evenWithLargeDiscount() {
        Product2 svc = new Product2(
            Name = 'Service ' + String.valueOf(Math.abs(Crypto.getRandomLong())),
            IsActive = true,
            Service_Item__c = 'Yes',
            Tax__c = 5
        );
        insert svc;
        insert new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = svc.Id,
            UnitPrice = 500,
            IsActive = true
        );

        PricebookEntry pbe = stdPbeFor(svc.Id);
        Order o = createOrder();

        Test.startTest();
        OrderItem oi = new OrderItem(
            OrderId = o.Id,
            Product2Id = svc.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 500,
            Discount__c = 90
        );
        insert oi;
        Test.stopTest();

        OrderItem refreshed = [SELECT Price_Status__c FROM OrderItem WHERE Id = :oi.Id];
        System.assertEquals('Not Required', refreshed.Price_Status__c,
            'Service items short-circuit to Not Required regardless of discount');
    }

    @isTest
    static void computeRollupReturnsNotRequiredForEmpty() {
        String s = OrderItemTriggerHandler.computeRollup(new List<OrderItem>());
        System.assertEquals('Not Required', s);
    }
}
