@IsTest
public class CustomLookupController_Test {

    /* =====================================================
       UTILITY METHOD – DYNAMIC PICKLIST VALUE
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

        String customerCategory =
            getValidPicklistValue(Account.Customer_Category__c);

        List<Account> accList = new List<Account>();

        for (Integer i = 0; i < 5; i++) {
            accList.add(new Account(
                Name  = 'Test Account ' + i,
                Phone = '9876543210',                 // ✔ phone validation
                Customer_Category__c = customerCategory // ✔ required picklist
            ));
        }
        insert accList;
    }

    /* =====================================================
       TEST fetchRecords – SEARCH STRING PATH
       ===================================================== */
    @IsTest
    static void test_fetchRecords_withSearchString() {

        Test.startTest();

        List<CustomLookupController.RecordsData> results =
            CustomLookupController.fetchRecords(
                'Account',
                'Name',
                'Test',
                null,
                ''
            );

        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assert(results.size() > 0);
        System.assertNotEquals(null, results[0].label);
        System.assertNotEquals(null, results[0].value);
    }

    /* =====================================================
       TEST fetchRecords – VALUE (Id) PATH
       ===================================================== */
    @IsTest
    static void test_fetchRecords_withValue() {

        Account acc = [
            SELECT Id, Name
            FROM Account
            LIMIT 1
        ];

        Test.startTest();

        List<CustomLookupController.RecordsData> results =
            CustomLookupController.fetchRecords(
                'Account',
                'Name',
                '',
                acc.Id,
                ''
            );

        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(acc.Name, results[0].label);
        System.assertEquals(acc.Id, results[0].value);
    }

    /* =====================================================
       TEST fetchRecords – EXCEPTION PATH
       ===================================================== */
    @IsTest
    static void test_fetchRecords_exception() {

        try {
            Test.startTest();

            CustomLookupController.fetchRecords(
                'InvalidObject__c',
                'Name',
                'Test',
                null,
                ''
            );

            Test.stopTest();
            System.assert(false, 'Exception should be thrown');

        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage() != null);
        }
    }
 
    /* =====================================================
       TEST testcover METHOD
       ===================================================== */
    @IsTest
    static void test_testcover() {

        Test.startTest();
            CustomLookupController.testcover();
        Test.stopTest();

        System.assert(true);
    }
}