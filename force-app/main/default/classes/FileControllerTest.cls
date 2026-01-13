@IsTest
public class FileControllerTest {

    // Helper to fetch valid picklist value
    private static String getPicklistValue(String obj, String field) {
        return Schema.getGlobalDescribe()
            .get(obj)
            .getDescribe()
            .fields.getMap()
            .get(field)
            .getDescribe()
            .getPicklistValues()[0]
            .getValue();
    }

    @IsTest
    static void testSaveFile_WithUniqueId() {

        Account acc = new Account(
            Name = 'Test Account',
            Phone = '9876543210',
            Customer_Category__c =
                getPicklistValue('Account', 'Customer_Category__c')
        );
        insert acc;

        String base64Data =
            EncodingUtil.base64Encode(Blob.valueOf('Test File'));

        Test.startTest();
        String docId = FileController.saveFile(
            acc.Id,
            'Store.jpg',
            base64Data,
            'UNIQ001'
        );
        Test.stopTest();

        System.assertNotEquals(null, docId);
    }

    @IsTest
    static void testSaveFile_WithoutUniqueId() {

        Account acc = new Account(
            Name = 'Test Account 2',
            Phone = '9123456789',
            Customer_Category__c =
                getPicklistValue('Account', 'Customer_Category__c')
        );
        insert acc;

        String base64Data =
            EncodingUtil.base64Encode(Blob.valueOf('Another File'));

        Test.startTest();
        String docId = FileController.saveFile(
            acc.Id,
            'Store2.png',
            base64Data,
            null
        );
        Test.stopTest();

        System.assertNotEquals(null, docId);
    }

    @IsTest
    static void testSaveFile_ExceptionPath() {

        Account acc = new Account(
            Name = 'Test Account 3',
            Phone = '9998887776',
            Customer_Category__c =
                getPicklistValue('Account', 'Customer_Category__c')
        );
        insert acc;

        Test.startTest();
        try {
            FileController.saveFile(
                acc.Id,
                'Invalid.png',
                'INVALID_BASE64',
                'ERR'
            );
            System.assert(false, 'Exception expected');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Error saving file'));
        }
        Test.stopTest();
    }
}