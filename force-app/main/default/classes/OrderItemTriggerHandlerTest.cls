/**
 * Coverage for OrderItemTriggerHandler — discount threshold evaluation
 * and the Order.Price_Status__c rollup.
 */
@isTest
private class OrderItemTriggerHandlerTest {

    private static Product2 createProduct(
        Decimal managerLimit, Decimal vpLimit, Decimal ceoLimit
    ) {
        Product2 p = new Product2(
            Name = 'Test Prod',
            IsActive = true,
            Manager_Discount_Up_to__c = managerLimit,
            VP_Sales_Discount_Up_to__c = vpLimit,
            CEO_Sales_Discount_Up_to__c = ceoLimit
        );
        insert p;
        return p;
    }

    private static PricebookEntry createPbe(Id productId) {
        Id stdPbId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id   = productId,
            UnitPrice    = 1000,
            IsActive     = true
        );
        insert pbe;
        return pbe;
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
    static void discountBelowManagerLimitIsNotRequired() {
        Product2 p = createProduct(10, 20, 30);
        PricebookEntry pbe = createPbe(p.Id);
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
            'Discount 5% below manager limit 10% should be Not Required');

        Order refreshedOrder = [SELECT Price_Status__c FROM Order WHERE Id = :o.Id];
        System.assertNotEquals('Approval Required', refreshedOrder.Price_Status__c,
            'Parent Order should NOT be Approval Required');
    }

    @isTest
    static void discountAboveCeoLimitIsApprovalRequired() {
        Product2 p = createProduct(10, 20, 30);
        PricebookEntry pbe = createPbe(p.Id);
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
            'Discount 40% above CEO limit 30% should be Approval Required');

        Order refreshedOrder = [SELECT Price_Status__c FROM Order WHERE Id = :o.Id];
        System.assertEquals('Approval Required', refreshedOrder.Price_Status__c,
            'Parent Order should roll up to Approval Required');
    }

    @isTest
    static void updateDiscountDownwardFlipsBackToNotRequired() {
        Product2 p = createProduct(10, 20, 30);
        PricebookEntry pbe = createPbe(p.Id);
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
            'Discount 5% should revert to Not Required');

        Order afterUpdate = [SELECT Price_Status__c FROM Order WHERE Id = :o.Id];
        System.assertNotEquals('Approval Required', afterUpdate.Price_Status__c,
            'Parent Order should roll back off Approval Required');
    }

    @isTest
    static void mixedItemsRollUpToApprovalRequired() {
        Product2 p = createProduct(10, 20, 30);
        PricebookEntry pbe = createPbe(p.Id);
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
            'One Approval Required child should push parent to Approval Required');
    }

    @isTest
    static void computeRollupReturnsNotRequiredForEmpty() {
        String s = OrderItemTriggerHandler.computeRollup(new List<OrderItem>());
        System.assertEquals('Not Required', s);
    }
}
