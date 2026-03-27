@isTest
private class QuoteApprovalControllerTest {

    @TestSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Test Hospital');
        insert acc;

        Product2 prod = new Product2(
            Name = 'Test X-Ray Machine',
            IsActive = true,
            Manager_Discount_Up_to__c = 8,
            VP_Sales_Discount_Up_to__c = 12,
            CEO_Sales_Discount_Up_to__c = 15
        );
        insert prod;

        Id stdPricebookId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100000,
            IsActive = true
        );
        insert pbe;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(30),
            Amount = 500000,
            Pricebook2Id = stdPricebookId
        );
        insert opp;

        Quote qt = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = stdPricebookId,
            Quote_Date__c = Date.today(),
            Valid_Till__c = Date.today().addDays(30),
            Price_Status__c = 'Draft'
        );
        insert qt;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = qt.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 90000,
            Discount = 10,
            Price_Status__c = 'Standard'
        );
        insert qli;
    }

    @isTest
    static void testGetQuoteLineItems() {
        Quote qt = [SELECT Id FROM Quote LIMIT 1];

        Test.startTest();
        QuoteApprovalController.QuoteApprovalWrapper result =
            QuoteApprovalController.getQuoteLineItems(qt.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.quote);
        System.assertEquals(1, result.lineItems.size());
        System.assertEquals('Standard', result.lineItems[0].priceStatus);
    }

    @isTest
    static void testSubmitForApproval() {
        Quote qt = [SELECT Id FROM Quote LIMIT 1];
        QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];

        Test.startTest();
        QuoteApprovalController.submitForApproval(
            new List<Id>{ qli.Id }, qt.Id, 'Please review discount'
        );
        Test.stopTest();

        QuoteLineItem updated = [SELECT Price_Status__c FROM QuoteLineItem WHERE Id = :qli.Id];
        System.assertEquals('Approval Required', updated.Price_Status__c);

        Quote updatedQt = [SELECT Price_Status__c FROM Quote WHERE Id = :qt.Id];
        System.assertEquals('Approval Required', updatedQt.Price_Status__c);
    }

    @isTest
    static void testApproveLineItems() {
        Quote qt = [SELECT Id FROM Quote LIMIT 1];
        QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];
        qli.Price_Status__c = 'Approval Required';
        update qli;

        Test.startTest();
        QuoteApprovalController.approveLineItems(
            new List<Id>{ qli.Id }, qt.Id, 'Approved - within limits'
        );
        Test.stopTest();

        QuoteLineItem updated = [SELECT Price_Status__c FROM QuoteLineItem WHERE Id = :qli.Id];
        System.assertEquals('Approved', updated.Price_Status__c);
    }

    @isTest
    static void testRejectLineItems() {
        Quote qt = [SELECT Id FROM Quote LIMIT 1];
        QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];
        qli.Price_Status__c = 'Approval Required';
        update qli;

        Test.startTest();
        QuoteApprovalController.rejectLineItems(
            new List<Id>{ qli.Id }, qt.Id, 'Discount too high'
        );
        Test.stopTest();

        QuoteLineItem updated = [SELECT Price_Status__c FROM QuoteLineItem WHERE Id = :qli.Id];
        System.assertEquals('Rejected', updated.Price_Status__c);

        Quote updatedQt = [SELECT Price_Status__c FROM Quote WHERE Id = :qt.Id];
        System.assertEquals('Rejected', updatedQt.Price_Status__c);
    }

    @isTest
    static void testEvaluateDiscountThresholds() {
        Quote qt = [SELECT Id FROM Quote LIMIT 1];

        Test.startTest();
        QuoteApprovalController.evaluateDiscountThresholds(qt.Id);
        Test.stopTest();

        QuoteLineItem updated = [SELECT Price_Status__c, Discount FROM QuoteLineItem WHERE QuoteId = :qt.Id];
        // Discount is 10%, Manager limit is 8%, so should require approval
        System.assertEquals('Approval Required', updated.Price_Status__c);
    }
}
