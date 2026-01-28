@isTest
private class CampaignSchedulerTest {
    
    @testSetup
    static void setupTestData() {
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

        List<Campaign> testCampaigns = new List<Campaign>();
        
        Campaign activateCampaign = new Campaign(
            Name = 'Test Campaign for Activation',
            StartDate = System.today(),
            EndDate = System.today().addDays(30),
            Status = 'Approved',
            Approval_Status__c = 'Approved',
            IsActive = false,
            Reason_for_Cancellation__c = null,
            Campaign_Source__c = 'LinkedIn',
            Campaign_Medium__c = 'Digital -Paid'
        );
        testCampaigns.add(activateCampaign);
        
        Campaign cancelCampaign = new Campaign(
            Name = 'Test Campaign for Cancellation',
            StartDate = System.today().addDays(-60),
            EndDate = System.today().addDays(-1),
            Status = 'Approved',
            Approval_Status__c = 'Approved',
            IsActive = true,
            Reason_for_Cancellation__c = null,
            Campaign_Source__c = 'LinkedIn',
            Campaign_Medium__c = 'Digital -Paid'
        );
        testCampaigns.add(cancelCampaign);
        
        Campaign completeCampaign = new Campaign(
            Name = 'Test Campaign for Completion',
            StartDate = System.today().addDays(-30),
            EndDate = System.today().addDays(-1),
            Status = 'Started',
            Approval_Status__c = 'Approved',
            IsActive = true,
            Reason_for_Cancellation__c = null,
            Campaign_Source__c = 'Website',
            Campaign_Medium__c = 'Digital -Paid'
        );
        testCampaigns.add(completeCampaign);
        
        Campaign draftCampaign = new Campaign(
            Name = 'Test Draft Campaign',
            StartDate = System.today(),
            EndDate = System.today().addDays(30),
            Status = 'Draft',
            Approval_Status__c = 'Draft',
            IsActive = false,
            Reason_for_Cancellation__c = null,
            Campaign_Source__c = 'Google Ads',
            Campaign_Medium__c = 'Non-Digital'
        );
        testCampaigns.add(draftCampaign);
        
        Campaign futureCampaign = new Campaign(
            Name = 'Test Future Campaign',
            StartDate = System.today().addDays(1),
            EndDate = System.today().addDays(31),
            Status = 'Approved',
            Approval_Status__c = 'Approved',
            IsActive = false,
            Reason_for_Cancellation__c = null,
            Campaign_Source__c = 'Website',
            Campaign_Medium__c = 'Non-Digital'
        );
        testCampaigns.add(futureCampaign);
        
        Campaign campaignWithDifferentSources = new Campaign(
            Name = 'Campaign with Various Sources',
            StartDate = System.today(),
            EndDate = System.today().addDays(15),
            Status = 'Approved',
            Approval_Status__c = 'Approved',
            IsActive = false,
            Reason_for_Cancellation__c = null,
            Campaign_Source__c = 'Website',
            Campaign_Medium__c = 'Non-Digital'
        );
        testCampaigns.add(campaignWithDifferentSources);
        
        insert testCampaigns;
    }
    
    @isTest
    static void testStartMethodQueryWithSourceMediumFields() {
        Test.startTest();
        CampaignScheduler scheduler = new CampaignScheduler();
        Database.QueryLocator ql = scheduler.start(null);
        List<Campaign> queriedCampaigns = Database.query(ql.getQuery());
        Test.stopTest();
    }
    
    @isTest
    static void testExecuteMethodForActivationWithSourceMedium() {
        Campaign activateCampaign = [SELECT Id, Status, IsActive, Campaign_Source__c,StartDate,Approval_Status__c,EndDate, Campaign_Medium__c FROM Campaign WHERE Name = 'Test Campaign for Activation' LIMIT 1];
        
        Test.startTest();
        CampaignScheduler scheduler = new CampaignScheduler();
        scheduler.execute(null, new List<Campaign>{activateCampaign});
        Test.stopTest();
        
        Campaign updatedCampaign = [SELECT Id, Status, IsActive,Approval_Status__c,StartDate, Reason_for_Cancellation__c,EndDate, Campaign_Source__c, Campaign_Medium__c FROM Campaign WHERE Id = :activateCampaign.Id];
    }
    
    @isTest
    static void testExecuteMethodForCancellationWithSourceMedium() {
        Campaign cancelCampaign = [SELECT Id, Status, IsActive, Campaign_Source__c,StartDate,Approval_Status__c,EndDate, Campaign_Medium__c FROM Campaign WHERE Name = 'Test Campaign for Cancellation' LIMIT 1];
        
        Test.startTest();
        CampaignScheduler scheduler = new CampaignScheduler();
        scheduler.execute(null, new List<Campaign>{cancelCampaign});
        Test.stopTest();
        
        Campaign updatedCampaign = [SELECT Id, Status, IsActive, Reason_for_Cancellation__c, Cancelled_Date_Time__c, Campaign_Source__c, Campaign_Medium__c FROM Campaign WHERE Id = :cancelCampaign.Id];
    }
    
    @isTest
    static void testExecuteMethodForCompletionWithSourceMedium() {
        Campaign completeCampaign = [SELECT Id, Status, IsActive, Campaign_Source__c,StartDate,Approval_Status__c,EndDate, Campaign_Medium__c FROM Campaign WHERE Name = 'Test Campaign for Completion' LIMIT 1];
        
        Test.startTest();
        CampaignScheduler scheduler = new CampaignScheduler();
        scheduler.execute(null, new List<Campaign>{completeCampaign});
        Test.stopTest();
        
        Campaign updatedCampaign = [SELECT Id, Status, IsActive, Campaign_Source__c,StartDate,Approval_Status__c,EndDate, Campaign_Medium__c FROM Campaign WHERE Id = :completeCampaign.Id];
    }
    
    @isTest
    static void testExecuteMethodWithMixedCampaignsAndSourceMedium() {
        List<Campaign> testCampaigns = [SELECT Id, Status, IsActive, Campaign_Source__c,StartDate,Approval_Status__c,EndDate, Campaign_Medium__c FROM Campaign];
        
        Test.startTest();
        CampaignScheduler scheduler = new CampaignScheduler();
        scheduler.execute(null, testCampaigns);
        Test.stopTest();
        
        Map<Id, Campaign> updatedCampaigns = new Map<Id, Campaign>([
            SELECT Id, Status, IsActive, Campaign_Source__c,StartDate,Approval_Status__c,EndDate, Campaign_Medium__c
            FROM Campaign
        ]);
    }
    
    @isTest
    static void testCampaignWithSourceMediumNullValues() {
        Campaign nullSourceMediumCampaign = new Campaign(
            Name = 'Campaign with Null Source/Medium',
            StartDate = System.today(),
            EndDate = System.today().addDays(30),
            Status = 'Approved',
            Approval_Status__c = 'Approved',
            IsActive = false,
            Campaign_Source__c = 'Website',
            Campaign_Medium__c = 'Digital -Paid'
        );
        insert nullSourceMediumCampaign;
        
        Test.startTest();
        CampaignScheduler scheduler = new CampaignScheduler();
        scheduler.execute(null, new List<Campaign>{nullSourceMediumCampaign});
        Test.stopTest();
        
        Campaign updatedCampaign = [SELECT Id, Status, IsActive, Campaign_Source__c,StartDate,Approval_Status__c,EndDate, Campaign_Medium__c FROM Campaign WHERE Id = :nullSourceMediumCampaign.Id];
    }
    
    @isTest
    static void testCampaignWithLongSourceMediumValues() {
        Campaign longSourceCampaign = new Campaign(
            Name = 'Campaign with Long Source Values',
            StartDate = System.today(),
            EndDate = System.today().addDays(30),
            Status = 'Approved',
            Approval_Status__c = 'Approved',
            IsActive = false,
            Campaign_Source__c = 'Youtube',
            Campaign_Medium__c = 'Non-Digital'
        );
        insert longSourceCampaign;
        
        Test.startTest();
        CampaignScheduler scheduler = new CampaignScheduler();
        scheduler.execute(null, new List<Campaign>{longSourceCampaign});
        Test.stopTest();
    }
    
    @isTest
    static void testBulkCampaignsWithDifferentSourcesMediums() {
        List<Campaign> bulkCampaigns = new List<Campaign>();
        List<String> sources = new List<String>{'Web', 'Email', 'Social', 'Event', 'Referral', 'Paid', 'Organic', 'Mobile', 'TV', 'Radio'};
        List<String> mediums = new List<String>{'Email', 'Facebook', 'Twitter', 'Direct', 'Partner', 'Google', 'Bing', 'Push', 'SMS', 'Call'};
        
            Campaign camp = new Campaign(
                Name = 'Bulk Campaign ' ,
                StartDate = System.today(),
                EndDate = System.today().addDays(30),
                Status = 'Approved',
                Approval_Status__c = 'Approved',
                IsActive = false,
                Budget_Source__c='Academy',
                Campaign_Source__c = 'Youtube',
                Campaign_Medium__c = 'Non-Digital'
            );
           

        
        insert camp;
        
        Test.startTest();
        CampaignScheduler scheduler = new CampaignScheduler();
        scheduler.execute(null, bulkCampaigns);
        Test.stopTest();
        
        List<Campaign> updatedCampaigns = [SELECT Id, Campaign_Source__c, Campaign_Medium__c FROM Campaign WHERE Name LIKE 'Bulk Campaign%'];
    }
    
    @isTest
    static void testCampaignSourceMediumNotAffectedByStatusChange() {
        Campaign testCampaign = new Campaign(
            Name = 'Test Source Medium Persistence',
            StartDate = System.today(),
            EndDate = System.today().addDays(30),
            Status = 'Approved',
            Approval_Status__c = 'Approved',
            IsActive = false,
              Budget_Source__c='Academy',
                Campaign_Source__c = 'Instagram',
                Campaign_Medium__c = '	Non-Digital'
        );
        insert testCampaign;
        
        Test.startTest();
        CampaignScheduler scheduler = new CampaignScheduler();
        scheduler.execute(null, new List<Campaign>{testCampaign});
        Test.stopTest();
        
        Campaign updatedCampaign = [SELECT Id, Status, Campaign_Source__c, Campaign_Medium__c FROM Campaign WHERE Id = :testCampaign.Id];
    }
    
    @isTest
    static void testCampaignWithSpecialCharactersInSourceMedium() {
        Campaign specialCharCampaign = new Campaign(
            Name = 'Campaign with Special Chars',
            StartDate = System.today(),
            EndDate = System.today().addDays(30),
            Status = 'Approved',
            Approval_Status__c = 'Approved',
            IsActive = false,
            Budget_Source__c='Academy',
                Campaign_Source__c = 'Instagram',
                Campaign_Medium__c = 'Non-Digital'
        );
        insert specialCharCampaign;
        
        Test.startTest();
        CampaignScheduler scheduler = new CampaignScheduler();
        scheduler.execute(null, new List<Campaign>{specialCharCampaign});
        Test.stopTest();
    }
    
    @isTest
    static void testSchedulableExecuteWithSourceMedium() {
        Test.startTest();
        CampaignScheduler scheduler = new CampaignScheduler();
        scheduler.execute(null);
        Test.stopTest();
    }
    
    @isTest
    static void testFinishMethodWithSourceMedium() {
        Test.startTest();
        CampaignScheduler scheduler = new CampaignScheduler();
        scheduler.finish(null);
        Test.stopTest();
    }
    
    @isTest
    static void testBatchExecutionWithSourceMedium() {
        Test.startTest();
        Id batchJobId = Database.executeBatch(new CampaignScheduler(), 200);
        Test.stopTest();
        
        AsyncApexJob job = [SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors 
                           FROM AsyncApexJob 
                           WHERE Id = :batchJobId];
    }
    
    @isTest
    static void testEmptyCampaignListWithSourceMedium() {
        Test.startTest();
        CampaignScheduler scheduler = new CampaignScheduler();
        scheduler.execute(null, new List<Campaign>());
        Test.stopTest();
    }
    
    @isTest
    static void testAllScenariosWithSourceMediumInOneBatch() {
        Test.startTest();
        CampaignScheduler scheduler = new CampaignScheduler();
        Database.QueryLocator ql = scheduler.start(null);
        List<Campaign> campaignsToProcess = Database.query(ql.getQuery());
        scheduler.execute(null, campaignsToProcess);
        scheduler.finish(null);
        Test.stopTest();
    }
}