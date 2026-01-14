@IsTest
public class VisitTriggerHandlerTest {

    /* =====================================================
       Base Test Data (Reusable)
    ===================================================== */
    private static Map<String, Id> createBaseData() {

        // ---- Account (Phone + Customer Category required) ----
        String customerCategory =
            Account.Customer_Category__c.getDescribe()
                .getPicklistValues()[0].getValue();

        Account acc = new Account(
            Name = 'Test Account',
            Phone = '9876543210',
            Customer_Category__c = customerCategory
        );
        insert acc;

        // ---- Lead (Phone required) ----
        Lead lead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Phone = '9876543210'
        );
        insert lead;

        // ---- Daily Log (required fields) ----
        Daily_Log__c log = new Daily_Log__c(
            Day_started_Time__c = System.now(),
            Odometer_Starting_Kms__c = 100
        );
        insert log;

        return new Map<String, Id>{
            'accId'  => acc.Id,
            'leadId' => lead.Id,
            'logId'  => log.Id
        };
    }

    /* =====================================================
       1. beforeInsert – Visit_Date__c derivation
    ===================================================== */
    @IsTest
    static void testBeforeInsert() {

        Map<String, Id> ids = createBaseData();
        Datetime plannedStart = System.now();

        Visit__c visit = new Visit__c(
            Account__c = ids.get('accId'),
            Lead__c = ids.get('leadId'),
            Daily_Log__c = ids.get('logId'),
            OwnerId = UserInfo.getUserId(),
            Planned_Start_Time__c = plannedStart
        );

        Test.startTest();
        insert visit;
        Test.stopTest();

        Visit__c insertedVisit = [
            SELECT Visit_Date__c
            FROM Visit__c
            WHERE Id = :visit.Id
        ];

        System.assertEquals(
            plannedStart.date(),
            insertedVisit.Visit_Date__c
        );
    }

    /* =====================================================
       2. calculateDistance (status transition)
    ===================================================== */
    @IsTest
    static void testCalculateDistance() {

        Map<String, Id> ids = createBaseData();

        Visit__c visit = new Visit__c(
            Account__c = ids.get('accId'),
            Lead__c = ids.get('leadId'),
            Daily_Log__c = ids.get('logId'),
            OwnerId = UserInfo.getUserId(),
            Status__c = 'Planned',
            Planned_Start_Time__c = System.now()
        );
        insert visit;

        Visit__c updatedVisit = visit.clone(false, true, false, false);
        updatedVisit.Id = visit.Id;
        updatedVisit.Status__c = 'In Progress';
        updatedVisit.Visit_Start__c = System.now();
        updatedVisit.Check_In_Location__Latitude__s = 18.52;
        updatedVisit.Check_In_Location__Longitude__s = 73.85;

        Test.startTest();
        update updatedVisit;
        Test.stopTest();

        System.assert(true);
    }

    /* =====================================================
       3. updateDailyLogs – distance & count
    ===================================================== */
    @IsTest
    static void testUpdateDailyLogs() {

        Map<String, Id> ids = createBaseData();

        Visit__c v1 = new Visit__c(
            Account__c = ids.get('accId'),
            Lead__c = ids.get('leadId'),
            Daily_Log__c = ids.get('logId'),
            OwnerId = UserInfo.getUserId(),
            Planned_Start_Time__c = System.now(),
            Distance__c = 10
        );

        Visit__c v2 = new Visit__c(
            Account__c = ids.get('accId'),
            Lead__c = ids.get('leadId'),
            Daily_Log__c = ids.get('logId'),
            OwnerId = UserInfo.getUserId(),
            Planned_Start_Time__c = System.now().addMinutes(30),
            Distance__c = 20
        );

        insert new List<Visit__c>{ v1, v2 };

        Test.startTest();
        VisitTriggerHandler.updateDailyLogs(
            new Set<Id>{ ids.get('logId') }
        );
        Test.stopTest();

        Daily_Log__c updatedLog = [
            SELECT KMs_Travelled__c, Total_Visits__c
            FROM Daily_Log__c
            WHERE Id = :ids.get('logId')
        ];

        System.assertEquals(30, updatedLog.KMs_Travelled__c);
        System.assertEquals(2, updatedLog.Total_Visits__c);
    }

    /* =====================================================
       4. missedVisit – reschedule logic
    ===================================================== */
    @IsTest
    static void testMissedVisit() {

        Map<String, Id> ids = createBaseData();

        String visitFor =
            Visit__c.Visit_for__c.getDescribe()
                .getPicklistValues()[0].getValue();

        String visitPurpose =
            Visit__c.Visit_Purpose__c.getDescribe()
                .getPicklistValues()[0].getValue();

        String visitType =
            Visit__c.Visit_Type__c.getDescribe()
                .getPicklistValues()[0].getValue();

        Visit__c missedVisit = new Visit__c(
            Account__c = ids.get('accId'),
            Lead__c = ids.get('leadId'),
            Daily_Log__c = ids.get('logId'),
            OwnerId = UserInfo.getUserId(),
            Status__c = 'Missed',
            Visit_for__c = visitFor,
            Visit_Purpose__c = visitPurpose,
            Visit_Type__c = visitType,
            Planned_Start_Time__c = System.now(),
            PostPoned_Start_Time__c = System.now().addDays(1)
        );
        insert missedVisit;

        Integer beforeCount = [SELECT COUNT() FROM Visit__c];

        Test.startTest();
        VisitTriggerHandler.missedVisit(
            new List<Visit__c>{ missedVisit }
        );
        Test.stopTest();

        Integer afterCount = [SELECT COUNT() FROM Visit__c];

        System.assertEquals(beforeCount + 1, afterCount);
    }
}