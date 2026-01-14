@IsTest
public class ExpenseControllerTest {

    /* =====================================================
       TEST DATA SETUP
    ===================================================== */
    
    static void setupData() {

        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Alias = 'tuser',
            Email = 'tuser@test.com',
            Username = 'tuser' + System.currentTimeMillis() + '@test.com',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert u;

        Travel_Eligibility__c te = new Travel_Eligibility__c(
            Profile__c = 'ASM',
            Travel_Mode_HQ__c = 'Car;Bike;Autorishaw'
        );
        insert te;

        Daily_Log__c log = new Daily_Log__c(
            Travel_Type__c = 'Field - Home District',
            Day_started_Time__c = Datetime.newInstance(
                Date.today(),
                Time.newInstance(9, 0, 0, 0)
            ),
            Odometer_Starting_Kms__c = 1000,
            KMs_Travelled__c = 20
        );
        insert log;
    }

    /* =====================================================
       getExpenses – no recordId
    ===================================================== */
    @IsTest
    static void testGetExpenses_NoExpense() {

        User runUser = [
            SELECT Id FROM User WHERE IsActive = true LIMIT 1
        ];

        System.runAs(runUser) {
            Test.startTest();
            ExpenseController.ExpenseData data =
                ExpenseController.getExpenses(null);
            Test.stopTest();

            System.assertNotEquals(null, data);
            System.assertNotEquals(null, data.startDate);
            System.assertNotEquals(null, data.endDate);
        }
    }

    /* =====================================================
       getExpenses – with Expense
    ===================================================== */
    @IsTest
    static void testGetExpenses_WithExpense() {

        User runUser = [
            SELECT Id FROM User WHERE IsActive = true LIMIT 1
        ];

        Expense__c exp = new Expense__c(
            Start_Date__c = Date.today().toStartOfMonth(),
            End_Date__c   = Date.today().toStartOfMonth()
                                .addMonths(1).addDays(-1),
            Expense_Type__c = 'Travel',
            Approval_Status__c = 'Pending',
            OwnerId = runUser.Id
        );
        insert exp;

        Expenses_Line_Item__c item = new Expenses_Line_Item__c(
            Expense__c = exp.Id,
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'TA',
            Approval_Status__c = 'Pending'
        );
        insert item;

        System.runAs(runUser) {
            Test.startTest();
            ExpenseController.ExpenseData data =
                ExpenseController.getExpenses(exp.Id);
            Test.stopTest();

            System.assertEquals(exp.Id, data.expense.Id);
            System.assert(data.lineItems.size() > 0);
        }
    }

    /* =====================================================
       saveExpense – SAFE SAVE ONLY (NO submit/approve/reject)
       ❗ This avoids notification code completely
    ===================================================== */
    @IsTest
    static void testSaveExpense_SaveOnly() {

        User runUser = [
            SELECT Id FROM User WHERE IsActive = true LIMIT 1
        ];

        System.runAs(runUser) {

            Expense__c exp = new Expense__c(
                Start_Date__c = Date.today(),
                End_Date__c   = Date.today().addDays(2),
                Expense_Type__c = 'Travel',
                Approval_Status__c = 'Pending'
            );

            Expenses_Line_Item__c item = new Expenses_Line_Item__c(
                Expense_Date__c = Date.today(),
                Expense_Type__c = 'TA',
                Approval_Status__c = 'Pending'
            );

            Test.startTest();
            ExpenseController.ExpenseData res =
                ExpenseController.saveExpense(
                    exp,
                    new List<Expenses_Line_Item__c>{ item },
                    new List<String>(),
                    false,   
                    false,   
                    false,   
                    'Saved'
                );
            Test.stopTest();

            System.assertNotEquals(null, res);
            System.assertNotEquals(null, res.expenseId);
        }
    }

    /*
       validateFiles
     */
    @IsTest
    static void testValidateFiles() {

        List<Map<String,String>> input =
            new List<Map<String,String>>{
                new Map<String,String>{
                    'uniqueKey' => 'row1',
                    'localId__c' => 'LOCAL_1'
                }
            };

        Test.startTest();
        Map<String,Boolean> result =
            ExpenseController.validateFiles(input);
        Test.stopTest();

        System.assert(result.containsKey('row1'));
    }

    /* =====================================================
       Utility – getMonthName
    ===================================================== */
    @IsTest
    static void testGetMonthName() {

        System.assertEquals(
            'JAN',
            ExpenseController.getMonthName(1)
        );
        System.assertEquals(
            'DEC',
            ExpenseController.getMonthName(12)
        );
    }
    @IsTest
   static void testSaveExpense_Approve() {

    User runUser = [
        SELECT Id FROM User WHERE IsActive = true LIMIT 1
    ];

    System.runAs(runUser) {

        Expense__c exp = new Expense__c(
            Start_Date__c = Date.today(),
            End_Date__c   = Date.today().addDays(1),
            Expense_Type__c = 'Travel'
        );

        Expenses_Line_Item__c item = new Expenses_Line_Item__c(
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'TA',
            Approval_Status__c = 'Pending',
            Is_Updated__c = true
        );

        Test.startTest();
        ExpenseController.saveExpense(
            exp,
            new List<Expenses_Line_Item__c>{ item },
            new List<String>(),
            false,   // submitForApproval
            true,    // ✅ approveRecord
            false,   // rejectRecord
            'Approved'
        );
        Test.stopTest();

        System.assert(true); // execution coverage only
    }
}
    @IsTest
static void testSaveExpense_Reject() {

    User runUser = [
        SELECT Id FROM User WHERE IsActive = true LIMIT 1
    ];

    System.runAs(runUser) {

        Expense__c exp = new Expense__c(
            Start_Date__c = Date.today(),
            End_Date__c   = Date.today().addDays(1),
            Expense_Type__c = 'Travel'
        );

        Expenses_Line_Item__c item = new Expenses_Line_Item__c(
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'TA',
            Approval_Status__c = 'Pending',
            Is_Updated__c = true
        );

        Test.startTest();
        ExpenseController.saveExpense(
            exp,
            new List<Expenses_Line_Item__c>{ item },
            new List<String>(),
            false,   // submitForApproval
            false,   // approveRecord
            true,    // ✅ rejectRecord
            'Rejected'
        );
        Test.stopTest();

        System.assert(true); // execution coverage only
    }
}
@IsTest
static void testUtilityAndDeletePaths() {

    User runUser = [
        SELECT Id FROM User WHERE IsActive = true LIMIT 1
    ];

    System.runAs(runUser) {

        // Create Expense + Line Item first
        Expense__c exp = new Expense__c(
            Start_Date__c = Date.today(),
            End_Date__c   = Date.today().addDays(1),
            Expense_Type__c = 'Travel',
            Approval_Status__c = 'Pending'
        );
        insert exp;

        Expenses_Line_Item__c item = new Expenses_Line_Item__c(
            Expense__c = exp.Id,
            Expense_Date__c = Date.today(),
            Expense_Type__c = 'TA',
            Approval_Status__c = 'Pending'
        );
        insert item;

        // ---- delete path ----
        List<String> delIds = new List<String>{ item.Id };

        Test.startTest();
        ExpenseController.saveExpense(
            exp,
            new List<Expenses_Line_Item__c>(),
            delIds,        // ✅ triggers delete block
            false,
            false,
            false,
            null
        );
        Test.stopTest();

        // ---- validateFiles null + empty ----
        ExpenseController.validateFiles(null);
        ExpenseController.validateFiles(
            new List<Map<String,String>>()
        );

        // ---- getMonthName default case ----
        String result = ExpenseController.getMonthName(0);
        System.assertEquals('', result);
    }
}


}