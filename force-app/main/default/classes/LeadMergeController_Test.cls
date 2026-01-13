@IsTest
public class LeadMergeController_Test {

    /* =====================================================
       UTILITY: DYNAMIC PICKLIST VALUE (SAFE FOR RESTRICTED)
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

        String leadCategory =
            getValidPicklistValue(Lead.Lead_Category__c);
        String leadSource =
            getValidPicklistValue(Lead.LeadSource);

        List<Lead> leads = new List<Lead>();

        Lead l1 = new Lead(
            LastName = 'Test Lead One',
            Company = 'Test Company',
            Phone = '9876543210',
            MobilePhone = '9876543211',
            Email = 'lead1@test.com',
            Secondary_Email__c = 'lead1_alt@test.com',
            LeadSource = leadSource,
            Lead_Category__c = leadCategory
        );

        Lead l2 = new Lead(
            LastName = 'Test Lead Two',
            Company = 'Test Company',
            Phone = '9876543210',              // duplicate phone
            MobilePhone = '9876543212',
            Email = 'lead2@test.com',
            Secondary_Email__c = 'lead1@test.com', // duplicate email
            LeadSource = leadSource,
            Lead_Category__c = leadCategory
        );

        leads.add(l1);
        leads.add(l2);
        insert leads;
    }

    /* =====================================================
       TEST duplicateLeads
       ===================================================== */
    @IsTest
    static void test_duplicateLeads() {

        Lead testLead = [
            SELECT Id
            FROM Lead
            LIMIT 1
        ];

        Test.startTest();
            List<Lead> duplicates =
                LeadMergeController.duplicateLeads(testLead.Id);
        Test.stopTest();

        System.assertNotEquals(null, duplicates);
        System.assert(
            duplicates.size() > 0,
            'Duplicate leads should be found'
        );
    }

    /* =====================================================
       TEST fetchLeads
       ===================================================== */
    @IsTest
    static void test_fetchLeads() {

        List<Lead> leads = [
            SELECT Id
            FROM Lead
            LIMIT 2
        ];

        Test.startTest();
            LeadMergeController.LeadMergeWrapper wrapper =
                LeadMergeController.fetchLeads(
                    leads[0].Id,
                    leads[1].Id
                );
        Test.stopTest();

        System.assertNotEquals(null, wrapper);
        System.assertNotEquals(null, wrapper.firstLead);
        System.assertNotEquals(null, wrapper.secondLead);
        System.assert(wrapper.fieldset.size() > 0);
    }

    /* =====================================================
       TEST mergeLeads (FIXED QUERY)
       ===================================================== */
    @IsTest
    static void test_mergeLeads() {

        List<Lead> leads = [
            SELECT Id, Lead_ID__c, Email, Phone, MobilePhone,
                   Company, LeadSource, Lead_Category__c
            FROM Lead
            ORDER BY CreatedDate
            LIMIT 2
        ];

        Lead firstLead = leads[0];
        Lead secondLead = leads[1];

        Map<String, String> selectedFields = new Map<String, String>();

        // Principal lead selection (Lead_ID__c is read-only → queried)
        selectedFields.put(
            'Principal Record to Merge',
            'Use as principal (' + firstLead.Lead_ID__c + ')'
        );

        selectedFields.put('Email', firstLead.Email);
        selectedFields.put('Primary Contact Number', firstLead.Phone);
        selectedFields.put('Secondary Contact Number', firstLead.MobilePhone);
        selectedFields.put('Company/Institution', firstLead.Company);
        selectedFields.put('LeadSource', firstLead.LeadSource);
        selectedFields.put('Lead Category', firstLead.Lead_Category__c);

        Test.startTest();
            String masterId =
                LeadMergeController.mergeLeads(
                    firstLead,
                    secondLead,
                    selectedFields
                );
        Test.stopTest();

        System.assertNotEquals(
            null,
            masterId,
            'Master Lead Id should be returned'
        );
    }

    /* =====================================================
       TEST helper methods
       ===================================================== */
    @IsTest
    static void test_helperMethods() {

        System.assertEquals(
            'Email',
            LeadMergeController.getValidFieldNameApi('Email')
        );

        System.assertEquals(
            'Invalid option',
            LeadMergeController.getValidFieldNameApi('Invalid')
        );

        System.assertEquals(
            'LD-001',
            LeadMergeController.getCodeInsideBrackets(
                'Use as principal (LD-001)'
            )
        );
    }
}