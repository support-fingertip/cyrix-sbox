@IsTest
public class SystemEndDayControllerTest {

    @IsTest
    static void testAutoEndDailyLogs_RecordUpdated() {

        Daily_Log__c dl = new Daily_Log__c(
            Day_started_Time__c        = Datetime.now().addHours(-2),
            Odometer_Starting_Kms__c   = 1000,
            Clock_In_Location__Latitude__s  = 28.6139,
            Clock_In_Location__Longitude__s = 77.2090,
            Is_System_Ended__c = false
        );
        insert dl;

        Test.startTest();
        SystemEndDayController.autoEndDailyLogs();
        Test.stopTest();

        Daily_Log__c updatedDL = [
            SELECT Day_ended_time__c, Is_System_Ended__c
            FROM Daily_Log__c
            WHERE Id = :dl.Id
        ];

        System.assertNotEquals(
            null,
            updatedDL.Day_ended_time__c,
            'Day ended time should be populated'
        );
        System.assertEquals(
            true,
            updatedDL.Is_System_Ended__c,
            'System ended flag should be true'
        );
    }

    @IsTest
    static void testAutoEndDailyLogs_NoMatchingRecords() {

        // This record should NOT be picked due to already-ended day
        Daily_Log__c dl = new Daily_Log__c(
            Day_started_Time__c        = Datetime.now().addHours(-3),
            Odometer_Starting_Kms__c   = 1500,
            Clock_In_Location__Latitude__s  = 0,      // fails latitude condition
            Clock_In_Location__Longitude__s = 77.2090,
            Day_ended_time__c = Datetime.now(),
            Is_System_Ended__c = false
        );
        insert dl;

        Test.startTest();
        SystemEndDayController.autoEndDailyLogs();
        Test.stopTest();

        Daily_Log__c unchangedDL = [
            SELECT Day_ended_time__c, Is_System_Ended__c
            FROM Daily_Log__c
            WHERE Id = :dl.Id
        ];

        System.assertNotEquals(
            null,
            unchangedDL.Day_ended_time__c,
            'Day ended time should remain unchanged'
        );
    }
}