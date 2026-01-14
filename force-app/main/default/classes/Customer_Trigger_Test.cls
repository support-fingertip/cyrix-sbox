@IsTest
public class Customer_Trigger_Test {

    // Utility to get picklist values
    private static List<Schema.PicklistEntry> getPicklistValues(String fieldApi) {
        return Account.SObjectType
            .getDescribe()
            .fields.getMap()
            .get(fieldApi)
            .getDescribe()
            .getPicklistValues();
    }

    @IsTest
    static void testApprovalStatusClearedOnStatusChangeFromInactive() {

        // Step 1: Get Status__c picklist values
        List<Schema.PicklistEntry> statusValues = getPicklistValues('Status__c');

        String inactiveStatus;
        String newStatus;

        // Find 'Inactive' and another valid value
        for (Schema.PicklistEntry pe : statusValues) {
            if (pe.getValue() == 'Inactive') {
                inactiveStatus = pe.getValue();
            } else if (newStatus == null) {
                newStatus = pe.getValue();
            }
        }

        // Safety check (prevents false failures)
        System.assertNotEquals(
            null,
            inactiveStatus,
            'Inactive must exist as a Status__c picklist value'
        );

        // Step 2: Create Account with Status = Inactive
        Account acc = new Account(
            Name = 'Test Customer',
            Status__c = inactiveStatus,
            Approval_Status__c = 'Approved',
            Phone = '9999999999',
            Customer_Category__c = Account.SObjectType
                .getDescribe()
                .fields.getMap()
                .get('Customer_Category__c')
                .getDescribe()
                .getPicklistValues()[0]
                .getValue()
        );
        insert acc;

        // Step 3: Update status to a different value
        Test.startTest();
            acc.Status__c = newStatus;
            update acc;
        Test.stopTest();

        // Step 4: Verify Approval_Status__c is cleared
        Account updatedAcc = [
            SELECT Status__c, Approval_Status__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals(
            null,
            updatedAcc.Approval_Status__c,
            'Approval_Status__c must be cleared when status changes from Inactive'
        );
    }
}