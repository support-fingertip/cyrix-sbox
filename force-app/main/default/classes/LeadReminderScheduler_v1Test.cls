@IsTest
public class LeadReminderScheduler_v1Test {

    @testSetup
    static void setupData() {

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User manager = new User(
            FirstName = 'Test',
            LastName  = 'Manager',
            Email     = 'manager@test.com',
            Username  = 'manager' + System.currentTimeMillis() + '@test.com',
            Alias     = 'mngr',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert manager;

        User owner = new User(
            FirstName = 'Test',
            LastName  = 'Owner',
            Email     = 'owner@test.com',
            Username  = 'owner' + System.currentTimeMillis() + '@test.com',
            Alias     = 'ownr',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            ManagerId = manager.Id
        );
        insert owner;

        Date today = Date.today();

        List<Lead> leads = new List<Lead>();

        leads.add(new Lead(
            LastName = 'Hot Lead',
            Company = 'Test',
            OwnerId = owner.Id,
            Phone = '9000000001',
            purchaseDate__c = today.addDays(-10),
            PurchaseDate_Last_Updated__c = today.addDays(-3),
            Last_Activity_Date__c = today.addDays(-5),
            Hot_Notification_Sent__c = false,
            Warm_Notification_Sent__c = false,
            Cold_Notification_Sent__c = false
        ));

        leads.add(new Lead(
            LastName = 'Warm Lead',
            Company = 'Test',
            OwnerId = owner.Id,
            Phone = '9000000002',
            purchaseDate__c = today.addDays(-40),
            PurchaseDate_Last_Updated__c = today.addDays(-7),
            Last_Activity_Date__c = today.addDays(-10),
            Hot_Notification_Sent__c = true,
            Warm_Notification_Sent__c = false,
            Cold_Notification_Sent__c = false
        ));

        leads.add(new Lead(
            LastName = 'Cold Lead',
            Company = 'Test',
            OwnerId = owner.Id,
            Phone = '9000000003',
            purchaseDate__c = today.addDays(-70),
            PurchaseDate_Last_Updated__c = today.addDays(-10),
            Last_Activity_Date__c = today.addDays(-20),
            Hot_Notification_Sent__c = true,
            Warm_Notification_Sent__c = true,
            Cold_Notification_Sent__c = false
        ));

        insert leads;
    }

   @IsTest
static void testExecute_updatesFlags() {

    Date today = Date.today();

    // Update leads so they match exact conditions required in scheduler
    List<Lead> leads = [
        SELECT Id, Lead_Rating__c,
               PurchaseDate_Last_Updated__c, Last_Activity_Date__c,
               Hot_Notification_Sent__c, Warm_Notification_Sent__c, Cold_Notification_Sent__c
        FROM Lead
        WHERE LastName IN ('Hot Lead','Warm Lead','Cold Lead')
    ];

    for (Lead l : leads) {
        if (l.Lead_Rating__c == '🔴 Hot') {
            l.PurchaseDate_Last_Updated__c = today.addDays(-3);
            l.Last_Activity_Date__c = today.addDays(-10);
            l.Hot_Notification_Sent__c = false;
        }
        if (l.Lead_Rating__c == '🟠 Warm') {
            l.PurchaseDate_Last_Updated__c = today.addDays(-7);
            l.Last_Activity_Date__c = today.addDays(-20);
            l.Warm_Notification_Sent__c = false;
        }
        if (l.Lead_Rating__c == '🔵 Cold') {
            l.PurchaseDate_Last_Updated__c = today.addDays(-10);
            l.Last_Activity_Date__c = today.addDays(-30);
            l.Cold_Notification_Sent__c = false;
        }
    }
    update leads;

    Test.startTest();
    new LeadReminderScheduler_v1().execute(null);
    Test.stopTest();

    Lead hot = [
        SELECT Hot_Notification_Sent__c
        FROM Lead
        WHERE Lead_Rating__c = '🔴 Hot'
        LIMIT 1
    ];
    System.assertEquals(true, hot.Hot_Notification_Sent__c);

    Lead warm = [
        SELECT Warm_Notification_Sent__c
        FROM Lead
        WHERE Lead_Rating__c = '🟠 Warm'
        LIMIT 1
    ];
    System.assertEquals(true, warm.Warm_Notification_Sent__c);

    Lead cold = [
        SELECT Cold_Notification_Sent__c
        FROM Lead
        WHERE Lead_Rating__c = '🔵 Cold'
        LIMIT 1
    ];
    System.assertEquals(true, cold.Cold_Notification_Sent__c);
}

    @IsTest
    static void testScheduleJob() {

        Test.startTest();
        System.schedule(
            'LeadReminderScheduler_v1 Job',
            '0 0 0 1 1 ? 2099',
            new LeadReminderScheduler_v1()
        );
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT count() FROM CronTrigger WHERE CronJobDetail.Name = 'LeadReminderScheduler_v1 Job']
        );
    }
}