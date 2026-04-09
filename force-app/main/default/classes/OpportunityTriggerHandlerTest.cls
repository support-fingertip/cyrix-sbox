@isTest
public class OpportunityTriggerHandlerTest {

    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(Name = 'Test Cyrix Customer');
        insert testAccount;

        Contact testContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            AccountId = testAccount.Id
        );
        insert testContact;
    }

    /* ────── Auto Number Generation ────── */


    /* ────── Default Stage ────── */
    @isTest
    static void testDefaultStage() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Opportunity opp = new Opportunity(
            Name = 'Test Default Stage',
            AccountId = acc.Id,
            CloseDate = Date.today().addDays(30)
        );

        Test.startTest();
        insert opp;
        Test.stopTest();

        Opportunity result = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Qualified', result.StageName, 'Default stage should be Qualified');
    }

    /* ────── Opportunity Name from Account ────── */
    @isTest
    static void testOpportunityNameFromAccount() {
        Account acc = [SELECT Id, Name FROM Account LIMIT 1];

        Opportunity opp = new Opportunity(
            AccountId = acc.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(30)
        );

        Test.startTest();
        insert opp;
        Test.stopTest();

        Opportunity result = [SELECT Name FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(acc.Name, result.Name, 'Opportunity name should default to Account name when no product');
    }

    /* ────── Opportunity Name = Account + Product ────── */
    @isTest
    static void testOpportunityNameWithProduct() {
        Account acc = [SELECT Id, Name FROM Account LIMIT 1];

        Product2 prod = new Product2(Name = 'X-Ray Machine', IsActive = true);
        insert prod;

        Opportunity opp = new Opportunity(
            AccountId = acc.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(30),
            Product__c = prod.Id
        );

        Test.startTest();
        insert opp;
        Test.stopTest();

        Opportunity result = [SELECT Name FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(acc.Name + ' ' + prod.Name, result.Name, 'Opportunity name should be Account + Product');
    }

    /* ────── Stage Change ────── */
    @isTest
    static void testStageChange() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Opportunity opp = new Opportunity(
            Name = 'Test Stage Change',
            AccountId = acc.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Test.startTest();
        opp.StageName = 'Proposal';
        update opp;
        Test.stopTest();

        Opportunity result = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Proposal', result.StageName, 'Stage should be updated to Proposal');
    }

    /* ────── Closed Lost Requires Reason (Validation Rule) ────── */
    @isTest
    static void testClosedLostRequiresReason() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Opportunity opp = new Opportunity(
            Name = 'Test Closed Lost',
            AccountId = acc.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Test.startTest();
        Boolean errorOccurred = false;
        try {
            opp.StageName = 'Closed Lost';
            update opp;
        } catch (DmlException e) {
            errorOccurred = true;
        }
        Test.stopTest();

        System.assertEquals(true, errorOccurred, 'Validation should fail without Lost Reason');
    }

    /* ────── Closed Lost With Reason ────── */
    @isTest
    static void testClosedLostWithReason() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Opportunity opp = new Opportunity(
            Name = 'Test Closed Lost Valid',
            AccountId = acc.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Test.startTest();
        opp.StageName = 'Closed Lost';
        opp.Closed_Lost_Reason__c = 'Our response was delayed';
        opp.CloseDate = Date.today();
        update opp;
        Test.stopTest();

        Opportunity result = [SELECT StageName, Closed_Lost_Reason__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Closed Lost', result.StageName);
        System.assertEquals('Our response was delayed', result.Closed_Lost_Reason__c);
    }

    /* ────── Closed Won Mandatory Fields (Validation Rule) ────── */
    @isTest
    static void testClosedWonRequiresMandatoryFields() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Opportunity opp = new Opportunity(
            Name = 'Test Closed Won',
            AccountId = acc.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Test.startTest();
        Boolean errorOccurred = false;
        try {
            opp.StageName = 'Closed Won';
            update opp;
        } catch (DmlException e) {
            errorOccurred = true;
        }
        Test.stopTest();

        System.assertEquals(true, errorOccurred, 'Validation should fail without mandatory Closed Won fields');
    }

    /* ────── Closed Won With All Fields ────── */
    @isTest
    static void testClosedWonWithAllFields() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Opportunity opp = new Opportunity(
            Name = 'Test Closed Won Valid',
            AccountId = acc.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Test.startTest();
        opp.StageName = 'Closed Won';
        opp.CloseDate = Date.today();
        opp.PO_WO_Signed_Quotation__c = 'Yes';
        opp.Advance_Received__c = 'Yes';
        opp.Advance_Payment_Mode__c = 'UPI';
        opp.Advance_Realized__c = 'Yes';
        update opp;
        Test.stopTest();

        Opportunity result = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Closed Won', result.StageName);
    }

    /* ────── Advance Paid Next Payment Date (Validation Rule) ────── */
    @isTest
    static void testAdvancePaidRequiresNextPaymentDate() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Opportunity opp = new Opportunity(
            Name = 'Test Advance Paid',
            AccountId = acc.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Test.startTest();
        Boolean errorOccurred = false;
        try {
            opp.StageName = 'Advance Paid';
            update opp;
        } catch (DmlException e) {
            errorOccurred = true;
        }
        Test.stopTest();

        System.assertEquals(true, errorOccurred, 'Validation should fail without Next Payment Date');
    }

    /* ────── Customer Mandatory (Validation Rule) ────── */
    @isTest
    static void testCustomerMandatory() {
        Test.startTest();
        Boolean errorOccurred = false;
        try {
            Opportunity opp = new Opportunity(
                Name = 'No Customer Opp',
                StageName = 'Qualified',
                CloseDate = Date.today().addDays(30)
            );
            insert opp;
        } catch (DmlException e) {
            errorOccurred = true;
        }
        Test.stopTest();

        System.assertEquals(true, errorOccurred, 'Validation should fail without Account');
    }

    /* ────── Owner Reassignment ────── */
    @isTest
    static void testOwnerReassignment() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Opportunity opp = new Opportunity(
            Name = 'Test Reassignment',
            AccountId = acc.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Test.startTest();
        // Reassign to current user (just to trigger the code path)
        opp.OwnerId = UserInfo.getUserId();
        update opp;
        Test.stopTest();

        Opportunity result = [SELECT OwnerId FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(UserInfo.getUserId(), result.OwnerId);
    }

    /* ────── Competitor Record Creation ────── */
    @isTest
    static void testCompetitorCreation() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Opportunity opp = new Opportunity(
            Name = 'Test Competitor',
            AccountId = acc.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Test.startTest();
        Competitor__c comp = new Competitor__c(
            Name = 'Competitor Corp',
            Opportunity__c = opp.Id,
            Competitor_Price__c = '50000',
            Remarks__c = 'Strong competitor in the region',
            Discount_Details__c = '10% discount offered'
        );
        insert comp;
        Test.stopTest();

        List<Competitor__c> competitors = [
            SELECT Id, Name, Opportunity__c
            FROM Competitor__c
            WHERE Opportunity__c = :opp.Id
        ];
        System.assertEquals(1, competitors.size(), 'One competitor record should exist');
        System.assertEquals('Competitor Corp', competitors[0].Name);
    }

    /* ────── Bulk Insert ────── */
   
    /* ────── Opportunity Type Field ────── */
    @isTest
    static void testOpportunityType() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Opportunity opp = new Opportunity(
            Name = 'Test Type',
            AccountId = acc.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(30),
            Opportunity_Type__c = 'Direct Sales'
        );

        Test.startTest();
        insert opp;
        Test.stopTest();

        Opportunity result = [SELECT Opportunity_Type__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Direct Sales', result.Opportunity_Type__c);
    }

    /* ────── Primary Contact Person ────── */
    @isTest
    static void testPrimaryContactPerson() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        Opportunity opp = new Opportunity(
            Name = 'Test Contact Link',
            AccountId = acc.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(30),
            Primary_Contact_Person__c = con.Id
        );

        Test.startTest();
        insert opp;
        Test.stopTest();

        Opportunity result = [SELECT Primary_Contact_Person__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(con.Id, result.Primary_Contact_Person__c);
    }

    /* ────── Campaign Mapping on Insert ────── 
    @isTest
    static void testCampaignMappingOnInsert() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        Campaign camp = new Campaign(Name = 'Test Campaign', IsActive = true);
        insert camp;

        Opportunity opp = new Opportunity(
            Name = 'Test Campaign Opp',
            AccountId = acc.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(30),
            Campaign__c = camp.Id,
            Primary_Contact_Person__c = con.Id
        );

        Test.startTest();
        insert opp;
        Test.stopTest();

        List<CampaignMember> members = [
            SELECT Id, ContactId, CampaignId
            FROM CampaignMember
            WHERE CampaignId = :camp.Id AND ContactId = :con.Id
        ];
        System.assertEquals(1, members.size(), 'Contact should be added as Campaign Member');
    }
*/
    /* ────── Campaign Mapping on Update ────── 
    @isTest
    static void testCampaignMappingOnUpdate() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        Campaign camp = new Campaign(Name = 'Test Campaign Update', IsActive = true);
        insert camp;

        Opportunity opp = new Opportunity(
            Name = 'Test Campaign Update Opp',
            AccountId = acc.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(30),
            Primary_Contact_Person__c = con.Id
        );
        insert opp;

        Test.startTest();
        opp.Campaign__c = camp.Id;
        update opp;
        Test.stopTest();

        List<CampaignMember> members = [
            SELECT Id, ContactId, CampaignId
            FROM CampaignMember
            WHERE CampaignId = :camp.Id AND ContactId = :con.Id
        ];
        System.assertEquals(1, members.size(), 'Contact should be added as Campaign Member on update');
    }*/
}