@isTest
private class ExpenseApprovalControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test users with different profiles
        Profile systemAdminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        Profile standardUserProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        // Create L1 Approver
        User l1Approver = new User(
            Alias = 'l1appr',
            Email = 'l1approver@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'L1Approver',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardUserProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'l1approver@testorg.com.testclass'
        );
        
        // Create L2 Approver
        User l2Approver = new User(
            Alias = 'l2appr',
            Email = 'l2approver@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'L2Approver',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardUserProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'l2approver@testorg.com.testclass'
        );
        
        // Create Finance Approver
        User financeApprover = new User(
            Alias = 'finappr',
            Email = 'finance@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'FinanceApprover',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardUserProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'financeapprover@testorg.com.testclass'
        );
        
        // Create Expense Owner
        User expenseOwner = new User(
            Alias = 'owner',
            Email = 'owner@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'ExpenseOwner',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardUserProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'expenseowner@testorg.com.testclass'
        );
        
        insert new List<User>{l1Approver, l2Approver, financeApprover, expenseOwner};
        
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // Create Travel Eligibility
            Travel_Eligibility__c eligibility = new Travel_Eligibility__c(
                Eligibility_For__c='Profile',
                Profile__c = 'System Administrator',
                Conveyance_Allowance_per_KM_Bike__c = 10,
                Conveyance_Allowance_per_KM_Own_Car__c = 15,
                Monthly_limit_Auto__c = 5000,
                Monthly_limit_Bike__c = 3000,
                Monthly_Limit_Car__c = 10000,
                Travel_Mode_HQ__c = 'Car;Bike;Autorishaw',
                Travel_Mode_UC__c = 'Car;Bike;Autorishaw'
            );
            insert eligibility;
            
            // Create Expense record
            Expense__c expense = new Expense__c(
                Name = 'Test Expense',
                OwnerId = expenseOwner.Id,
                Expense_Approver_L1__c = l1Approver.Id,
                Expense_Approver_L2__c = l2Approver.Id,
                Expense_Finance_Department_Approver__c = financeApprover.Id
        
            );
            insert expense;
            
            // Create Expense Line Items
            List<Expenses_Line_Item__c> lineItems = new List<Expenses_Line_Item__c>();
            
            lineItems.add(new Expenses_Line_Item__c(
                Expense__c = expense.Id,
                Approval_Status__c = 'Pending',
                Expense_Date__c = Date.today().addDays(-10),
                Expense_Type__c = 'TA',
                Travel_Mode__c = 'Car',
                City_Name__c = 'Test City',
                TA_Limit__c = 100,
                Submitted_Amount__c = 80,
                Total_KM__c = 80,
                Calculated_KM__c = 70,
                Total_Distance_Calculated_by_ODM_Reading__c = 75,
                System_Calculated_Amount__c = 1200,
                Amount__c = 1000,
                Remarks__c = 'Test TA Car'
            ));
            
            lineItems.add(new Expenses_Line_Item__c(
                Expense__c = expense.Id,
                Approval_Status__c = 'Level 1 Approved',
                Expense_Date__c = Date.today().addDays(-5),
                Expense_Type__c = 'TA',
                Travel_Mode__c = 'Bike',
                City_Name__c = 'Test City',
                TA_Limit__c = 50,
                Submitted_Amount__c = 60,
                Total_KM__c = 60,
                Calculated_KM__c = 40,
                Total_Distance_Calculated_by_ODM_Reading__c = 50,
                System_Calculated_Amount__c = 800,
                Amount__c = 900,
                Remarks__c = 'Test TA Bike'
            ));
            
            lineItems.add(new Expenses_Line_Item__c(
                Expense__c = expense.Id,
                Approval_Status__c = 'Pending',
                Expense_Date__c = Date.today().addDays(-3),
                Expense_Type__c = 'DA',
                City_Name__c = 'Test City',
                DA_Limit__c = 1000,
                Submitted_Amount__c = 800,
                System_Calculated_Amount__c = 800,
                Amount__c = 800,
                Remarks__c = 'Test DA'
            ));
            
            lineItems.add(new Expenses_Line_Item__c(
                Expense__c = expense.Id,
                Approval_Status__c = 'Pending',
                Expense_Date__c = Date.today().addDays(-1),
                Expense_Type__c = 'Accommodation',
                City_Name__c = 'Test City',
                lodging_Limit__c = 2000,
                Submitted_Amount__c = 2500,
                System_Calculated_Amount__c = 2500,
                Amount__c = 2500,
                Remarks__c = 'Test Accommodation'
            ));
            
            insert lineItems;
        }
    }
    
    @isTest
    static void testGetExpenseLineItemsAsOwner() {
        User expenseOwner = [SELECT Id FROM User WHERE UserName = 'expenseowner@testorg.com.testclass' LIMIT 1];
        
        System.runAs(expenseOwner) {
            Expense__c expense = [SELECT Id FROM Expense__c LIMIT 1];
            
            Test.startTest();
            ExpenseApprovalController controller = ExpenseApprovalController.getExpenseLineItems(expense.Id);
            Test.stopTest();
        }
    }
    
    @isTest
    static void testGetExpenseLineItemsAsL1Approver() {
        User l1Approver = [SELECT Id FROM User WHERE UserName = 'l1approver@testorg.com.testclass' LIMIT 1];
        

            Expense__c expense = [SELECT Id FROM Expense__c LIMIT 1];
            
            Test.startTest();
            ExpenseApprovalController controller = ExpenseApprovalController.getExpenseLineItems(expense.Id);
            Test.stopTest();
        
    }
    
    @isTest
    static void testGetExpenseLineItemsAsFinanceApprover() {
        User financeApprover = [SELECT Id FROM User WHERE UserName = 'financeapprover@testorg.com.testclass' LIMIT 1];
        
            Expense__c expense = [SELECT Id FROM Expense__c LIMIT 1];
            
            Test.startTest();
            ExpenseApprovalController controller = ExpenseApprovalController.getExpenseLineItems(expense.Id);
            Test.stopTest();
        
    }
    
    @isTest
    static void testGetExpenseLineItemsAsSystemAdmin() {
        User adminUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];
        
        System.runAs(adminUser) {
            Expense__c expense = [SELECT Id FROM Expense__c LIMIT 1];
            
            Test.startTest();
            ExpenseApprovalController controller = ExpenseApprovalController.getExpenseLineItems(expense.Id);
            Test.stopTest();
        }
    }
    
    @isTest
    static void testGetExpenseDetailsAsOwner() {
        User expenseOwner = [SELECT Id FROM User WHERE UserName = 'expenseowner@testorg.com.testclass' LIMIT 1];
        
        System.runAs(expenseOwner) {
            Expense__c expense = [SELECT Id FROM Expense__c LIMIT 1];
            
            Test.startTest();
            ExpenseApprovalController.DataBox dataBox = ExpenseApprovalController.getExpenseDetails(expense.Id);
            Test.stopTest();
        }
    }
    
    @isTest
    static void testGetExpenseDetailsAsApprover() {
        User l1Approver = [SELECT Id FROM User WHERE UserName = 'l1approver@testorg.com.testclass' LIMIT 1];
        
        
            Expense__c expense = [SELECT Id FROM Expense__c LIMIT 1];
            
            Test.startTest();
            ExpenseApprovalController.DataBox dataBox = ExpenseApprovalController.getExpenseDetails(expense.Id);
            Test.stopTest();
        
    }
    
    @isTest
    static void testGetExpenseDetailsAsSystemAdmin() {
        User adminUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];
        
        System.runAs(adminUser) {
            Expense__c expense = [SELECT Id FROM Expense__c LIMIT 1];
            
            Test.startTest();
            ExpenseApprovalController.DataBox dataBox = ExpenseApprovalController.getExpenseDetails(expense.Id);
            Test.stopTest();
        }
    }
    
    @isTest
    static void testUpdateExpenseLineItems() {
        User expenseOwner = [SELECT Id FROM User WHERE UserName = 'expenseowner@testorg.com.testclass' LIMIT 1];
        
        System.runAs(expenseOwner) {
            List<Expenses_Line_Item__c> lineItems = [SELECT Id, Submitted_Amount__c FROM Expenses_Line_Item__c LIMIT 2];
            
            for (Expenses_Line_Item__c item : lineItems) {
                item.Submitted_Amount__c = item.Submitted_Amount__c + 100;
            }
            
            Test.startTest();
            ExpenseApprovalController.updateExpenseLineItems(lineItems);
            Test.stopTest();
        }
    }
    
  
    
   
    
    @isTest
    static void testApproveExpenseItemsAsSystemAdmin() {
        User adminUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];
        
        System.runAs(adminUser) {
            Expense__c expense = [SELECT Id FROM Expense__c LIMIT 1];
            List<Expenses_Line_Item__c> pendingItems = [
                SELECT Id FROM Expenses_Line_Item__c 
                WHERE Expense__c = :expense.Id
                LIMIT 2
            ];
            
            List<Id> itemIds = new List<Id>();
            for (Expenses_Line_Item__c item : pendingItems) {
                itemIds.add(item.Id);
            }
            
            Test.startTest();
            ExpenseApprovalController.approveExpenseItems(itemIds, expense.Id, 'Test approval comments from Admin');
            Test.stopTest();
        }
    }
    
    @isTest
    static void testRejectExpensesAsL1Approver() {
        User l1Approver = [SELECT Id FROM User WHERE UserName = 'l1approver@testorg.com.testclass' LIMIT 1];
        
            Expense__c expense = [SELECT Id FROM Expense__c LIMIT 1];
            List<Expenses_Line_Item__c> pendingItems = [
                SELECT Id FROM Expenses_Line_Item__c 
                WHERE Expense__c = :expense.Id AND Approval_Status__c = 'Pending'
                LIMIT 2
            ];
            
            List<Id> itemIds = new List<Id>();
            for (Expenses_Line_Item__c item : pendingItems) {
                itemIds.add(item.Id);
            }
            
            Test.startTest();
            ExpenseApprovalController.rejectExpenses(itemIds, expense.Id, 'Test rejection comments from L1 approver');
            Test.stopTest();
        
    }
    
    @isTest
    static void testRejectExpensesAsFinanceApprover() {
        User financeApprover = [SELECT Id FROM User WHERE UserName = 'financeapprover@testorg.com.testclass' LIMIT 1];

            Expense__c expense = [SELECT Id FROM Expense__c LIMIT 1];
            List<Expenses_Line_Item__c> approvedItems = [
                SELECT Id FROM Expenses_Line_Item__c 
                WHERE Expense__c = :expense.Id AND Approval_Status__c = 'Level 1 Approved'
                LIMIT 2
            ];
            
            List<Id> itemIds = new List<Id>();
            for (Expenses_Line_Item__c item : approvedItems) {
                itemIds.add(item.Id);
            }
            
            Test.startTest();
            ExpenseApprovalController.rejectExpenses(itemIds, expense.Id, 'Test rejection comments from Finance');
            Test.stopTest();
        
    }
    
    @isTest
    static void testRejectExpensesAsSystemAdmin() {
        User adminUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];
        
        System.runAs(adminUser) {
            Expense__c expense = [SELECT Id FROM Expense__c LIMIT 1];
            List<Expenses_Line_Item__c> pendingItems = [
                SELECT Id FROM Expenses_Line_Item__c 
                WHERE Expense__c = :expense.Id
                LIMIT 2
            ];
            
            List<Id> itemIds = new List<Id>();
            for (Expenses_Line_Item__c item : pendingItems) {
                itemIds.add(item.Id);
            }
            
            Test.startTest();
            ExpenseApprovalController.rejectExpenses(itemIds, expense.Id, 'Test rejection comments from Admin');
            Test.stopTest();
        }
    }
    
    @isTest
    static void testRejectExpenses1() {
        User adminUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];
        
        System.runAs(adminUser) {
            Expense__c expense = [SELECT Id FROM Expense__c LIMIT 1];
            List<Expenses_Line_Item__c> items = [
                SELECT Id FROM Expenses_Line_Item__c 
                WHERE Expense__c = :expense.Id
                LIMIT 2
            ];
            
            List<Id> itemIds = new List<Id>();
            for (Expenses_Line_Item__c item : items) {
                itemIds.add(item.Id);
            }
            
            Test.startTest();
            ExpenseApprovalController.rejectExpenses1(itemIds, expense.Id, 'Test rejectExpenses1 method');
            Test.stopTest();
        }
    }
    
    @isTest
    static void testGetExpenseLineItemsWithEmptyExpenseId() {
        Test.startTest();
        try {
            ExpenseApprovalController.getExpenseLineItems(null);
        } catch (Exception e) {
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetExpenseDetailsWithEmptyExpenseId() {
        Test.startTest();
        try {
            ExpenseApprovalController.getExpenseDetails(null);
        } catch (Exception e) {
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateExpenseLineItemsWithEmptyList() {
        Test.startTest();
        try {
            ExpenseApprovalController.updateExpenseLineItems(new List<Expenses_Line_Item__c>());
        } catch (Exception e) {
        }
        Test.stopTest();
    }
    
    @isTest
    static void testApproveExpenseItemsWithEmptyLists() {
        Test.startTest();
        try {
            ExpenseApprovalController.approveExpenseItems(new List<Id>(), null, null);
        } catch (Exception e) {
        }
        Test.stopTest();
    }
    
    @isTest
    static void testRejectExpensesWithEmptyLists() {
        Test.startTest();
        try {
            ExpenseApprovalController.rejectExpenses(new List<Id>(), null, null);
        } catch (Exception e) {
        }
        Test.stopTest();
    }
    
    @isTest
    static void testRejectExpenses1WithEmptyLists() {
        Test.startTest();
        try {
            ExpenseApprovalController.rejectExpenses1(new List<Id>(), null, null);
        } catch (Exception e) {
        }
        Test.stopTest();
    }
}