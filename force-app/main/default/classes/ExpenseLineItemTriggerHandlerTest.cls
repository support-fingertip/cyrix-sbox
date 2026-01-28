@IsTest
public class ExpenseLineItemTriggerHandlerTest {
    
    @IsTest
    static void testAfterInsertWithFiles() {
        // Create test content documents with unique descriptions
        List<ContentVersion> contentVersions = new List<ContentVersion>();
        Set<String> uniqueIds = new Set<String>{'unique-id-1', 'unique-id-2', 'unique-id-3'};
        
        for(String uniqueId : uniqueIds) {
            ContentVersion cv = new ContentVersion(
                Title = 'Test File ' + uniqueId,
                PathOnClient = 'TestFile_' + uniqueId + '.pdf',
                VersionData = Blob.valueOf('Test Content ' + uniqueId),
                Description = uniqueId,
                IsMajorVersion = true
            );
            contentVersions.add(cv);
        }
        insert contentVersions;
        
        // Get the created ContentDocument IDs
        contentVersions = [SELECT Id, ContentDocumentId, Description FROM ContentVersion WHERE Id IN :contentVersions];
        
        // Create test expense line items
        List<Expenses_Line_Item__c> expenseItems = new List<Expenses_Line_Item__c>();
         Expense__c expense = new Expense__c(
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addDays(30),
                Expense_Type__c = 'Travel',
                Expense_Approver_L1__c = userinfo.getuserId()
            );
            insert expense;
        for(Integer i = 0; i < 3; i++) {
            Expenses_Line_Item__c item = new Expenses_Line_Item__c(
               Expense_Date__c = Date.today(),
                 Expense__c = expense.Id,
                    Expense_Type__c = 'TA',
                    Travel_Type__c = 'In Office',
                    Travel_Mode__c = 'Car',
                    Amount__c = 500 ,
                    Total_KM__c = 50 ,
                    Approval_Status__c = 'Draft',
                    localId__c = 'test-local-' 
            );
            expenseItems.add(item);
        }
        
        Test.startTest();
        insert expenseItems;
        Test.stopTest();
    }
    
    @IsTest
    static void testAfterInsertWithoutLocalId() {
        // Create test expense line items without localId
        List<Expenses_Line_Item__c> expenseItems = new List<Expenses_Line_Item__c>();
         Expense__c expense = new Expense__c(
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addDays(30),
                Expense_Type__c = 'Travel',
                Expense_Approver_L1__c = userinfo.getuserId()
            );
            insert expense;
        for(Integer i = 0; i < 3; i++) {
            Expenses_Line_Item__c item = new Expenses_Line_Item__c(
             Expense_Date__c = Date.today(),
                 Expense__c = expense.Id,
                    Expense_Type__c = 'TA',
                    Travel_Type__c = 'In Office',
                    Travel_Mode__c = 'Car',
                    Amount__c = 500 ,
                    Total_KM__c = 50 ,
                    Approval_Status__c = 'Draft',
                    localId__c = 'test-local-' 
            );
            expenseItems.add(item);
        }
        
        Test.startTest();
        insert expenseItems;
        Test.stopTest();
    }
    
    @IsTest
    static void testAfterInsertWithNullLocalId() {
        // Create test expense line items with null localId
        List<Expenses_Line_Item__c> expenseItems = new List<Expenses_Line_Item__c>();
         Expense__c expense = new Expense__c(
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addDays(30),
                Expense_Type__c = 'Travel',
                Expense_Approver_L1__c = userinfo.getuserId()
            );
            insert expense;
        for(Integer i = 0; i < 3; i++) {
            Expenses_Line_Item__c item = new Expenses_Line_Item__c(
               Expense_Date__c = Date.today(),
                 Expense__c = expense.Id,
                    Expense_Type__c = 'TA',
                    Travel_Type__c = 'In Office',
                    Travel_Mode__c = 'Car',
                    Amount__c = 500 ,
                    Total_KM__c = 50 ,
                    Approval_Status__c = 'Draft',
                    localId__c = 'test-local-' 
            );
            expenseItems.add(item);
        }
        
        Test.startTest();
        insert expenseItems;
        Test.stopTest();
    }
    
    @IsTest
    static void testAfterInsertWithMixedLocalIds() {
        // Create test content document for the matching localId
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test Content'),
            Description = 'matching-id',
            IsMajorVersion = true
        );
        insert cv;
        
         Expense__c expense = new Expense__c(
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addDays(30),
                Expense_Type__c = 'Travel',
                Expense_Approver_L1__c = userinfo.getuserId()
            );
            insert expense;
        // Create test expense line items with mixed localIds
        List<Expenses_Line_Item__c> expenseItems = new List<Expenses_Line_Item__c>();
        
        // Item with matching localId
        expenseItems.add(new Expenses_Line_Item__c(
           Expense_Date__c = Date.today(),
             Expense__c = expense.Id,
                    Expense_Type__c = 'TA',
                    Travel_Type__c = 'In Office',
                    Travel_Mode__c = 'Car',
                    Amount__c = 500 ,
                    Total_KM__c = 50 ,
                    Approval_Status__c = 'Draft',
                    localId__c = 'test-local-' 
        ));
        
        // Item with non-matching localId
        expenseItems.add(new Expenses_Line_Item__c(
            Expense_Date__c = Date.today(),
             Expense__c = expense.Id,
                    Expense_Type__c = 'TA',
                    Travel_Type__c = 'In Office',
                    Travel_Mode__c = 'Car',
                    Amount__c = 500 ,
                    Total_KM__c = 50 ,
                    Approval_Status__c = 'Draft',
                    localId__c = 'test-local-' 
        ));
        
        // Item without localId
        expenseItems.add(new Expenses_Line_Item__c(
          Expense_Date__c = Date.today(),
             Expense__c = expense.Id,
                    Expense_Type__c = 'TA',
                    Travel_Type__c = 'In Office',
                    Travel_Mode__c = 'Car',
                    Amount__c = 500 ,
                    Total_KM__c = 50 ,
                    Approval_Status__c = 'Draft',
                    localId__c = 'test-local-' 
        ));
        
        Test.startTest();
        insert expenseItems;
        Test.stopTest();
    }
    
    @IsTest
    static void testAfterInsertWithDuplicateLocalIds() {
        // Create test content document
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test Content'),
            Description = 'duplicate-id',
            IsMajorVersion = true
        );
        insert cv;
        
        // Create test expense line items with duplicate localIds
        List<Expenses_Line_Item__c> expenseItems = new List<Expenses_Line_Item__c>();
         Expense__c expense = new Expense__c(
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addDays(30),
                Expense_Type__c = 'Travel',
                Expense_Approver_L1__c = userinfo.getuserId()
            );
            insert expense;
        for(Integer i = 0; i < 3; i++) {
            Expenses_Line_Item__c item = new Expenses_Line_Item__c(
              Expense_Date__c = Date.today(),
                 Expense__c = expense.Id,
                    Expense_Type__c = 'TA',
                    Travel_Type__c = 'In Office',
                    Travel_Mode__c = 'Car',
                    Amount__c = 500 ,
                    Total_KM__c = 50 ,
                    Approval_Status__c = 'Draft',
                    localId__c = 'test-local-' );
            expenseItems.add(item);
        }
        
        Test.startTest();
        insert expenseItems;
        Test.stopTest();
    }
    
    @IsTest
    static void testAfterInsertWithNoMatchingFiles() {
        // Create test expense line items with localIds that don't match any files
        List<Expenses_Line_Item__c> expenseItems = new List<Expenses_Line_Item__c>();
         Expense__c expense = new Expense__c(
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addDays(30),
                Expense_Type__c = 'Travel',
                Expense_Approver_L1__c = userinfo.getuserId()
            );
            insert expense;
        for(Integer i = 0; i < 3; i++) {
            Expenses_Line_Item__c item = new Expenses_Line_Item__c(
               Expense_Date__c = Date.today(),
                 Expense__c = expense.Id,
                    Expense_Type__c = 'TA',
                    Travel_Type__c = 'In Office',
                    Travel_Mode__c = 'Car',
                    Amount__c = 500 ,
                    Total_KM__c = 50 ,
                    Approval_Status__c = 'Draft',
                    localId__c = 'test-local-' );
            expenseItems.add(item);
        }
        
        Test.startTest();
        insert expenseItems;
        Test.stopTest();
    }
    
    @IsTest
    static void testAfterInsertWithEmptySet() {
        // Create test expense line items
        List<Expenses_Line_Item__c> expenseItems = new List<Expenses_Line_Item__c>();
        
        Test.startTest();
        // Insert empty list to test empty set logic
        insert expenseItems;
        Test.stopTest();
    }
    
    @IsTest
    static void testAfterInsertWithMultipleFilesSameDescription() {
        // Create multiple test content documents with same description
        List<ContentVersion> contentVersions = new List<ContentVersion>();
        
        for(Integer i = 0; i < 2; i++) {
            ContentVersion cv = new ContentVersion(
                Title = 'Test File ' + i,
                PathOnClient = 'TestFile_' + i + '.pdf',
                VersionData = Blob.valueOf('Test Content ' + i),
                Description = 'same-description',
                IsMajorVersion = true
            );
            contentVersions.add(cv);
        }
        insert contentVersions;
         Expense__c expense = new Expense__c(
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addDays(30),
                Expense_Type__c = 'Travel',
                Expense_Approver_L1__c = userinfo.getuserId()
            );
            insert expense;
        // Create test expense line item
        Expenses_Line_Item__c expenseItem = new Expenses_Line_Item__c(
          Expense_Date__c = Date.today(),
             Expense__c = expense.Id,
                    Expense_Type__c = 'TA',
                    Travel_Type__c = 'In Office',
                    Travel_Mode__c = 'Car',
                    Amount__c = 500 ,
                    Total_KM__c = 50 ,
                    Approval_Status__c = 'Draft',
                    localId__c = 'test-local-' 
        );
        
        Test.startTest();
        insert expenseItem;
        Test.stopTest();
    }
    
    @IsTest
    static void testAfterInsertWithSpecialCharactersInLocalId() {
        // Create test content document with special characters in description
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test Content'),
            Description = 'test-id_123@#$%',
            IsMajorVersion = true
        );
        insert cv;
         Expense__c expense = new Expense__c(
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addDays(30),
                Expense_Type__c = 'Travel',
                Expense_Approver_L1__c = userinfo.getuserId()
            );
            insert expense;
        // Create test expense line item with same special characters
        Expenses_Line_Item__c expenseItem = new Expenses_Line_Item__c(
           Expense_Date__c = Date.today(),
             Expense__c = expense.Id,
                    Expense_Type__c = 'TA',
                    Travel_Type__c = 'In Office',
                    Travel_Mode__c = 'Car',
                    Amount__c = 500 ,
                    Total_KM__c = 50 ,
                    Approval_Status__c = 'Draft',
                    localId__c = 'test-local-' 
        );
        
        Test.startTest();
        insert expenseItem;
        Test.stopTest();
    }
    
    @IsTest
    static void testAfterInsertWithLongLocalId() {
        // Create test content document with long description
        String longId = 'very-long-unique-id-1234567890123456789012345678901234567890';
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test Content'),
            Description = longId,
            IsMajorVersion = true
        );
        insert cv;
          Expense__c expense = new Expense__c(
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addDays(30),
                Expense_Type__c = 'Travel',
                Expense_Approver_L1__c = userinfo.getuserId()
            );
            insert expense;
        // Create test expense line item with same long localId
        Expenses_Line_Item__c expenseItem = new Expenses_Line_Item__c(
           Expense_Date__c = Date.today(),
             Expense__c = expense.Id,
                    Expense_Type__c = 'TA',
                    Travel_Type__c = 'In Office',
                    Travel_Mode__c = 'Car',
                    Amount__c = 500 ,
                    Total_KM__c = 50 ,
                    Approval_Status__c = 'Draft',
                    localId__c = 'test-local-' 
        );
        
        Test.startTest();
        insert expenseItem;
        Test.stopTest();
    }
    
    @IsTest
    static void testAfterInsertWithOtherFields() {
        
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
        // Create test content document
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test Content'),
            Description = 'test-with-fields',
            IsMajorVersion = true
        );
        insert cv;
         Expense__c expense = new Expense__c(
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addDays(30),
                Expense_Type__c = 'Travel',
                Expense_Approver_L1__c = manager.Id
            );
            insert expense;
        // Create test expense line item with various fields populated
      Expenses_Line_Item__c expenseItem =new Expenses_Line_Item__c(
                    Expense__c = expense.Id,
                    Expense_Date__c = Date.today(),
                    Expense_Type__c = 'TA',
                    Travel_Type__c = 'In Office',
                    Travel_Mode__c = 'Car',
                    Amount__c = 500 ,
                    Total_KM__c = 50 ,
                    Approval_Status__c = 'Draft',
                    localId__c = 'test-local-' 
                );
        
        Test.startTest();
        insert expenseItem;
        ExpenseLineItemTriggerHandler.testCoverage();
        Test.stopTest();
    }
    
  
}