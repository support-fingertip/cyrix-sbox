@IsTest
public class ExpenseTriggerHandlerTest {

    /* =========================================================
       Utility: Get valid Expense Type safely (restricted picklist)
    ========================================================= */
    private static String getValidExpenseType() {
        return Expense__c.Expense_Type__c
            .getDescribe()
            .getPicklistValues()[0]
            .getValue();
    }

    /* =========================================================
       Test when General Settings EXISTS
    ========================================================= */
    @IsTest
    static void testAfterInsert_WithSettings() {

        // Profile
        Profile adminProfile =
            [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        // Users for approvers
        User level1 = new User(
            Alias = 'l1',
            Email = 'l1@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Level1',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'l1' + System.currentTimeMillis() + '@test.com'
        );

        User level2 = new User(
            Alias = 'l2',
            Email = 'l2@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Level2',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'l2' + System.currentTimeMillis() + '@test.com'
        );

        insert new List<User>{ level1, level2 };

        // General Settings
        General_Settings__c gs = new General_Settings__c(
            Expense_Level_1_Approver__c = level1.Id,
            Expense_Level_2_Approver__c = level2.Id
        );
        insert gs;

        String expenseType = getValidExpenseType();

        // Insert Expense (triggers afterInsert)
        Expense__c exp = new Expense__c(
            Expense_Type__c = expenseType,
            OwnerId = level1.Id
        );

        Test.startTest();
        insert exp;
        Test.stopTest();

        // Validate approvers populated
        Expense__c insertedExp = [
            SELECT Expense_Approver_L1__c,
                   Expense_Finance_Department_Approver__c
            FROM Expense__c
            WHERE Id = :exp.Id
        ];

        System.assertEquals(level1.Id, insertedExp.Expense_Approver_L1__c);
        System.assertEquals(level2.Id, insertedExp.Expense_Finance_Department_Approver__c);
    }

    /* =========================================================
       Test when General Settings DOES NOT exist
    ========================================================= */
    @IsTest
    static void testAfterInsert_WithoutSettings() {

        // Ensure no General Settings
        delete [SELECT Id FROM General_Settings__c];

        Profile adminProfile =
            [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        User usr = new User(
            Alias = 'usr',
            Email = 'usr@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'usr' + System.currentTimeMillis() + '@test.com'
        );
        insert usr;

        String expenseType = getValidExpenseType();

        Expense__c exp = new Expense__c(
            Expense_Type__c = expenseType,
            OwnerId = usr.Id
        );

        Test.startTest();
        insert exp;
        Test.stopTest();

        // Validate fields remain NULL (safe exit path)
        Expense__c insertedExp = [
            SELECT Expense_Approver_L1__c,
                   Expense_Finance_Department_Approver__c
            FROM Expense__c
            WHERE Id = :exp.Id
        ];

        System.assertEquals(null, insertedExp.Expense_Approver_L1__c);
        System.assertEquals(null, insertedExp.Expense_Finance_Department_Approver__c);
    }
}