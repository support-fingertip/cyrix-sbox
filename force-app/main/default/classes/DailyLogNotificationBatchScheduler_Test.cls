@IsTest
public class DailyLogNotificationBatchScheduler_Test {

    @IsTest
    static void testSchedulerExecution() {

        /* ----------------------------------------
           STEP 1: PREPARE REQUIRED TEST DATA
           (Only if your batch queries Daily_Log__c)
           ---------------------------------------- */
        Daily_Log__c dl = new Daily_Log__c(
            Day_started_Time__c = System.now(),
            Odometer_Starting_Kms__c = 100,
            Is_System_Ended__c = false
        );
        insert dl;

        /* ----------------------------------------
           STEP 2: SCHEDULE THE JOB
           ---------------------------------------- */
        String cronExp = '0 0 0 1 1 ? 2099'; // valid future cron

        Test.startTest();
        System.schedule(
            'DailyLogNotificationBatchScheduler_TestJob',
            cronExp,
            new DailyLogNotificationBatchScheduler()
        );
        Test.stopTest();

        /* ----------------------------------------
           STEP 3: ASSERT JOB WAS SCHEDULED
           ---------------------------------------- */
        CronTrigger ct = [
            SELECT Id, CronJobDetail.Name, State
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'DailyLogNotificationBatchScheduler_TestJob'
            LIMIT 1
        ];

        System.assertEquals(
            'WAITING',
            ct.State,
            'Scheduled job should be in WAITING state'
        );
    }
}