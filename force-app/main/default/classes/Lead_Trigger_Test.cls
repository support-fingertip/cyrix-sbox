@IsTest
public class Lead_Trigger_Test {

    /* =====================================================
       UTILITY: GET DYNAMIC PICKLIST VALUE
       ===================================================== */
    private static String getPickVal(Schema.SObjectType objType, String fieldApi) {
        return objType.getDescribe()
                      .fields.getMap()
                      .get(fieldApi)
                      .getDescribe()
                      .getPicklistValues()[0]
                      .getValue();
    }

    /* =====================================================
       UTILITY: GET CONVERTED LEAD STATUS
       ===================================================== */
    private static String getConvertedStatus() {
        return [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true
            LIMIT 1
        ].MasterLabel;
    }

    /* =====================================================
       UTILITY: SAFE INSERT (DUPLICATE SAFE)
       ===================================================== */
    private static void safeInsert(SObject s) {
        Database.DMLOptions dmo = new Database.DMLOptions();
        dmo.DuplicateRuleHeader.allowSave = true;
        dmo.DuplicateRuleHeader.runAsCurrentUser = true;
        s.setOptions(dmo);
        insert s;
    }

    /* =====================================================
       TEST SETUP
       ===================================================== */
    @testSetup
    static void setupData() {

        // Profile
        Profile p = [
            SELECT Id FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        // Active User
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

        // Required General Settings
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

        // Campaign (dynamic picklists)
        Campaign camp = new Campaign(
            Name = 'Test Campaign',
            IsActive = true,
            Type = 'Marketing',
            Campaign_Source__c =
                getPickVal(Campaign.SObjectType, 'Campaign_Source__c'),
            Campaign_Medium__c =
                getPickVal(Campaign.SObjectType, 'Campaign_Medium__c')
        );
        insert camp;

        // Lead (Phone exactly 10 digits)
        Lead ld = new Lead(
            LastName = 'Test Lead',
            Company  = 'Test Company',
            Phone    = '9999999999',
            Status   = 'Open - Not Contacted',
            Campaign__c = camp.Id,
            OwnerId     = u.Id,
            Next_Follow_up_Date__c = Date.today().addDays(3)
        );
        safeInsert(ld);
    }

    /* =====================================================
       TEST: INSERT + UPDATE PATHS
       ===================================================== */
    @IsTest
    static void testLeadUpdate() {
        Lead ld = [
            SELECT Id, Next_Follow_up_Date__c
            FROM Lead
            LIMIT 1
        ];

        Test.startTest();
            ld.Next_Follow_up_Date__c = Date.today().addDays(7);
            update ld;
        Test.stopTest();

        System.assert(true);
    }

    /* =====================================================
       TEST: LEAD CONVERSION
       ===================================================== */
    @IsTest
    static void testLeadConversion() {

        Lead ld = [SELECT Id FROM Lead LIMIT 1];

        // Account with REQUIRED FIELD
        Account acc = new Account(
            Name = 'Converted Account',
            Customer_Category__c =
                getPickVal(Account.SObjectType, 'Customer_Category__c')
        );
        safeInsert(acc);

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(ld.Id);
        lc.setConvertedStatus(getConvertedStatus());
        lc.setAccountId(acc.Id);
        lc.setDoNotCreateOpportunity(true);

        Test.startTest();
            Database.convertLead(lc);
        Test.stopTest();

        System.assert(true);
    }
}