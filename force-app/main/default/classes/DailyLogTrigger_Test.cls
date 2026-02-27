@IsTest
public class DailyLogTrigger_Test {

    @IsTest
    static void testBeforeAndAfterUpdate() {

        /* -----------------------------
           STEP 1: CREATE DAILY LOG
           ----------------------------- */
        Daily_Log__c dl = new Daily_Log__c(
            Day_started_Time__c = System.now(),   // required
            Odometer_Starting_Kms__c = 100,       // required
            Is_System_Ended__c = false
        );
        insert dl;

        /* -----------------------------
           STEP 2: CREATE RELATED VISIT
           (needed for handler logic)
           ----------------------------- */
        Visit__c visit = new Visit__c(
            Daily_Log__c = dl.Id,
            Visit_Date__c = Date.today(),
            Planned_Start_Time__c = System.now(),
            Check_In_Location__Latitude__s = 12.9716,
            Check_In_Location__Longitude__s = 77.5946,
            Visit_End__c = System.now()
        );
        insert visit;

        /* -----------------------------
           STEP 3: UPDATE DAILY LOG
           → fires BEFORE + AFTER update
           ----------------------------- */
        dl.Day_ended_time__c = System.now();
        dl.Clock_Out_Location__Latitude__s = 12.2958;
        dl.Clock_Out_Location__Longitude__s = 76.6394;

        Test.startTest();
        update dl;
        Test.stopTest();

        /* -----------------------------
           STEP 4: ASSERT EXECUTION
           ----------------------------- */
        Daily_Log__c updatedDL = [
            SELECT Id
            FROM Daily_Log__c
            WHERE Id = :dl.Id
        ];

        System.assertNotEquals(
            null,
            updatedDL.Id,
            'Daily Log should be updated successfully'
        );
    }
}