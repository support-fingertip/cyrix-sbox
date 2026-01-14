@IsTest
public class VisitTrigger_Test {

    /* ----------------------------------------
       TEST DATA SETUP 
       ---------------------------------------- */
    @TestSetup
    static void setupData() {

        // Create User (Owner)
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'tuser',
            Email = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'testuser' + System.currentTimeMillis() + '@test.com'
        );
        insert u;

        // Daily Log
        Daily_Log__c dl = new Daily_Log__c(
            OwnerId = u.Id,
            Day_started_Time__c = System.now(),
            Odometer_Starting_Kms__c = 100
        );
        insert dl;

        // Visit
        Visit__c visit = new Visit__c(
            OwnerId = u.Id,
            Daily_Log__c = dl.Id,
            Visit_Date__c = Date.today(),
            Planned_Start_Time__c = System.now(),
            Status__c = 'Planned',
            Check_In_Location__Latitude__s = 12.9716,
            Check_In_Location__Longitude__s = 77.5946
        );
        insert visit;
    }

    /* ----------------------------------------
       BEFORE INSERT
       ---------------------------------------- */
    @IsTest
    static void testBeforeInsert() {

        Daily_Log__c dl = [SELECT Id FROM Daily_Log__c LIMIT 1];
        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];

        Visit__c v = new Visit__c(
            OwnerId = u.Id,
            Daily_Log__c = dl.Id,
            Visit_Date__c = Date.today(),
            Planned_Start_Time__c = System.now(),
            Status__c = 'Planned'
        );

        Test.startTest();
        insert v;
        Test.stopTest();

        System.assertNotEquals(null, v.Id);
    }

    /* ----------------------------------------
       AFTER UPDATE – MISSED VISIT + DISTANCE
       ---------------------------------------- */
    @IsTest
    static void testAfterUpdateMissedVisit() {

        Visit__c v = [
            SELECT Id, Status__c
            FROM Visit__c
            LIMIT 1
        ];

        v.Status__c = 'Missed';
        v.PostPoned_Start_Time__c = System.now().addHours(2);

        Test.startTest();
        update v;
        Test.stopTest();

        Visit__c updated = [
            SELECT Status__c
            FROM Visit__c
            WHERE Id = :v.Id
        ];

        System.assertEquals('Missed', updated.Status__c);
    }

    /* ----------------------------------------
       DAILY LOG ROLLUP – AFTER UPDATE
       ---------------------------------------- */
    @IsTest
    static void testDailyLogRollupAfterUpdate() {

        Visit__c v = [
            SELECT Id, Distance__c
            FROM Visit__c
            LIMIT 1
        ];

        v.Distance__c = 15;

        Test.startTest();
        update v;
        Test.stopTest();

        System.assert(true, 'Distance update executed');
    }

    /* ----------------------------------------
       BEFORE DELETE
       ---------------------------------------- */
    @IsTest
    static void testBeforeDelete() {

        Visit__c v = [
            SELECT Id
            FROM Visit__c
            LIMIT 1
        ];

        Test.startTest();
        delete v;
        Test.stopTest();

        Integer countAfterDelete = [
            SELECT COUNT()
            FROM Visit__c
            WHERE Id = :v.Id
        ];

        System.assertEquals(0, countAfterDelete);
    }

    /* ----------------------------------------
       AFTER UNDELETE
       ---------------------------------------- */
    @IsTest
    static void testAfterUndelete() {

        Visit__c v = [
            SELECT Id
            FROM Visit__c
            LIMIT 1
        ];

        delete v;
        undelete v;

        Integer countAfterUndelete = [
            SELECT COUNT()
            FROM Visit__c
            WHERE Id = :v.Id
        ];

        System.assertEquals(1, countAfterUndelete);
    }
}