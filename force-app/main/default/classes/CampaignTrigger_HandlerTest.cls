@isTest
private class CampaignTrigger_HandlerTest {
    
    @testSetup
    static void setupTestData() {
        // Create test users for different roles
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        List<User> testUsers = new List<User>();
        
        // Create approver users
        testUsers.add(new User(
            Alias = 'mmgr',
            Email = 'mmgr@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'MarketingManager',
            FirstName = 'Approver',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'marketing.manager@example.com.test'
        ));
        
        testUsers.add(new User(
            Alias = 'mktg',
            Email = 'mktg@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Marketing',
            FirstName = 'Approver',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'marketing@example.com.test'
        ));
        
        testUsers.add(new User(
            Alias = 'sales',
            Email = 'sales@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Sales',
            FirstName = 'Approver',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'sales@example.com.test'
        ));
        
        testUsers.add(new User(
            Alias = 'service',
            Email = 'service@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Service',
            FirstName = 'Approver',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'service@example.com.test'
        ));
        
        testUsers.add(new User(
            Alias = 'hr',
            Email = 'hr@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'HR',
            FirstName = 'Approver',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'hr@example.com.test'
        ));
        
        testUsers.add(new User(
            Alias = 'academy',
            Email = 'academy@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Academy',
            FirstName = 'Approver',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'academy@example.com.test'
        ));
        
        testUsers.add(new User(
            Alias = 'digital',
            Email = 'digital@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Digital',
            FirstName = 'Approver',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'digital@example.com.test'
        ));
        
        testUsers.add(new User(
            Alias = 'expense',
            Email = 'expense@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Expense',
            FirstName = 'Approver',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'expense@example.com.test'
        ));
        
        testUsers.add(new User(
            Alias = 'final',
            Email = 'final@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Final',
            FirstName = 'Approver',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'final@example.com.test'
        ));
        
        insert testUsers;
        
        // Create General Settings with approvers
        List<User> insertedUsers = [SELECT Id, LastName FROM User WHERE UserName LIKE '%@example.com.test%'];
        
        Map<String, Id> userMap = new Map<String, Id>();
        for(User u : insertedUsers) {
            userMap.put(u.LastName, u.Id);
        }
        
        General_Settings__c settings = new General_Settings__c(

            Campaign_Marketing_Manager_Approver__c = userMap.get('MarketingManager'),
            Marketing_Campaign_Approver__c = userMap.get('Marketing'),
            Sales_Campaign_Approver__c = userMap.get('Sales'),
            Service_Campaign_Approver__c = userMap.get('Service'),
            HR_Campaign_Approver__c = userMap.get('HR'),
            Academy_Campaign_Approver__c = userMap.get('Academy'),
            Digital_Campaign_Approver__c = userMap.get('Digital'),
            Campaign_Expense_Approver__c = userMap.get('Expense'),
            Campaign_Final_Approver__c = userMap.get('Final')
        );
        insert settings;
        

    }
    
    @isTest
    static void testCampaignSubmitterNotification_Approved() {
        // Get test data
        User testOwner = [SELECT Id FROM User WHERE LastName = 'Marketing' LIMIT 1];
        Campaign testCampaign = new Campaign(
            Name = 'Test Campaign Approved',
            OwnerId = testOwner.Id,
            Status = 'In Progress',
            Budget_Source__c = 'Marketing',
            Campaign_Medium__c = 'Non-Digital',
            Campaign_Source__c = 'Website'
        );
        insert testCampaign;
        
        List<Campaign> campaignList = new List<Campaign>{testCampaign};
        
        Test.startTest();
        CampaignTrigger_Handler.campaignSubmitterNotification(campaignList, 'approved');
        Test.stopTest();
    }
    
    @isTest
    static void testCampaignSubmitterNotification_Rejected() {
        User testOwner = [SELECT Id FROM User WHERE LastName = 'Marketing' LIMIT 1];
        Campaign testCampaign = new Campaign(
            Name = 'Test Campaign Rejected',
            OwnerId = testOwner.Id,
            Status = 'Started',
            Budget_Source__c = 'Sales',
            Campaign_Medium__c = 'Digital -Paid',
            Campaign_Source__c = 'Facebook'
        );
        insert testCampaign;
        
        List<Campaign> campaignList = new List<Campaign>{testCampaign};
        
        Test.startTest();
        CampaignTrigger_Handler.campaignSubmitterNotification(campaignList, 'rejected');
        Test.stopTest();
    }
    
    @isTest
    static void testCampaignSubmitterNotification_MultipleCampaigns() {
        User testOwner = [SELECT Id FROM User WHERE LastName = 'Marketing' LIMIT 1];
        
        List<Campaign> campaignList = new List<Campaign>();
        for(Integer i = 0; i < 5; i++) {
            campaignList.add(new Campaign(
                Name = 'Test Campaign ' + i,
                OwnerId = testOwner.Id,
                Status = 'Planned',
                Budget_Source__c = 'Marketing',
                Campaign_Medium__c = 'Non-Digital',
                Campaign_Source__c = 'Trade Show'
            ));
        }
        insert campaignList;
         campaignList[0].Status = 'Started';
        campaignList[0].Approval_Status__c ='Approved';
         campaignList[1].Status = 'Cancelled';
        campaignList[1].Approval_Status__c ='Approved';
         campaignList[1].Reason_for_Cancellation__c='System Cancelled';
        update campaignList;
        
        Test.startTest();
        CampaignTrigger_Handler.campaignSubmitterNotification(campaignList, 'approved');
        Test.stopTest();
    }
    
    @isTest
    static void testMapApproverUser_MarketingBudget() {
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
            Digital_Campaign_Approver__c = UserInfo.getUserId()
        );
        insert general;
        List<Campaign> campaignList = new List<Campaign>();
        
        // Test Marketing budget source
        campaignList.add(new Campaign(
            Name = 'Marketing Campaign',
            Budget_Source__c = 'Marketing',
            Status = 'Planned',
            Campaign_Medium__c = 'Non-Digital',
            Campaign_Source__c = 'Website'
        ));
        
        Test.startTest();
        CampaignTrigger_Handler.mapApproverUser(campaignList);
        Test.stopTest();
    }
    
    @isTest
    static void testMapApproverUser_SalesBudget() {
        Campaign testCampaign = new Campaign(
            Name = 'Sales Campaign',
            Budget_Source__c = 'Sales',
            Status = 'Planned',
            Campaign_Medium__c = 'Digital - Paid',
            Campaign_Source__c = 'LinkedIn'
        );
        
        List<Campaign> campaignList = new List<Campaign>{testCampaign};
        
        Test.startTest();
        CampaignTrigger_Handler.mapApproverUser(campaignList);
        Test.stopTest();
    }
    
    @isTest
    static void testMapApproverUser_ServiceSalesBudget() {
        Campaign testCampaign = new Campaign(
            Name = 'Service Sales Campaign',
            Budget_Source__c = 'Service Sales',
            Status = 'Planned',
            Campaign_Medium__c = 'Digital - Organic',
            Campaign_Source__c = 'Email Marketing'
        );
        
        List<Campaign> campaignList = new List<Campaign>{testCampaign};
        
        Test.startTest();
        CampaignTrigger_Handler.mapApproverUser(campaignList);
        Test.stopTest();
    }
    
    @isTest
    static void testMapApproverUser_CorporateBudget() {
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
            Digital_Campaign_Approver__c = UserInfo.getUserId()
        );
        insert general;
        Campaign testCampaign = new Campaign(
            Name = 'Corporate Campaign',
            Budget_Source__c = 'Corporate',
            Status = 'Planned',
            Campaign_Medium__c = 'Non-Digital',
            Campaign_Source__c = 'Trade Show'
        );
        
        List<Campaign> campaignList = new List<Campaign>{testCampaign};
        
        Test.startTest();
        CampaignTrigger_Handler.mapApproverUser(campaignList);
        Test.stopTest();
    }
    
    @isTest
    static void testMapApproverUser_OthersBudget() {
        Campaign testCampaign = new Campaign(
            Name = 'Others Campaign',
            Budget_Source__c = 'Others',
            Status = 'Planned',
            Campaign_Medium__c = 'Digital - Paid',
            Campaign_Source__c = 'Instagram'
        );
        
        List<Campaign> campaignList = new List<Campaign>{testCampaign};
        
        Test.startTest();
        CampaignTrigger_Handler.mapApproverUser(campaignList);
        Test.stopTest();
    }
    
    @isTest
    static void testMapApproverUser_AcademyBudget() {
        Campaign testCampaign = new Campaign(
            Name = 'Academy Campaign',
            Budget_Source__c = 'Academy',
            Status = 'Planned',
            Campaign_Medium__c = 'Digital - Organic',
            Campaign_Source__c = 'WhatsApp'
        );
        
        List<Campaign> campaignList = new List<Campaign>{testCampaign};
        
        Test.startTest();
        CampaignTrigger_Handler.mapApproverUser(campaignList);
        Test.stopTest();
    }
    
    @isTest
    static void testMapApproverUser_HRBudget() {
        Campaign testCampaign = new Campaign(
            Name = 'HR Campaign',
            Budget_Source__c = 'HR',
            Status = 'Planned',
            Campaign_Medium__c = 'Non-Digital',
            Campaign_Source__c = 'Website'
        );
        
        List<Campaign> campaignList = new List<Campaign>{testCampaign};
        
        Test.startTest();
        CampaignTrigger_Handler.mapApproverUser(campaignList);
        Test.stopTest();
    }
    
    @isTest
    static void testMapApproverUser_AllBudgetSources() {
        List<Campaign> campaignList = new List<Campaign>();
        
        // Test all valid budget sources with different mediums and sources
        campaignList.add(new Campaign(Name = 'Camp 1', Budget_Source__c = 'Marketing', Status = 'Planned', Campaign_Medium__c = 'Non-Digital', Campaign_Source__c = 'Website'));
        campaignList.add(new Campaign(Name = 'Camp 2', Budget_Source__c = 'Sales', Status = 'Planned', Campaign_Medium__c = 'Digital - Paid', Campaign_Source__c = 'Facebook'));
        campaignList.add(new Campaign(Name = 'Camp 3', Budget_Source__c = 'Service Sales', Status = 'Planned', Campaign_Medium__c = 'Digital - Organic', Campaign_Source__c = 'Instagram'));
        campaignList.add(new Campaign(Name = 'Camp 4', Budget_Source__c = 'Corporate', Status = 'Planned', Campaign_Medium__c = 'Non-Digital', Campaign_Source__c = 'Trade Show'));
        campaignList.add(new Campaign(Name = 'Camp 5', Budget_Source__c = 'Others', Status = 'Planned', Campaign_Medium__c = 'Digital - Paid', Campaign_Source__c = 'LinkedIn'));
        campaignList.add(new Campaign(Name = 'Camp 6', Budget_Source__c = 'Academy', Status = 'Planned', Campaign_Medium__c = 'Digital - Organic', Campaign_Source__c = 'Email Marketing'));
        campaignList.add(new Campaign(Name = 'Camp 7', Budget_Source__c = 'HR', Status = 'Planned', Campaign_Medium__c = 'Non-Digital', Campaign_Source__c = 'WhatsApp'));
        
        Test.startTest();
        CampaignTrigger_Handler.mapApproverUser(campaignList);
        Test.stopTest();
    }
    
    @isTest
    static void testMapApproverUser_VariousMediums() {
        List<Campaign> campaignList = new List<Campaign>();
        
        // Test different campaign mediums
        campaignList.add(new Campaign(Name = 'Non-Digital Camp', Budget_Source__c = 'Marketing', Status = 'Planned', Campaign_Medium__c = 'Non-Digital', Campaign_Source__c = 'Trade Show'));
        campaignList.add(new Campaign(Name = 'Digital Paid Camp', Budget_Source__c = 'Sales', Status = 'Planned', Campaign_Medium__c = 'Digital - Paid', Campaign_Source__c = 'Facebook'));
        campaignList.add(new Campaign(Name = 'Digital Organic Camp', Budget_Source__c = 'Service Sales', Status = 'Planned', Campaign_Medium__c = 'Digital - Organic', Campaign_Source__c = 'Email Marketing'));
        
        Test.startTest();
        CampaignTrigger_Handler.mapApproverUser(campaignList);
        Test.stopTest();
    }
    
    @isTest
    static void testMapApproverUser_VariousSources() {
        List<Campaign> campaignList = new List<Campaign>();
        
        // Test different campaign sources
        campaignList.add(new Campaign(Name = 'Website Camp', Budget_Source__c = 'Marketing', Status = 'Planned', Campaign_Medium__c = 'Non-Digital', Campaign_Source__c = 'Website'));
        campaignList.add(new Campaign(Name = 'FB Camp', Budget_Source__c = 'Sales', Status = 'Planned', Campaign_Medium__c = 'Digital - Paid', Campaign_Source__c = 'Facebook'));
        campaignList.add(new Campaign(Name = 'Insta Camp', Budget_Source__c = 'Service Sales', Status = 'Planned', Campaign_Medium__c = 'Digital - Paid', Campaign_Source__c = 'Instagram'));
        campaignList.add(new Campaign(Name = 'Trade Camp', Budget_Source__c = 'Corporate', Status = 'Planned', Campaign_Medium__c = 'Non-Digital', Campaign_Source__c = 'Trade Show'));
        campaignList.add(new Campaign(Name = 'LinkedIn Camp', Budget_Source__c = 'Others', Status = 'Planned', Campaign_Medium__c = 'Digital - Paid', Campaign_Source__c = 'LinkedIn'));
        campaignList.add(new Campaign(Name = 'Email Camp', Budget_Source__c = 'Academy', Status = 'Planned', Campaign_Medium__c = 'Digital - Organic', Campaign_Source__c = 'Email Marketing'));
        campaignList.add(new Campaign(Name = 'WhatsApp Camp', Budget_Source__c = 'HR', Status = 'Planned', Campaign_Medium__c = 'Digital - Organic', Campaign_Source__c = 'WhatsApp'));
        
        Test.startTest();
        CampaignTrigger_Handler.mapApproverUser(campaignList);
        Test.stopTest();
    }
    
    @isTest
    static void testMapApproverUser_SkipInTest() {
        Campaign testCampaign = new Campaign(
            Name = 'Test Skip Campaign',
            Budget_Source__c = 'Marketing',
            Status = 'Planned',
            Campaign_Medium__c = 'Non-Digital',
            Campaign_Source__c = 'Website'
        );
        
        List<Campaign> campaignList = new List<Campaign>{testCampaign};
        

        
        Test.startTest();
        CampaignTrigger_Handler.mapApproverUser(campaignList);
        Test.stopTest();
        
   
    }
    
    @isTest
    static void testMapApproverUser_EmptySettings() {
        // Delete existing settings
        delete [SELECT Id FROM General_Settings__c LIMIT 1];
        
        Campaign testCampaign = new Campaign(
            Name = 'Empty Settings Campaign',
            Budget_Source__c = 'Marketing',
            Status = 'Planned',
            Campaign_Medium__c = 'Non-Digital',
            Campaign_Source__c = 'Website'
        );
        
        List<Campaign> campaignList = new List<Campaign>{testCampaign};
        
        Test.startTest();
        CampaignTrigger_Handler.mapApproverUser(campaignList);
        Test.stopTest();
    }
    
    @isTest
    static void testMapApproverUser_NullBudgetSource() {
        Campaign testCampaign = new Campaign(
            Name = 'Null Budget Campaign',
            Budget_Source__c = null,
            Status = 'Planned',
            Campaign_Medium__c = 'Non-Digital',
            Campaign_Source__c = 'Website'
        );
        
        List<Campaign> campaignList = new List<Campaign>{testCampaign};
        
        Test.startTest();
        CampaignTrigger_Handler.mapApproverUser(campaignList);
        Test.stopTest();
    }
    
    @isTest
    static void testMapApproverUser_AllNullOptionalFields() {
        Campaign testCampaign = new Campaign(
            Name = 'All Null Fields Campaign',
            Budget_Source__c = 'Marketing',
            Status = 'Planned',
            Campaign_Medium__c = null,
            Campaign_Source__c = null
        );
        
        List<Campaign> campaignList = new List<Campaign>{testCampaign};
        
        Test.startTest();
        CampaignTrigger_Handler.mapApproverUser(campaignList);
        Test.stopTest();
    }
}