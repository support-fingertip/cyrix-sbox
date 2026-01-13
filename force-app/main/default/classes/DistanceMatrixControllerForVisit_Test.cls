@IsTest
public class DistanceMatrixControllerForVisit_Test {

    /* =====================================================
       TEST DATA SETUP
       ===================================================== */
    @testSetup
    static void setupData() {

        // Create Daily Log (with required fields)
        Daily_Log__c dl = new Daily_Log__c(
            Day_started_Time__c = DateTime.now().addHours(-8),
            Odometer_Starting_Kms__c = 1200,
            Is_System_Ended__c = false,
            Clock_In_Location__Latitude__s = 12.9716,
            Clock_In_Location__Longitude__s = 77.5946
        );
        insert dl;

        // Create FIRST Visit (earlier visit)
        Visit__c visit1 = new Visit__c(
            Daily_Log__c = dl.Id,
            Visit_Date__c = Date.today(),
            Planned_Start_Time__c = DateTime.now().addHours(-6),
            Visit_Start__c = DateTime.now().addHours(-6),
            Visit_End__c = DateTime.now().addHours(-5),
            Check_In_Location__Latitude__s = 12.9716,
            Check_In_Location__Longitude__s = 77.5946
        );
        insert visit1;

        // Create SECOND Visit (later visit)
        Visit__c visit2 = new Visit__c(
            Daily_Log__c = dl.Id,
            Visit_Date__c = Date.today(),
            Planned_Start_Time__c = DateTime.now().addHours(-3),
            Visit_Start__c = DateTime.now().addHours(-3),
            Visit_End__c = DateTime.now().addHours(-2),
            Check_In_Location__Latitude__s = 13.0827,
            Check_In_Location__Longitude__s = 80.2707
        );
        insert visit2;
    }

    /* =====================================================
       TEST distanceCalculation METHOD
       ===================================================== */
    @IsTest
    static void test_distanceCalculation() {

        List<Visit__c> visits = [
            SELECT Id FROM Visit__c
        ];

        List<String> visitIds = new List<String>();
        for (Visit__c v : visits) {
            visitIds.add(v.Id);
        }

        Test.startTest();
            DistanceMatrixControllerForVisit.distanceCalculation(visitIds);
        Test.stopTest();

        // Verify distance updated
        Visit__c updatedVisit = [
            SELECT Distance__c
            FROM Visit__c
            WHERE Distance__c != null
            LIMIT 1
        ];

        System.assert(
            updatedVisit.Distance__c > 0,
            'Distance should be calculated and populated'
        );
    }

    /* =====================================================
       TEST calculateHaversineDistance METHOD
       ===================================================== */
    @IsTest
    static void test_calculateHaversineDistance() {

        Decimal distance = DistanceMatrixControllerForVisit.calculateHaversineDistance(
            12.9716, 77.5946,   // Bangalore
            13.0827, 80.2707    // Chennai
        );

        System.assert(
            distance > 0,
            'Haversine distance should be greater than zero'
        );
    }
}