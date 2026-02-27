@isTest
public class LeadTriggerHandlerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test user
        Profile salesProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'testusr',
            Email = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = salesProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testus4er@test.com'
        );
        insert testUser;
        
        // Create manager user
        User managerUser = new User(
            Alias = 'mgrusr',
            Email = 'manager@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Manager',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = salesProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'manageyyr@test.com'
        );
        insert managerUser;
        
        // Update test user to have manager
        testUser.ManagerId = managerUser.Id;
        update testUser;
        
        // Create campaign
        Campaign testCampaign = new Campaign(
            Name = 'Test Campaign',
            IsActive = true,
            Campaign_Medium__c='Non-Digital',
            Campaign_Source__c='Trade Show'
        );
        insert testCampaign;
        
        // Create existing lead for duplicate testing
        Lead existingLead = new Lead(
            LastName = 'Existing Lead',
            Company = 'Existing Company',
            Email = 'existing@test.com',
            phone='1234567894',
            Status = 'Open'
        );
        insert existingLead;
        update existingLead;
    }
    
    @isTest
    static void testCampaignMapping() {
        Test.startTest();
        
        Campaign camp = [SELECT Id FROM Campaign LIMIT 1];
        
        Lead newLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Campaign__c = camp.Id,
            Status = 'Open',phone='1234567890'
        );
        insert newLead;
        
        LeadTriggerHandler.campaignMapping(new List<Lead>{newLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testCampaignMappingWithoutCampaign() {
        Test.startTest();
        
        Lead newLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = 'Open',
            phone='1234566786'
        );
        insert newLead;
        
        LeadTriggerHandler.campaignMapping(new List<Lead>{newLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testCampaignMappingEmptyList() {
        Test.startTest();
        
        LeadTriggerHandler.campaignMapping(new List<Lead>());
        
        Test.stopTest();
    }
    
    @isTest
    static void testLeadAssignedNotification() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testus4er@test.com' LIMIT 1];
        User managerUser = [SELECT Id FROM User WHERE UserName = 'manageyyr@test.com' LIMIT 1];
        
        Test.startTest();
        
        Lead newLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            OwnerId = testUser.Id,
            Status = 'Open',
            phone='1234567890'
        );
        insert newLead;
        
        LeadTriggerHandler.leadAssignedNotification(new List<Lead>{newLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testLeadAssignedNotificationNoManager() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testus4er@test.com' LIMIT 1];
        
        Test.startTest();
        
        Lead newLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            OwnerId = testUser.Id,
            Status = 'Open',
              phone='1285678906'
        );
        insert newLead;
        
        LeadTriggerHandler.leadAssignedNotification(new List<Lead>{newLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testLeadAssignedNotificationWithSalutation() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testus4er@test.com' LIMIT 1];
        
        Test.startTest();
        
        Lead newLead = new Lead(
            Salutation = 'Mr.',
            FirstName = 'John',
            LastName = 'Doe',
            Company = 'Test Company',
            OwnerId = testUser.Id,
            Status = 'Open',
            phone='1234567895'
        );
        insert newLead;
        
        LeadTriggerHandler.leadAssignedNotification(new List<Lead>{newLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testCheckAndSeprateMobileNumber() {
        Test.startTest();
        
        Lead newLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Phone = '9876543210',
            MobilePhone = '9876543211',
            Status = 'Open'
        );
        
        LeadTriggerHandler.checkAndSeprateMobileNumber(new List<Lead>{newLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testCheckAndSeprateMobileNumberNoPlus91() {
        Test.startTest();
        
        Lead newLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Phone = '9876543210',
            MobilePhone = '9876543211',
            Status = 'Open'
        );
        
        LeadTriggerHandler.checkAndSeprateMobileNumber(new List<Lead>{newLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testCheckAndSeprateMobileNumberNullPhone() {
        Test.startTest();
        
        Lead newLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = 'Open'
        );
        
        LeadTriggerHandler.checkAndSeprateMobileNumber(new List<Lead>{newLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testGetformated() {
        Test.startTest();
        
        String result1 = LeadTriggerHandler.getformated('test');
        String result2 = LeadTriggerHandler.getformated(null);
        
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateLastActivityDate() {
        Test.startTest();
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = 'Open',
            Rating = 'Hot',
            phone='1234567123'
        );
        insert testLead;
        
        testLead.Status = 'Working';
        testLead.Rating = 'Warm';
        testLead.LeadSource = 'Web';
        testLead.Lead_Category__c = 'Premium';
        testLead.GST_Number__c = 'GST123';
        testLead.Company = 'Updated Company';
        
        Map<Id, Lead> oldMap = new Map<Id, Lead>{
            testLead.Id => new Lead(
                Id = testLead.Id,
                Status = 'Open',
                Rating = 'Hot',
                LeadSource = null,
                Lead_Category__c = null,
                GST_Number__c = null,
                Company = 'Test Company'
            )
        };
        
        LeadTriggerHandler.updateLastActivityDate(new List<Lead>{testLead}, oldMap);
        
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateLastActivityDateNoChange() {
        Test.startTest();
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = 'Open',
            phone='1245678906'
        );
        insert testLead;
        
        Map<Id, Lead> oldMap = new Map<Id, Lead>{
            testLead.Id => new Lead(
                Id = testLead.Id,
                Status = 'Open',
                Company = 'Test Company',
                  phone='1245678706'
            )
        };
        
        LeadTriggerHandler.updateLastActivityDate(new List<Lead>{testLead}, oldMap);
        
        Test.stopTest();
    }
    
    @isTest
    static void testSendLostConvertedManagerNotificationLost() {
        User testUser = [SELECT Id, ManagerId FROM User WHERE UserName = 'testus4er@test.com' LIMIT 1];
        
        Test.startTest();
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            OwnerId = testUser.Id,
            Status = 'Open',
              phone='1245678776'
        );
        insert testLead;
        
        testLead.Status = 'Closed Lost';
        testLead.Lost_Reason__c='Features';
        update testLead;
        
        LeadTriggerHandler.sendLostConvertedManagerNotification(new List<Lead>{testLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testSendLostConvertedManagerNotificationConverted() {
        User testUser = [SELECT Id, ManagerId FROM User WHERE UserName = 'testus4er@test.com' LIMIT 1];
        
        Test.startTest();
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            OwnerId = testUser.Id,
            Status = 'Open',
              phone='1245688906'
        );
        insert testLead;
        
        
        LeadTriggerHandler.sendLostConvertedManagerNotification(new List<Lead>{testLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testSendLostConvertedManagerNotificationNoChange() {
        User testUser = [SELECT Id, ManagerId FROM User WHERE UserName = 'testus4er@test.com' LIMIT 1];
        
        Test.startTest();
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            OwnerId = testUser.Id,
            Status = 'Open',
              phone='1245778906'
        );
        
        LeadTriggerHandler.sendLostConvertedManagerNotification(new List<Lead>{testLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testSendLostConvertedManagerNotificationNoManager() {
        User managerUser = [SELECT Id FROM User WHERE UserName = 'manageyyr@test.com' LIMIT 1];
        
        Test.startTest();
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            OwnerId = managerUser.Id,
            Status = 'Closed Lost',
              phone='1945678906'
        );
        
        LeadTriggerHandler.sendLostConvertedManagerNotification(new List<Lead>{testLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testFindDuplicate() {
        Test.startTest();
        
        Lead newLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Email = 'existing@test.com',
            Status = 'Open',
              phone='1945678906'
        );
        
        LeadTriggerHandler.findDuplicate(new List<Lead>{newLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testFindDuplicateNoEmail() {
        Test.startTest();
        
        Lead newLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = 'Open',
              phone='1145678906'
        );
        
        LeadTriggerHandler.findDuplicate(new List<Lead>{newLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testFindDuplicateEmptyList() {
        Test.startTest();
        
        LeadTriggerHandler.findDuplicate(new List<Lead>());
        
        Test.stopTest();
    }
    
    @isTest
    static void testFindDuplicateUniqueEmail() {
        Test.startTest();
        
        Lead newLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Email = 'unique@test.com',
            Status = 'Open',
              phone='1246678906'
        );
        
        LeadTriggerHandler.findDuplicate(new List<Lead>{newLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testSetAccountEmail() {
        Test.startTest();
        
        Account testAccount = new Account(
            Name = 'Test Account',
            phone='1234567891',
            Customer_Category__c='Exporters'
        );
        insert testAccount;
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Email = 'test@test.com',
            Status = 'Open',
              phone='1245578906'
        );
        insert testLead;
        
    
        
        Set<String> accIds = new Set<String>{testAccount.Id};
        LeadTriggerHandler.setAccountEmail(new List<Lead>{testLead}, accIds);
        
        Test.stopTest();
    }
    
    @isTest
    static void testSetAccountEmailNoAccount() {
        Test.startTest();
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Email = 'test@test.com',
            Status = 'Open',
              phone='1265678906'
        );
        
        Set<String> accIds = new Set<String>();
        LeadTriggerHandler.setAccountEmail(new List<Lead>{testLead}, accIds);
        
        Test.stopTest();
    }
    
    @isTest
    static void testSetAccountEmailNoEmail() {
        Test.startTest();
        
        Account testAccount = new Account(
            Name = 'Test Account',
            phone='1245785555',
            Customer_Category__c='Exporters'
        );
        insert testAccount;
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = 'Open',
              phone='1245618906'
        );

        
        Set<String> accIds = new Set<String>{testAccount.Id};
        LeadTriggerHandler.setAccountEmail(new List<Lead>{testLead}, accIds);
        
        Test.stopTest();
    }
    
    @isTest
    static void testCreatefollowupTasks() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testus4er@test.com' LIMIT 1];
        
        Test.startTest();
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            OwnerId = testUser.Id,
            Next_Follow_up_Date__c = Date.today().addDays(7),
            Status = 'Open',
              phone='1241678906'
        );
        
        LeadTriggerHandler.createfollowupTasks(new List<Lead>{testLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testCreatefollowupTasksNoDate() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testus4er@test.com' LIMIT 1];
        
        Test.startTest();
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            OwnerId = testUser.Id,
            Status = 'Open',
              phone='1433678906'
        );
        
        LeadTriggerHandler.createfollowupTasks(new List<Lead>{testLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testCreatefollowupTasksNoOwner() {
        Test.startTest();
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Next_Follow_up_Date__c = Date.today().addDays(7),
            Status = 'Open',
              phone='1267678906'
        );
        
        LeadTriggerHandler.createfollowupTasks(new List<Lead>{testLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testCreatefollowupTasksEmptyList() {
        Test.startTest();
        
        LeadTriggerHandler.createfollowupTasks(new List<Lead>());
        
        Test.stopTest();
    }
}