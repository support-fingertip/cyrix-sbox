@IsTest
private class CreateSalesOrderControllerTest {

    @TestSetup
    static void setup() {
        // Account
        Account acc = new Account(Name = 'Test Customer');
        insert acc;

        // Contact
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = acc.Id,
            Email = 'test@example.com',
            Phone = '1234567890'
        );
        insert con;

        // Product + standard PricebookEntry + custom pricebook entry
        Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
        insert prod;

        Id stdPbId = Test.getStandardPricebookId();
        PricebookEntry stdPbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert stdPbe;

        // Opportunity (required so Quote can have a Pricebook2Id reliably tied to Opp)
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id,
            Pricebook2Id = stdPbId
        );
        insert opp;

        // Quote
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = stdPbId,
            ContactId = con.Id,
            Email = 'test@example.com',
            Phone = '1234567890',
            BillingStreet = '1 Test St',
            BillingCity = 'Testville',
            BillingState = 'TS',
            BillingPostalCode = '00001',
            BillingCountry = 'India',
            ShippingStreet = '1 Test St',
            ShippingCity = 'Testville',
            ShippingState = 'TS',
            ShippingPostalCode = '00001',
            ShippingCountry = 'India'
        );
        insert q;

        // Quote Line Item
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            Product2Id = prod.Id,
            PricebookEntryId = stdPbe.Id,
            Quantity = 2,
            UnitPrice = 100
        );
        insert qli;

        // Branch (Warehouse)
        Branch__c br = new Branch__c(Name = 'Main Warehouse');
        insert br;
    }

    @IsTest
    static void testGetQuoteDetails() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];

        Test.startTest();
        CreateSalesOrderController.QuoteContext ctx =
            CreateSalesOrderController.getQuoteDetails(q.Id);
        Test.stopTest();

        System.assertNotEquals(null, ctx, 'Context should be returned');
        System.assertEquals(q.Id, ctx.quoteId);
        System.assertEquals('Test Customer', ctx.customerName);
        System.assertEquals(1, ctx.items.size(), 'Should return 1 quote line item');
        System.assertEquals(2, ctx.items[0].quantity);
    }

    @IsTest
    static void testGetQuoteDetailsNullId() {
        Test.startTest();
        try {
            CreateSalesOrderController.getQuoteDetails(null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetWarehouses() {
        Test.startTest();
        List<CreateSalesOrderController.WarehouseOption> opts =
            CreateSalesOrderController.getWarehouses();
        Test.stopTest();

        System.assert(opts.size() >= 1, 'Should return at least one warehouse');
        System.assertEquals('Main Warehouse', opts[0].label);
    }

    @IsTest
    static void testCreateSalesOrderSuccess() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        QuoteLineItem qli = [SELECT Id, Quantity FROM QuoteLineItem LIMIT 1];
        Branch__c br = [SELECT Id FROM Branch__c LIMIT 1];

        CreateSalesOrderController.SelectedItem si =
            new CreateSalesOrderController.SelectedItem();
        si.lineId = qli.Id;
        si.quantity = 5;

        CreateSalesOrderController.SalesOrderInput input =
            new CreateSalesOrderController.SalesOrderInput();
        input.deliveryCommittedDate = Date.today().addDays(7);
        input.warehouseId = br.Id;
        input.remarks = 'Test remarks';
        input.creditOrder = true;
        input.selectedItems = new List<CreateSalesOrderController.SelectedItem>{ si };

        Test.startTest();
        Id orderId = CreateSalesOrderController.createSalesOrder(q.Id, input);
        Test.stopTest();

        System.assertNotEquals(null, orderId, 'Order Id should be returned');

        Order ord = [
            SELECT Id, Status, EffectiveDate, Branch__c, Description, is_Active__c, QuoteId
            FROM Order
            WHERE Id = :orderId
        ];
        System.assertEquals('Draft', ord.Status);
        System.assertEquals(br.Id, ord.Branch__c);
        System.assertEquals('Test remarks', ord.Description);
        System.assertEquals(true, ord.is_Active__c);
        System.assertEquals(q.Id, ord.QuoteId);

        List<OrderItem> items = [
            SELECT Id, Quantity, UnitPrice FROM OrderItem WHERE OrderId = :orderId
        ];
        System.assertEquals(1, items.size(), 'Should create one OrderItem');
        System.assertEquals(5, items[0].Quantity);
    }

    @IsTest
    static void testCreateSalesOrderMissingInputs() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];

        Test.startTest();

        // Null quoteId
        try {
            CreateSalesOrderController.createSalesOrder(null, new CreateSalesOrderController.SalesOrderInput());
            System.assert(false, 'Expected exception for null quoteId');
        } catch (AuraHandledException e) { System.assert(true); }

        // Null input
        try {
            CreateSalesOrderController.createSalesOrder(q.Id, null);
            System.assert(false, 'Expected exception for null input');
        } catch (AuraHandledException e) { System.assert(true); }

        // Missing delivery date
        try {
            CreateSalesOrderController.SalesOrderInput inp =
                new CreateSalesOrderController.SalesOrderInput();
            CreateSalesOrderController.createSalesOrder(q.Id, inp);
            System.assert(false, 'Expected exception for missing delivery date');
        } catch (AuraHandledException e) { System.assert(true); }

        // Missing warehouse
        try {
            CreateSalesOrderController.SalesOrderInput inp =
                new CreateSalesOrderController.SalesOrderInput();
            inp.deliveryCommittedDate = Date.today();
            CreateSalesOrderController.createSalesOrder(q.Id, inp);
            System.assert(false, 'Expected exception for missing warehouse');
        } catch (AuraHandledException e) { System.assert(true); }

        // No selected items
        try {
            Branch__c br = [SELECT Id FROM Branch__c LIMIT 1];
            CreateSalesOrderController.SalesOrderInput inp =
                new CreateSalesOrderController.SalesOrderInput();
            inp.deliveryCommittedDate = Date.today();
            inp.warehouseId = br.Id;
            inp.selectedItems = new List<CreateSalesOrderController.SelectedItem>();
            CreateSalesOrderController.createSalesOrder(q.Id, inp);
            System.assert(false, 'Expected exception for empty selectedItems');
        } catch (AuraHandledException e) { System.assert(true); }

        Test.stopTest();
    }
}
