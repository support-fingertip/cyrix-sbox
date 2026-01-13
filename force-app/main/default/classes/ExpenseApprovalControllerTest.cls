@IsTest
public class ExpenseApprovalControllerTest {

    /* =========================================================
       Picklist Safe Resolvers (HEADER vs LINE ITEM)
    ========================================================= */
    private static String getExpenseHeaderType() {
        return Expense__c.Expense_Type__c
            .getDescribe()
            .getPicklistValues()[0]
            .getValue();
    }

    private static String getLineItemExpenseType() {
        return Expenses_Line_Item__c.Expense_Type__c
            .getDescribe()
            .getPicklistValues()[0]
            .getValue();
    }

    /* =========================================================
       TEST DATA SETUP
    ========================================================= */
    @TestSetup
    static void setupData() {

        Profile adminProfile =
            [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        User approver1 = new User(
            Alias = 'app1',
            Email = 'app1@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Approver1',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'approver1' + System.currentTimeMillis() + '@test.com'
        );

        User approver2 = new User(
            Alias = 'app2',
            Email = 'app2@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Approver2',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'approver2' + System.currentTimeMillis() + '@test.com'
        );

        insert new List<User>{ approver1, approver2 };

        Travel_Eligibility__c te = new Travel_Eligibility__c(
            Profile__c = 'System Administrator',
            Travel_Mode_HQ__c = 'Car;Bike;Autorishaw',
            Travel_Mode_UC__c = 'Car;Bike'
        );
        insert te;

        String headerType   = getExpenseHeaderType();     // ✅ Expense__c
        String lineItemType = getLineItemExpenseType();   // ✅ Expenses_Line_Item__c

        /* ---------- Expense HEADER ---------- */
        Expense__c exp = new Expense__c(
            Expense_Type__c = headerType,
            Expense_Approver_L1__c = approver1.Id,
            Expense_Approver_L2__c = approver2.Id,
            Expense_Finance_Department_Approver__c = approver2.Id,
            OwnerId = approver1.Id
        );
        insert exp;

        /* ---------- Expense LINE ITEM ---------- */
        Expenses_Line_Item__c eli = new Expenses_Line_Item__c(
            Expense__c = exp.Id,
            Expense_Type__c = lineItemType,
            Approval_Status__c = 'Pending',
            Submitted_Amount__c = 100,
            Calculated_KM__c = 10,
            System_Calculated_Amount__c = 90,
            Total_KM__c = 10,
            Expense_Date__c = Date.today(),
            Travel_Mode__c = 'Car',
            Amount__c = 100
        );
        insert eli;
    }

    /* =========================================================
       getExpenseLineItems
    ========================================================= */
    @IsTest
    static void testGetExpenseLineItems() {
        Expense__c exp = [SELECT Id FROM Expense__c LIMIT 1];

        Test.startTest();
        ExpenseApprovalController res =
            ExpenseApprovalController.getExpenseLineItems(exp.Id);
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assert(res.result.size() > 0);
    }

    /* =========================================================
       getExpenseDetails
    ========================================================= */
    @IsTest
    static void testGetExpenseDetails() {
        Expense__c exp = [SELECT Id FROM Expense__c LIMIT 1];

        Test.startTest();
        ExpenseApprovalController.DataBox db =
            ExpenseApprovalController.getExpenseDetails(exp.Id);
        Test.stopTest();

        System.assertEquals(exp.Id, db.expense.Id);
    }

    /* =========================================================
       updateExpenseLineItems
    ========================================================= */
    @IsTest
    static void testUpdateExpenseLineItems() {
        Expenses_Line_Item__c eli =
            [SELECT Id FROM Expenses_Line_Item__c LIMIT 1];

        eli.Remarks__c = 'Updated from test';

        Test.startTest();
        ExpenseApprovalController.updateExpenseLineItems(
            new List<Expenses_Line_Item__c>{ eli }
        );
        Test.stopTest();

        System.assertEquals(
            'Updated from test',
            [SELECT Remarks__c FROM Expenses_Line_Item__c WHERE Id = :eli.Id]
                .Remarks__c
        );
    }

    /* =========================================================
       approveExpenseItems
    ========================================================= */
    @IsTest
    static void testApproveExpenseItems() {
        Expense__c exp =
            [SELECT Id, Expense_Approver_L1__c FROM Expense__c LIMIT 1];
        Expenses_Line_Item__c eli =
            [SELECT Id FROM Expenses_Line_Item__c LIMIT 1];

        System.runAs(new User(Id = exp.Expense_Approver_L1__c)) {
            Test.startTest();
            ExpenseApprovalController.approveExpenseItems(
                new List<Id>{ eli.Id },
                exp.Id,
                'Approved in test'
            );
            Test.stopTest();
        }

        System.assertEquals(
            'Level 1 Approved',
            [SELECT Approval_Status__c FROM Expenses_Line_Item__c WHERE Id = :eli.Id]
                .Approval_Status__c
        );
    }

    /* =========================================================
       rejectExpenses
    ========================================================= */
    @IsTest
    static void testRejectExpenses() {
        Expense__c exp =
            [SELECT Id, Expense_Approver_L1__c FROM Expense__c LIMIT 1];
        Expenses_Line_Item__c eli =
            [SELECT Id FROM Expenses_Line_Item__c LIMIT 1];

        System.runAs(new User(Id = exp.Expense_Approver_L1__c)) {
            Test.startTest();
            ExpenseApprovalController.rejectExpenses(
                new List<Id>{ eli.Id },
                exp.Id,
                'Rejected in test'
            );
            Test.stopTest();
        }

        System.assertEquals(
            'Level 1 Rejected',
            [SELECT Approval_Status__c FROM Expenses_Line_Item__c WHERE Id = :eli.Id]
                .Approval_Status__c
        );
    }

    /* =========================================================
       rejectExpenses1
    ========================================================= */
    @IsTest
    static void testRejectExpenses1() {
        Expenses_Line_Item__c eli =
            [SELECT Id, Approval_Status__c FROM Expenses_Line_Item__c LIMIT 1];

        eli.Approval_Status__c = 'Pending';
        update eli;

        Test.startTest();
        ExpenseApprovalController.rejectExpenses1(
            new List<Id>{ eli.Id },
            null,
            null
        );
        Test.stopTest();

        System.assertEquals(
            'Level 1 Rejected',
            [SELECT Approval_Status__c FROM Expenses_Line_Item__c WHERE Id = :eli.Id]
                .Approval_Status__c
        );
    }
}