@IsTest
public class CalculateDistanceAPITest {

    /* ============================================================
       GOOGLE DISTANCE MATRIX MOCK
       ============================================================ */
    class GoogleDistanceMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{"rows":[{"elements":[{"distance":{"text":"5 km","value":5000},"duration":{"text":"10 mins","value":600}}]}]}'
            );
            return res;
        }
    }

    /* ============================================================
       TEST DATA SETUP
       ============================================================ */
    @TestSetup
    static void setupData() {

        Daily_Log__c dl = new Daily_Log__c(
            Day_started_Time__c = System.now(),
            Odometer_Starting_Kms__c = 1200,
            Clock_In_Location__Latitude__s = 28.6139,
            Clock_In_Location__Longitude__s = 77.2090,
            Clock_Out_Location__Latitude__s = 28.7041,
            Clock_Out_Location__Longitude__s = 77.1025
        );
        insert dl;

        Date today = Date.today();

        Visit__c v1 = new Visit__c(
            Daily_Log__c = dl.Id,
            Status__c = 'Completed',
            Visit_Date__c = today,
            Planned_Start_Time__c =
                DateTime.newInstance(today, Time.newInstance(10, 0, 0, 0)),
            Visit_Start__c = System.now(),
            Check_In_Location__Latitude__s = 28.5355,
            Check_In_Location__Longitude__s = 77.3910
        );

        Visit__c v2 = new Visit__c(
            Daily_Log__c = dl.Id,
            Status__c = 'Completed',
            Visit_Date__c = today,
            Planned_Start_Time__c =
                DateTime.newInstance(today, Time.newInstance(12, 0, 0, 0)),
            Visit_Start__c = System.now().addHours(1),
            Check_In_Location__Latitude__s = 28.4595,
            Check_In_Location__Longitude__s = 77.0266
        );

        insert new List<Visit__c>{ v1, v2 };
    }

    /* ============================================================
       TEST GOOGLE API FUTURE METHOD
       ============================================================ */
    @IsTest
    static void testDistanceCalculation_Google() {

        Daily_Log__c dl = [SELECT Id FROM Daily_Log__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new GoogleDistanceMock());

        Test.startTest();
            CalculateDistanceAPI.distanceCalculation(
                new List<String>{ dl.Id }
            );
        Test.stopTest();

        // ---- VERIFY VISITS UPDATED ----
        List<Visit__c> visits = [
            SELECT Distance__c, Distance_Calculated_by_Google_API__c
            FROM Visit__c
            WHERE Daily_Log__c = :dl.Id
        ];

        Boolean distanceUpdated = false;
        for (Visit__c v : visits) {
            if (v.Distance_Calculated_by_Google_API__c) {
                distanceUpdated = true;
                System.assert(v.Distance__c >= 0);
            }
        }

        System.assertEquals(
            true,
            distanceUpdated,
            'At least one visit should have Google distance calculated'
        );

        // ---- VERIFY LOGS CREATED ----
        System.assert(
            [SELECT COUNT() FROM log__c] > 0,
            'Log records must be inserted'
        );
    }

    /* ============================================================
       TEST SALESFORCE HAVERSINE DISTANCE METHOD
       ============================================================ */
    @IsTest
    static void testDistanceCalculation_SF() {

        Daily_Log__c dl = [SELECT Id FROM Daily_Log__c LIMIT 1];

        Test.startTest();
            CalculateDistanceAPI.distanceCalculationSF(
                new List<String>{ dl.Id }
            );
        Test.stopTest();

        // ---- VERIFY VISITS UPDATED ----
        List<Visit__c> visits = [
            SELECT SF_Distance__c, Distance_Calculated_by_SF__c
            FROM Visit__c
            WHERE Daily_Log__c = :dl.Id
        ];

        Boolean sfDistanceUpdated = false;
        for (Visit__c v : visits) {
            if (v.Distance_Calculated_by_SF__c) {
                sfDistanceUpdated = true;
                System.assert(v.SF_Distance__c >= 0);
            }
        }

        System.assertEquals(
            true,
            sfDistanceUpdated,
            'At least one visit should have SF distance calculated'
        );
    }

    /* ============================================================
       TEST UTILITY HAVERSINE METHOD
       ============================================================ */
    @IsTest
    static void testHaversineUtility() {

        Decimal dist = CalculateDistanceAPI.calculateHaversineDistance(
            28.6139, 77.2090,
            28.7041, 77.1025
        );

        System.assert(dist > 0);
    }
}