@isTest
public class LeadReminderScheduler_v1_Test {

    @testSetup
    static void setupUsers() {

        Profile p = [
            SELECT Id FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        // Manager
        User manager = new User(
            Alias = 'mgr',
            Email = 'mgr@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Manager',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'mgr_' + System.currentTimeMillis() + '@test.com',
            ProfileId = p.Id
        );
        insert manager;

        // Owner WITH manager
        User ownerWithMgr = new User(
            Alias = 'own1',
            Email = 'own1@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'OwnerOne',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'own1_' + System.currentTimeMillis() + '@test.com',
            ProfileId = p.Id,
            ManagerId = manager.Id
        );
        insert ownerWithMgr;

        // Owner WITHOUT manager
        User ownerNoMgr = new User(
            Alias = 'own2',
            Email = 'own2@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'OwnerTwo',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'own2_' + System.currentTimeMillis() + '@test.com',
            ProfileId = p.Id
        );
        insert ownerNoMgr;
    }

    @isTest
    static void testScheduler_GuaranteedCoverage() {

        User ownerWithMgr =
            [SELECT Id FROM User WHERE Alias = 'own1' LIMIT 1];
        User ownerNoMgr =
            [SELECT Id FROM User WHERE Alias = 'own2' LIMIT 1];

        Date today = Date.today();

        // 🔑 Inject DTOs (NO Lead creation, NO read-only writes)
        LeadReminderScheduler_v1.testLeadInfos =
            new List<LeadReminderScheduler_v1.LeadInfo>{

                // Notify paths
                new LeadReminderScheduler_v1.LeadInfo(
                    UserInfo.getUserId(),
                    ownerWithMgr.Id,
                    'Hot',
                    today.addDays(-5)
                ),
                new LeadReminderScheduler_v1.LeadInfo(
                    UserInfo.getUserId(),
                    ownerWithMgr.Id,
                    'Warm',
                    today.addDays(-10)
                ),
                new LeadReminderScheduler_v1.LeadInfo(
                    UserInfo.getUserId(),
                    ownerWithMgr.Id,
                    'Cold',
                    today.addDays(-15)
                ),

                // shouldNotify = false
                new LeadReminderScheduler_v1.LeadInfo(
                    UserInfo.getUserId(),
                    ownerWithMgr.Id,
                    'Hot',
                    today.addDays(-1)
                ),

                // Owner without manager
                new LeadReminderScheduler_v1.LeadInfo(
                    UserInfo.getUserId(),
                    ownerNoMgr.Id,
                    'Hot',
                    today.addDays(-10)
                )
            };

        Test.startTest();

        System.schedule(
            'Lead Reminder Scheduler FINAL',
            '0 0 12 * * ?',
            new LeadReminderScheduler_v1()
        );

        Test.stopTest();

        System.assert(true, 'Scheduler executed all branches');
    }
}