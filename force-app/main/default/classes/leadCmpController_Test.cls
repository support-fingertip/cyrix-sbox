@IsTest
public class leadCmpController_Test {

    /* =====================================================
       UTILITY: SAFE PICKLIST VALUE
       ===================================================== */
    private static String getValidPicklistValue(Schema.SObjectField fieldRef) {
        List<Schema.PicklistEntry> values =
            fieldRef.getDescribe().getPicklistValues();
        return values.isEmpty() ? null : values[0].getValue();
    }

    /* =====================================================
       TEST DATA SETUP
       ===================================================== */
    @testSetup
    static void setupData() {

        // Get valid State picklist value (ONLY for Region)
        String stateValue =
            getValidPicklistValue(Region__c.State__c);

        /* ---------- Region ---------- */
        Region__c region = new Region__c(
            Name = 'Test Region',
            State__c = stateValue       
        );
        insert region;

        /* ---------- Sub Region ---------- */
        Map_Sub_Region__c subRegion = new Map_Sub_Region__c(
            Name = 'Test Sub Region',
            Region__c = region.Id,
            Active__c = true            
        );
        insert subRegion;

        /* ---------- Lead ---------- */
        Lead ld = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Phone = '9876543210',
            Region__c = region.Id
        );
        insert ld;
    }

    /* =====================================================
       TEST fetchLead
       ===================================================== */
    @IsTest
    static void test_fetchLead() {

        Lead ld = [
            SELECT Id
            FROM Lead
            WHERE Region__c != null
            LIMIT 1
        ];

        Test.startTest();
            leadCmpController result =
                leadCmpController.fetchLead(ld.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.region);
        System.assert(result.subRegions.size() > 0);
    }

    /* =====================================================
       TEST fetchLead – NULL ID
       ===================================================== */
    @IsTest
    static void test_fetchLead_null() {

        Test.startTest();
            leadCmpController result =
                leadCmpController.fetchLead(null);
        Test.stopTest();

        System.assertEquals(null, result);
    }

    /* =====================================================
       TEST leadAssignment
       ===================================================== */
    @IsTest
    static void test_leadAssignment() {

        Lead ld = [
            SELECT Id, OwnerId
            FROM Lead
            LIMIT 1
        ];

        String newOwnerId = UserInfo.getUserId();

        Test.startTest();
            leadCmpController.leadAssignment(
                newOwnerId,
                ld.Id
            );
        Test.stopTest();

        Lead updatedLead = [
            SELECT OwnerId
            FROM Lead
            WHERE Id = :ld.Id
        ];

        System.assertEquals(newOwnerId, updatedLead.OwnerId);
    }
}