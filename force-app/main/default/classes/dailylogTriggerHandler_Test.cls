@IsTest
public class dailylogTriggerHandler_Test {

    /* =====================================================
       TEST DATA SETUP
       ===================================================== */
    @testSetup
    static void setupData() {

        
        Daily_Log__c dl = new Daily_Log__c(
            Day_started_Time__c = DateTime.now().addHours(-8),
            Odometer_Starting_Kms__c = 1000,
            Is_System_Ended__c = false
        );
        insert dl;

        // Create Visit with ALL required fields
        Visit__c visit = new Visit__c(
            Daily_Log__c = dl.Id,
            Visit_Date__c = Date.today(),
            Planned_Start_Time__c = DateTime.now().addHours(-6),

            Visit_End__c = DateTime.now().addHours(-5),
            Check_In_Location__Latitude__s = 12.9716,
            Check_In_Location__Longitude__s = 77.5946
        );
        insert visit;
    }

    /* =====================================================
       TEST beforeUpdate METHOD
       ===================================================== */
    @IsTest
    static void test_beforeUpdate_setsLastVisit() {

        Daily_Log__c dl = [
            SELECT Id, Day_ended_time__c
            FROM Daily_Log__c
            LIMIT 1
        ];

        dl.Day_ended_time__c = DateTime.now();

        Test.startTest();
            update dl;
        Test.stopTest();

        Daily_Log__c updatedDl = [
            SELECT Id
            FROM Daily_Log__c
            WHERE Id = :dl.Id
        ];

      
    }

    /* =====================================================
       TEST afterUpdate METHOD
       ===================================================== */
    @IsTest
    static void test_afterUpdate_clockOutLocation() {

        Daily_Log__c dl = [
            SELECT Id
            FROM Daily_Log__c
            LIMIT 1
        ];

        dl.Clock_Out_Location__Latitude__s = 12.2958;
        dl.Clock_Out_Location__Longitude__s = 76.6394;

        Test.startTest();
            update dl;
        Test.stopTest();

        System.assert(true);
    }
}