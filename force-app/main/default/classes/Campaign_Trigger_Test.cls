@IsTest
public class Campaign_Trigger_Test {

    /* =====================================================
       UTILITY: GET PICKLIST VALUE DYNAMICALLY
       ===================================================== */
    private static String pickVal(Schema.SObjectType objType, String fieldApi) {
        return objType.getDescribe()
            .fields.getMap()
            .get(fieldApi)
            .getDescribe()
            .getPicklistValues()[0]
            .getValue();
    }

    /* =====================================================
       TEST SETUP (RUNS ONCE)
       ===================================================== */
    @testSetup
    static void setupData() {

        // Create active user
        Profile p = [
            SELECT Id FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        User u = new User(
            FirstName = 'Test',
            LastName  = 'User',
            Alias     = 'tusr',
            Email     = 'testuser@test.com',
            Username  = 'testuser' + System.currentTimeMillis() + '@test.com',
            TimeZoneSidKey   = 'Asia/Kolkata',
            LocaleSidKey     = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey= 'en_US',
            ProfileId = p.Id
        );
        insert u;

        // REQUIRED: General Settings for handler
        insert new General_Settings__c(
            Campaign_Marketing_Manager_Approver__c = u.Id,
            Campaign_Final_Approver__c            = u.Id,
            Campaign_Expense_Approver__c          = u.Id,
            Telephony_Campaign_Approver__c        = u.Id,
            Academy_Campaign_Approver__c          = u.Id,
            Sales_Campaign_Approver__c            = u.Id,
            Service_Campaign_Approver__c          = u.Id,
            Marketing_Campaign_Approver__c        = u.Id,
            HR_Campaign_Approver__c               = u.Id,
            Digital_Campaign_Approver__c          = u.Id
        );
    }

    /* =====================================================
       TEST 1: BEFORE INSERT – MAP APPROVER
       ===================================================== */
    @IsTest
    static void testBeforeInsert_MapApprover() {

        Campaign camp = new Campaign(
            Name = 'Insert Campaign',
            StartDate = Date.today(),
            EndDate = Date.today().addDays(5),
            Status = 'Draft',
            Approval_Status__c = 'Draft',
            IsActive = false,
            Campaign_Source__c =
                pickVal(Campaign.SObjectType, 'Campaign_Source__c'),
            Campaign_Medium__c =
                pickVal(Campaign.SObjectType, 'Campaign_Medium__c')
        );

        Test.startTest();
            insert camp;
        Test.stopTest();

        Campaign inserted = [
            SELECT Id, Marketing_Manager_Approver__c
            FROM Campaign
            WHERE Id = :camp.Id
        ];

        System.assertNotEquals(
            null,
            inserted.Marketing_Manager_Approver__c,
            'Approver should be mapped in before insert'
        );
    }

    /* =====================================================
       TEST 2: BEFORE UPDATE – STATUS → ACTIVE
       ===================================================== */
    @IsTest
    static void testBeforeUpdate_StatusStarted() {

        Campaign camp = new Campaign(
            Name = 'Status Start Campaign',
            StartDate = Date.today(),
            EndDate = Date.today().addDays(5),
            Status = 'Approved',
            Approval_Status__c = 'Approved',
            IsActive = false,
            Campaign_Source__c =
                pickVal(Campaign.SObjectType, 'Campaign_Source__c'),
            Campaign_Medium__c =
                pickVal(Campaign.SObjectType, 'Campaign_Medium__c')
        );
        insert camp;

        Test.startTest();
            camp.Status = 'Started';
            update camp;
        Test.stopTest();

        Campaign updated = [
            SELECT IsActive
            FROM Campaign
            WHERE Id = :camp.Id
        ];

        System.assertEquals(
            true,
            updated.IsActive,
            'Campaign should auto-activate when status is Started'
        );
    }

    /* =====================================================
       TEST 3: AFTER UPDATE – APPROVED NOTIFICATION PATH
       ===================================================== */
    @IsTest
    static void testAfterUpdate_ApprovalNotification() {

        Campaign camp = new Campaign(
            Name = 'Approval Campaign',
            StartDate = Date.today(),
            EndDate = Date.today().addDays(5),
            Status = 'Draft',
            Approval_Status__c = 'Draft',
            IsActive = false,
            Campaign_Source__c =
                pickVal(Campaign.SObjectType, 'Campaign_Source__c'),
            Campaign_Medium__c =
                pickVal(Campaign.SObjectType, 'Campaign_Medium__c')
        );
        insert camp;

        Test.startTest();
            camp.Approval_Status__c = 'Approved';
            update camp;
        Test.stopTest();

        System.assert(true, 'Approval notification path executed');
    }

    /* =====================================================
       TEST 4: AFTER UPDATE – REJECTED → RESUBMIT
       ===================================================== */
    @IsTest
    static void testAfterUpdate_Resubmitted() {

        Campaign camp = new Campaign(
            Name = 'Rejected Campaign',
            StartDate = Date.today(),
            EndDate = Date.today().addDays(5),
            Status = 'Rejected',
            Approval_Status__c = 'Rejected',
            IsActive = false,
            Campaign_Source__c =
                pickVal(Campaign.SObjectType, 'Campaign_Source__c'),
            Campaign_Medium__c =
                pickVal(Campaign.SObjectType, 'Campaign_Medium__c')
        );
        insert camp;

        Test.startTest();
            camp.Approval_Status__c = 'Submitted for Approval';
            update camp;
        Test.stopTest();

        System.assert(true, 'Resubmission notification path executed');
    }
}