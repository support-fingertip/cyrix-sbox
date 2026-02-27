@IsTest
public class FileControllerTest {
    
    @IsTest
    static void testSaveFile() {
        // Create test data
        Account testAccount = new Account(Name = 'Test Account',phone='7234567867',customer_category__c='Exporters');
        insert testAccount;
        
        // Generate test base64 data (simple PNG header)
        String base64Data = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==';
        String fileName = 'test.png';
        String uniqueId = 'test-unique-id-123';
        
        Test.startTest();
        
        // Test with uniqueId
        String contentDocId1 = FileController.saveFile(
            testAccount.Id, 
            fileName, 
            base64Data, 
            uniqueId
        );
        
        // Test without uniqueId (null)
        String contentDocId2 = FileController.saveFile(
            testAccount.Id, 
            'test2.png', 
            base64Data, 
            null
        );
        
        // Test without uniqueId (empty string)
        String contentDocId3 = FileController.saveFile(
            testAccount.Id, 
            'test3.png', 
            base64Data, 
            ''
        );
        
        Test.stopTest();
        
        // No assertions required as per instructions
    }
    
    @IsTest
    static void testSaveFileWithException() {
        // Create test data
        Account testAccount = new Account(Name = 'Test Account',phone='1234567867',customer_category__c='Exporters');
        insert testAccount;
        
        // Use invalid base64 data to trigger exception
        String invalidBase64Data = 'invalid-base64-data';
        String fileName = 'test.png';
        String uniqueId = 'test-unique-id-123';
        
        Test.startTest();
        
        try {
            // This should throw an exception
            String contentDocId = FileController.saveFile(
                testAccount.Id, 
                fileName, 
                invalidBase64Data, 
                uniqueId
            );
        } catch (Exception e) {
            // Exception is expected - no assertion needed
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testSaveFileDuplicateLink() {
        // Create test data
        Account testAccount = new Account(Name = 'Test Account',phone='1234567867',customer_category__c='Exporters');
        insert testAccount;
        
        String base64Data = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==';
        String fileName = 'test.png';
        String uniqueId = 'test-unique-id-123';
        
        Test.startTest();
        
        // First upload
        String contentDocId1 = FileController.saveFile(
            testAccount.Id, 
            fileName, 
            base64Data, 
            uniqueId
        );
        
        // Second upload with same parent ID to test duplicate link prevention
        String contentDocId2 = FileController.saveFile(
            testAccount.Id, 
            'another-test.png', 
            base64Data, 
            'another-unique-id'
        );
        
        Test.stopTest();
    }
    
    @IsTest
    static void testSaveFileWithDifferentParent() {
        // Create multiple test accounts
        Account testAccount1 = new Account(Name = 'Test Account 1',phone='1234567867',customer_category__c='Exporters');
        Account testAccount2 = new Account(Name = 'Test Account 2',phone='1234567867',customer_category__c='Exporters');
        insert new List<Account>{testAccount1, testAccount2};
        
        String base64Data = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==';
        String fileName = 'test.png';
        String uniqueId = 'test-unique-id-123';
        
        Test.startTest();
        
        // Upload to first account
        String contentDocId1 = FileController.saveFile(
            testAccount1.Id, 
            fileName, 
            base64Data, 
            uniqueId
        );
        
        // Upload to second account
        String contentDocId2 = FileController.saveFile(
            testAccount2.Id, 
            fileName, 
            base64Data, 
            uniqueId
        );
        
        Test.stopTest();
    }
}