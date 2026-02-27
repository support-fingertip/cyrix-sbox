@IsTest
public class ExpenseControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test user with manager
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User manager = new User(
            Alias = 'manager',
            Email = 'manager@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Manager',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'manager@test.example.com'
        );
        insert manager;
        
        User testUser = new User(
            Alias = 'testusr',
            Email = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'TestUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuser55@test.example.com',
            ManagerId = manager.Id,
     
            Expense_Back_Day_Entry_Limit__c = 7
        );
        insert testUser;
        
           General_Settings__c general = new General_Settings__c(
           
            Campaign_Marketing_Manager_Approver__c = UserInfo.getUserId(),
            Campaign_Final_Approver__c = UserInfo.getUserId(),
            Campaign_Expense_Approver__c = UserInfo.getUserId(),
            Telephony_Campaign_Approver__c = UserInfo.getUserId(),
            Academy_Campaign_Approver__c = UserInfo.getUserId(),
            Sales_Campaign_Approver__c = UserInfo.getUserId(),
            Service_Campaign_Approver__c = UserInfo.getUserId(),
            Marketing_Campaign_Approver__c = UserInfo.getUserId(),
            HR_Campaign_Approver__c = UserInfo.getUserId(),
            Digital_Campaign_Approver__c = UserInfo.getUserId(),
               Expense_Level_1_Approver__c= UserInfo.getUserId(),  
               Expense_Level_2_Approver__c= UserInfo.getUserId()
        );
        insert general;
        // Create Travel Eligibility record
        Travel_Eligibility__c eligibility = new Travel_Eligibility__c(
            Eligibility_For__c = 'Profile',
            Profile__c = 'ASM',
            Conveyance_Allowance_per_KM_Bike__c = 5,
            Conveyance_Allowance_per_KM_Own_Car__c = 10,
            Daily_Allowance_HQ__c = 1000,
            DA_Other_State__c = 1500,
            DA_Other_District__c = 1200,
            Travel_Mode_HQ__c = 'Car;Bike;Autorishaw',
            Travel_Mode_UC__c = 'Car;Bike'
        );
        insert eligibility;
        
        // Create Daily Log records
        List<Daily_Log__c> dailyLogs = new List<Daily_Log__c>();
        for (Integer i = 0; i < 5; i++) {
            dailyLogs.add(new Daily_Log__c(
                Day_started_Time__c = Date.today().addDays(i),
                KMs_Travelled__c = 100 + i,
                Mode_of_transport__c = 'Car'
            ));
        }
        insert dailyLogs;
        
        System.runAs(testUser) {
            // Create Expense record
            Expense__c expense = new Expense__c(
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addDays(30),
                Expense_Type__c = 'Travel',
                Expense_Approver_L1__c = manager.Id
            );
            insert expense;
            
            // Create Expense Line Items
            List<Expenses_Line_Item__c> lineItems = new List<Expenses_Line_Item__c>();
            for (Integer i = 0; i < 3; i++) {
                lineItems.add(new Expenses_Line_Item__c(
                    Expense__c = expense.Id,
                    Expense_Date__c = Date.today().addDays(i),
                    Expense_Type__c = 'TA',
                    Travel_Type__c = 'In Office',
                    Travel_Mode__c = 'Car',
                    Amount__c = 500 + (i * 100),
                    Total_KM__c = 50 + i,
                    Approval_Status__c = 'Draft',
                    localId__c = 'test-local-' + i
                ));
            }
            insert lineItems;
        }
    }
    
    @IsTest
    static void testGetExpensesWithRecordId() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser55@test.example.com' LIMIT 1];
        Expense__c testExpense = [SELECT Id FROM Expense__c  LIMIT 1];
        
        Test.startTest();
        System.runAs(testUser) {
            ExpenseController.ExpenseData result = ExpenseController.getExpenses(testExpense.Id);
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGetExpensesWithoutRecordId() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser55@test.example.com' LIMIT 1];
        
        Test.startTest();
        System.runAs(testUser) {
            ExpenseController.ExpenseData result = ExpenseController.getExpenses(null);
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGetExpensesWithNoExistingExpense() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser55@test.example.com' LIMIT 1];
        // Delete existing expense to test creation path
        delete [SELECT Id FROM Expense__c];
        
        Test.startTest();
        System.runAs(testUser) {
            ExpenseController.ExpenseData result = ExpenseController.getExpenses(null);
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGetPicklistValues() {
        Test.startTest();
        List<String> picklistValues = ExpenseController.getPicklistValues('Expenses_Line_Item__c', 'Travel_Mode__c');
        Test.stopTest();
    }
    
    @IsTest
    static void testValidateFilesWithDocIds() {
        // Create test content
        ContentVersion cv = new ContentVersion(
            Title = 'Test Document',
            PathOnClient = 'TestDocument.pdf',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert cv;
        
        ContentVersion contentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        
        Expense__c testExpense = [SELECT Id FROM Expense__c LIMIT 1];
        
        // Link document to expense
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = testExpense.Id,
            ContentDocumentId = contentVersion.ContentDocumentId,
            ShareType = 'V'
        );
        insert cdl;
        
        List<Map<String, String>> itemsToCheck = new List<Map<String, String>>{
            new Map<String, String>{
                'uniqueKey' => 'test1',
                    'Id' => testExpense.Id
                    }
        };
        
        Test.startTest();
        Map<String, Boolean> results = ExpenseController.validateFiles(itemsToCheck);
        Test.stopTest();
    }
    
    @IsTest
    static void testValidateFilesWithLocalIds() {
        ContentVersion cv = new ContentVersion(
            Title = 'Test Document',
            PathOnClient = 'TestDocument.pdf',
            VersionData = Blob.valueOf('Test Content'),
            Description = 'test-local-0',
            IsMajorVersion = true
        );
        insert cv;
        
        List<Map<String, String>> itemsToCheck = new List<Map<String, String>>{
            new Map<String, String>{
                'uniqueKey' => 'test2',
                    'localId__c' => 'test-local-0'
                    }
        };
        
        Test.startTest();
        Map<String, Boolean> results = ExpenseController.validateFiles(itemsToCheck);
        Test.stopTest();
    }
    
    @IsTest
    static void testValidateFilesEmptyList() {
        Test.startTest();
        Map<String, Boolean> results = ExpenseController.validateFiles(new List<Map<String, String>>());
        Test.stopTest();
    }
    
    @IsTest
    static void testSaveExpenseCreateNew() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser55@test.example.com' LIMIT 1];
        
        System.runAs(testUser) {
            // Delete existing expense to test creation
            delete [SELECT Id FROM Expense__c];
            
            Expense__c newExpense = new Expense__c(
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addDays(30)
            );
            
            List<Expenses_Line_Item__c> lineItems = new List<Expenses_Line_Item__c>{
                new Expenses_Line_Item__c(
                    localId__c = 'new-item-1',
                    Expense_Date__c = Date.today(),
                    Expense_Type__c = 'TA',
                    Travel_Type__c = 'In Office',
                    Travel_Mode__c = 'Car',
                    Amount__c = 1000,
                    Approval_Status__c = 'Draft',
                    Is_Updated__c = true
                )
            };
            
            Test.startTest();
            ExpenseController.ExpenseData result = ExpenseController.saveExpense(
                newExpense, 
                lineItems, 
                new List<String>(), 
                false, 
                false, 
                false,
                ''
            );
            Test.stopTest();
        }
    }
    
    @IsTest
    static void testSaveExpenseUpdateExisting() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser55@test.example.com' LIMIT 1];
        Expense__c existingExpense = [SELECT Id, Name FROM Expense__c LIMIT 1];
         List<Expenses_Line_Item__c> existingItems = [SELECT Id,Food_Type__c,Approval_Status__c,System_Calculated_Amount__c,Local_Conveyance_Limit__c,lodging_Limit__c,Calculated_KM__c,Amount__c,Remarks__c, DA_Limit__c,Total_Distance_Calculated_by_ODM_Reading__c,Total_KM__c,TA_Limit__c,Working_Hours__c,Daily_Log__c,Accommodation_Type__c,Travel_Mode__c,Expense_Type__c,Is_Updated__c,localId__c,Expense_Date__c,Travel_Type__c FROM Expenses_Line_Item__c];
        
        System.runAs(testUser) {
            List<Expenses_Line_Item__c> updatedItems = new List<Expenses_Line_Item__c>();
            for (Expenses_Line_Item__c item : existingItems) {
                item.Amount__c = 600;
                item.Is_Updated__c = true;
                updatedItems.add(item);
            }
            
            Test.startTest();
            ExpenseController.ExpenseData result = ExpenseController.saveExpense(
                existingExpense, 
                updatedItems, 
                new List<String>(), 
                false, 
                false, 
                false,
                ''
            );
            Test.stopTest();
        }
    }
    
    @IsTest
    static void testSaveExpenseWithDelete() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser55@test.example.com' LIMIT 1];
        Expense__c existingExpense = [SELECT Id, Name FROM Expense__c LIMIT 1];
        List<Expenses_Line_Item__c> existingItems = [SELECT Id FROM Expenses_Line_Item__c];
        
        System.runAs(testUser) {
            List<String> itemsToDelete = new List<String>{existingItems[0].Id};
                
                Test.startTest();
            ExpenseController.ExpenseData result = ExpenseController.saveExpense(
                existingExpense, 
                new List<Expenses_Line_Item__c>(), 
                itemsToDelete, 
                false, 
                false, 
                false,
                ''
            );
            Test.stopTest();
        }
    }
    
    @IsTest
    static void testSaveExpenseSubmitForApproval() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser55@test.example.com' LIMIT 1];
        Expense__c existingExpense = [SELECT Id, Name FROM Expense__c LIMIT 1];
        List<Expenses_Line_Item__c> existingItems = [SELECT Id,Food_Type__c,Approval_Status__c,System_Calculated_Amount__c,Local_Conveyance_Limit__c,lodging_Limit__c,Calculated_KM__c,Amount__c,Remarks__c, DA_Limit__c,Total_Distance_Calculated_by_ODM_Reading__c,Total_KM__c,TA_Limit__c,Working_Hours__c,Daily_Log__c,Accommodation_Type__c,Travel_Mode__c,Expense_Type__c,Is_Updated__c,localId__c,Expense_Date__c,Travel_Type__c FROM Expenses_Line_Item__c];
          
        System.runAs(testUser) {
            List<Expenses_Line_Item__c> updatedItems = new List<Expenses_Line_Item__c>();
            for (Expenses_Line_Item__c item : existingItems) {
                item.Approval_Status__c = 'Pending';
                item.Is_Updated__c = true;
                updatedItems.add(item);
            }
            
            Test.startTest();
            ExpenseController.ExpenseData result = ExpenseController.saveExpense(
                existingExpense, 
                updatedItems, 
                new List<String>(), 
                true, 
                false, 
                false,
                'Please approve'
            );
            Test.stopTest();
        }
    }
    
    @IsTest
    static void testSaveExpenseApproveRecord() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser55@test.example.com' LIMIT 1];
        Expense__c existingExpense = [SELECT Id, Name FROM Expense__c LIMIT 1];
        List<Expenses_Line_Item__c> existingItems = [SELECT Id,Food_Type__c,Approval_Status__c,System_Calculated_Amount__c,Local_Conveyance_Limit__c,lodging_Limit__c,Calculated_KM__c,Amount__c,Remarks__c, DA_Limit__c,Total_Distance_Calculated_by_ODM_Reading__c,Total_KM__c,TA_Limit__c,Working_Hours__c,Daily_Log__c,Accommodation_Type__c,Travel_Mode__c,Expense_Type__c,Is_Updated__c,localId__c,Expense_Date__c,Travel_Type__c FROM Expenses_Line_Item__c];
        
        System.runAs(testUser) {
            Test.startTest();
            ExpenseController.ExpenseData result = ExpenseController.saveExpense(
                existingExpense, 
                existingItems, 
                new List<String>(), 
                false, 
                true, 
                false,
                'Approved'
            );
            Test.stopTest();
        }
    }
    
    @IsTest
    static void testSaveExpenseRejectRecord() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser55@test.example.com' LIMIT 1];
        Expense__c existingExpense = [SELECT Id, Name FROM Expense__c LIMIT 1];
         List<Expenses_Line_Item__c> existingItems = [SELECT Id,Food_Type__c,Approval_Status__c,System_Calculated_Amount__c,Local_Conveyance_Limit__c,lodging_Limit__c,Calculated_KM__c,Amount__c,Remarks__c, DA_Limit__c,Total_Distance_Calculated_by_ODM_Reading__c,Total_KM__c,TA_Limit__c,Working_Hours__c,Daily_Log__c,Accommodation_Type__c,Travel_Mode__c,Expense_Type__c,Is_Updated__c,localId__c,Expense_Date__c,Travel_Type__c FROM Expenses_Line_Item__c];
        
        System.runAs(testUser) {
            Test.startTest();
            ExpenseController.ExpenseData result = ExpenseController.saveExpense(
                existingExpense, 
                existingItems, 
                new List<String>(), 
                false, 
                false, 
                true,
                'Rejected: Missing details'
            );
            Test.stopTest();
        }
    }
    
    @IsTest
    static void testSaveExpenseWithNullExpense() {
        Test.startTest();
        ExpenseController.ExpenseData result = ExpenseController.saveExpense(
            null, 
            new List<Expenses_Line_Item__c>(), 
            new List<String>(), 
            false, 
            false, 
            false,
            ''
        );
        Test.stopTest();
    }
    
    @IsTest
    static void testGetMonthName() {
        Test.startTest();
        String jan = ExpenseController.getMonthName(1);
        String feb = ExpenseController.getMonthName(2);
        String mar = ExpenseController.getMonthName(3);
        String apr = ExpenseController.getMonthName(4);
        String may = ExpenseController.getMonthName(5);
        String jun = ExpenseController.getMonthName(6);
        String jul = ExpenseController.getMonthName(7);
        String aug = ExpenseController.getMonthName(8);
        String sep = ExpenseController.getMonthName(9);
        String oct = ExpenseController.getMonthName(10);
        String nov = ExpenseController.getMonthName(11);
        String dec = ExpenseController.getMonthName(12);
        Test.stopTest();
    }
    
    @IsTest
    static void testSkipHeavyLogicFlag() {
        Test.startTest();
        ExpenseController.skipHeavyLogic = true;
        Boolean flag = ExpenseController.skipHeavyLogic;
        Test.stopTest();
    }
    
    @IsTest
    static void testExpenseDataInnerClass() {
        Test.startTest();
        ExpenseController.ExpenseData data = new ExpenseController.ExpenseData();
        data.LoggedInUser = new User(FirstName = 'Test', LastName = 'User');
        data.selectedUser = new User(FirstName = 'Selected', LastName = 'User');
        data.expense = new Expense__c(Name = 'Test Expense');
        data.lineItems = new List<Expenses_Line_Item__c>();
        data.days = new List<Daily_Log__c>();
        data.eligibilities = new Travel_Eligibility__c();
        data.travelTypes = new List<String>{'Local', 'Outstation'};
        data.travelModes = new List<String>{'Car', 'Bike'};
        data.expenseTypes = new List<String>{'TA', 'DA'};
        data.accomodationTypes = new List<String>{'Hotel', 'Guest House'};
        data.foodTypes = new List<String>{'Breakfast', 'Lunch'};
        data.approvalStatus = new List<String>{'Draft', 'Pending'};
        data.startDate = Date.today();
        data.endDate = Date.today().addDays(30);
        data.isCurrentUserApprover = true;
        data.approverId = UserInfo.getUserId();
        data.isDistrictInCharge = false;
        data.expenseId = 'test-id';
        data.expenseCommnents = 'Test comments';
        data.isCarEnabled = true;
        data.isBikeEnabled = true;
        data.isAutoEnabled = false;
        Test.stopTest();
    }
}