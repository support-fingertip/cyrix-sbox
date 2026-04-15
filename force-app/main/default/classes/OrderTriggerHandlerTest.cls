@isTest
private class OrderTriggerHandlerTest {

    private static Order createDraftOrder() {
        Account a = new Account(Name = 'Acme Test');
        insert a;

        Id pbId = Test.getStandardPricebookId();

        Order o = new Order(
            AccountId      = a.Id,
            Pricebook2Id   = pbId,
            Status         = 'Draft',
            EffectiveDate  = Date.today()
        );
        insert o;
        return o;
    }

    @isTest
    static void cancellationTriggersNotificationPath() {
        Order o = createDraftOrder();

        Test.startTest();
        o.Status = 'Cancelled';
        o.Cancellation_Reason__c = 'Customer changed their mind';
        update o;
        Test.stopTest();

        Order refreshed = [
            SELECT Id, Status, Cancellation_Reason__c
            FROM Order
            WHERE Id = :o.Id
        ];
        System.assertEquals('Cancelled', refreshed.Status,
            'Status should be Cancelled after update');
        System.assertEquals('Customer changed their mind', refreshed.Cancellation_Reason__c,
            'Reason should be persisted');
    }

    @isTest
    static void nonCancellationUpdateDoesNothing() {
        Order o = createDraftOrder();

        Test.startTest();
        // Update a non-Status field. Handler should skip the notification path entirely.
        o.Description = 'Just a note';
        update o;
        Test.stopTest();

        Order refreshed = [SELECT Status FROM Order WHERE Id = :o.Id];
        System.assertEquals('Draft', refreshed.Status,
            'Status must remain Draft when only Description changes');
    }

    @isTest
    static void statusChangeToNonCancelledDoesNothing() {
        Order o = createDraftOrder();

        Test.startTest();
        o.Status = 'Draft'; // no-op change, still not Cancelled
        update o;
        Test.stopTest();

        Order refreshed = [SELECT Status FROM Order WHERE Id = :o.Id];
        System.assertEquals('Draft', refreshed.Status);
    }

    @isTest
    static void bodyIncludesAccountAndReason() {
        Account a = new Account(Name = 'Body Acct');
        insert a;
        Order o = new Order(
            AccountId = a.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status = 'Cancelled',
            EffectiveDate = Date.today(),
            Cancellation_Reason__c = 'Dup order'
        );
        insert o;

        Order reloaded = [
            SELECT OrderNumber, Cancellation_Reason__c, Account.Name
            FROM Order
            WHERE Id = :o.Id
        ];

        String body = OrderTriggerHandler.buildBody(reloaded);
        System.assert(body.contains('Body Acct'), 'Body should include account name');
        System.assert(body.contains('Dup order'), 'Body should include cancellation reason');
        System.assert(body.contains('has been cancelled'), 'Body should state cancellation');
    }

    @isTest
    static void bodyGracefulWhenOptionalFieldsAreBlank() {
        Order stub = new Order(
            OrderNumber = '00000001'
            // no Account, no reason
        );
        String body = OrderTriggerHandler.buildBody(stub);
        System.assertEquals(
            'Order 00000001 has been cancelled.',
            body,
            'Body should gracefully omit missing parts'
        );
    }
}
