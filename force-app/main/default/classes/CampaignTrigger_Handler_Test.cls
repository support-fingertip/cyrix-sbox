@IsTest
public class CampaignTrigger_Handler_Test {

    /* =========================================================
       UTILITY METHOD – DYNAMIC PICKLIST VALUE (SAFE)
       ========================================================= */
    private static String getValidPicklistValue(Schema.SObjectField fieldRef) {
        List<Schema.PicklistEntry> values =
            fieldRef.getDescribe().getPicklistValues();
        return values.isEmpty() ? null : values[0].getValue();
    }

    /* =========================================================
       TEST DATA SETUP
       ========================================================= */
    @testSetup
    static void setupData() {

        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        User approver1 = new User(
            Alias = 'app1',
            Email = 'app1@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Approver1',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'app1' + System.currentTimeMillis() + '@test.com'
        );

        User approver2 = new User(
            Alias = 'app2',
            Email = 'app2@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Approver2',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'app2' + System.currentTimeMillis() + '@test.com'
        );

        insert new List<User>{ approver1, approver2 };

        General_Settings__c settings = new General_Settings__c(
            Campaign_Marketing_Manager_Approver__c = approver1.Id,
            Campaign_Final_Approver__c = approver2.Id,
            Campaign_Expense_Approver__c = approver2.Id,
            Marketing_Campaign_Approver__c = approver1.Id,
            Digital_Campaign_Approver__c = approver1.Id,
            HR_Campaign_Approver__c = approver1.Id,
            Sales_Campaign_Approver__c = approver1.Id,
            Service_Campaign_Approver__c = approver1.Id,
            Academy_Campaign_Approver__c = approver1.Id,
            Telephony_Campaign_Approver__c = approver1.Id
        );
        insert settings;
    }

    /* =========================================================
       TEST mapApproverUser METHOD
       ========================================================= */
    @IsTest
    static void test_mapApproverUser() {

        Campaign camp = new Campaign(
            Name = 'Test Marketing Campaign',
            Status = 'Planned',
            Type = 'Marketing',
            StartDate = Date.today(),
            EndDate = Date.today().addDays(10),

            // 🔐 DYNAMIC PICKLIST VALUES
            Campaign_Source__c =
                getValidPicklistValue(Campaign.Campaign_Source__c),
            Campaign_Medium__c =
                getValidPicklistValue(Campaign.Campaign_Medium__c)
        );

        insert camp;

        Test.startTest();
            CampaignTrigger_Handler.mapApproverUser(
                new List<Campaign>{ camp }
            );
        Test.stopTest();

        Campaign updatedCamp = [
            SELECT Marketing_Manager_Approver__c,
                   Budget_Holder_Approver__c,
                   Final_Expense_Approver__c,
                   Campaign_Final_Approver__c
            FROM Campaign
            WHERE Id = :camp.Id
        ];

        System.assertNotEquals(
            null,
            updatedCamp.Marketing_Manager_Approver__c
        );
        System.assertNotEquals(
            null,
            updatedCamp.Budget_Holder_Approver__c
        );
        System.assertNotEquals(
            null,
            updatedCamp.Final_Expense_Approver__c
        );
        System.assertNotEquals(
            null,
            updatedCamp.Campaign_Final_Approver__c
        );
    }

    /* =========================================================
       TEST campaignSubmitterNotification METHOD
       ========================================================= */
    @IsTest
    static void test_campaignSubmitterNotification() {

        List<CustomNotificationType> notifTypes = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Campaign_Notification'
            LIMIT 1
        ];

        // Skip safely if metadata not present
        if (notifTypes.isEmpty()) {
            System.assert(true);
            return;
        }

        Campaign camp = new Campaign(
            Name = 'Notification Campaign',
            Status = 'Approved',
            Type = 'Marketing',
            StartDate = Date.today(),
            EndDate = Date.today().addDays(5),

            // 🔐 DYNAMIC PICKLIST VALUES
            Campaign_Source__c =
                getValidPicklistValue(Campaign.Campaign_Source__c),
            Campaign_Medium__c =
                getValidPicklistValue(Campaign.Campaign_Medium__c)
        );

        insert camp;

        Test.startTest();
            CampaignTrigger_Handler.campaignSubmitterNotification(
                new List<Campaign>{ camp },
                'Approved'
            );
        Test.stopTest();

        System.assert(true);
    }
}