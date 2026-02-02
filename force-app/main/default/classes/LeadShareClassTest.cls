@isTest
public class LeadShareClassTest {
    
    @TestSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        
        List<User> testUsers = new List<User>();
        for (Integer i = 0; i < 3; i++) {
            User u = new User(
                Alias = 'te',
                Email = 'testuser' + i + '@test.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Test' + i,
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'testuyyr' + i + '@testorg.com'
            );
            testUsers.add(u);
        }
        insert testUsers;
        
        System.runAs(testUsers[0]) {
            List<Lead> leads = new List<Lead>();
            for (Integer i = 0; i < 5; i++) {
                Lead l = new Lead(
                    FirstName = 'Test' + i,
                    LastName = 'Lead' + i,
                    Company = 'Test Company ' + i,
                    Status = 'New',
                    phone='1234567890'
                );
                leads.add(l);
            }
            insert leads;
        }
    }
    

    @isTest
    static void testShareWithCreator_PermissionCheck() {
        Profile lowProfile = [SELECT Id FROM Profile WHERE Name='Read Only' LIMIT 1];
        
        User lowPermUser = new User(
            Alias = 'lowperm',
            Email = 'lowperm@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'LowPerm',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = lowProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'lowperrrm@testorg.com'
        );
        insert lowPermUser;
        
        User creator = [SELECT Id FROM User WHERE UserName LIKE 'testuyyr%' LIMIT 1];
        Lead testLead = [SELECT Id FROM Lead WHERE CreatedById = :creator.Id LIMIT 1];
        
        Test.startTest();
        LeadShareClass.testcover();
        System.runAs(lowPermUser) {
            List<Id> leadIds = new List<Id>{testLead.Id};
            LeadShareClass.shareWithCreator(leadIds);
        }
        Test.stopTest();
        
        // No asserts here
    }
    
    
}