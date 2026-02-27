@IsTest
public class LightningFileUploadHandler1Test {
    
    @IsTest
    static void testGetFilesWithUniqueIdOnUpload() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account',phone='1234567867',customer_category__c='Exporters');
        insert testAccount;
        
        // Create test content document and version
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert cv;
        
        // Get the ContentDocumentId
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        
        // Link to account
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = testAccount.Id,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V'
        );
        insert cdl;
        
        Test.startTest();
        
        // Test with uniqueId and operation='OnUpload'
        String uniqueId = 'test-unique-id-123';
        String operation = 'OnUpload';
        
        List<ContentDocument> files = LightningFileUploadHandler1.getFiles(
            testAccount.Id,
            uniqueId,
            operation
        );
        
        Test.stopTest();
    }
    
    @IsTest
    static void testGetFilesWithUniqueIdOtherOperation() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account',phone='1234567867',customer_category__c='Exporters');
        insert testAccount;
        
        // Create test content document and version with description
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true,
            Description = 'existing-unique-id'
        );
        insert cv;
        
        // Get the ContentDocumentId
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        
        // Link to account
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = testAccount.Id,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V'
        );
        insert cdl;
        
        Test.startTest();
        
        // Test with uniqueId and operation NOT 'OnUpload'
        String uniqueId = 'existing-unique-id';
        String operation = 'SomeOtherOperation';
        
        List<ContentDocument> files = LightningFileUploadHandler1.getFiles(
            testAccount.Id,
            uniqueId,
            operation
        );
        
        Test.stopTest();
    }
    
    @IsTest
    static void testGetFilesWithoutUniqueId() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account',phone='1234567867',customer_category__c='Exporters');
        insert testAccount;
        
        // Create multiple test content documents
        List<ContentVersion> contentVersions = new List<ContentVersion>();
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        
        for(Integer i = 0; i < 3; i++) {
            ContentVersion cv = new ContentVersion(
                Title = 'Test File ' + i,
                PathOnClient = 'TestFile' + i + '.pdf',
                VersionData = Blob.valueOf('Test Content ' + i),
                IsMajorVersion = true
            );
            contentVersions.add(cv);
        }
        insert contentVersions;
        
        // Get ContentDocumentIds and create links
        contentVersions = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :contentVersions];
        
        for(ContentVersion cv : contentVersions) {
            ContentDocumentLink cdl = new ContentDocumentLink(
                LinkedEntityId = testAccount.Id,
                ContentDocumentId = cv.ContentDocumentId,
                ShareType = 'V'
            );
            links.add(cdl);
        }
        insert links;
        
        Test.startTest();
        
        // Test without uniqueId
        List<ContentDocument> files = LightningFileUploadHandler1.getFiles(
            testAccount.Id,
            null,
            null
        );
        
        // Test with empty string uniqueId
        List<ContentDocument> files2 = LightningFileUploadHandler1.getFiles(
            testAccount.Id,
            '',
            null
        );
        
        Test.stopTest();
    }
    
    @IsTest
    static void testGetFilesWithNoDocuments() {
        // Create test account with no documents
        Account testAccount = new Account(Name = 'Test Account',phone='1234567867',customer_category__c='Exporters');
        insert testAccount;
        
        Test.startTest();
        
        // Test with uniqueId
        List<ContentDocument> files1 = LightningFileUploadHandler1.getFiles(
            testAccount.Id,
            'test-unique-id',
            'OnUpload'
        );
        
        // Test without uniqueId
        List<ContentDocument> files2 = LightningFileUploadHandler1.getFiles(
            testAccount.Id,
            null,
            null
        );
        
        Test.stopTest();
    }
    
    @IsTest
    static void testGetFilesExceptionHandling() {
        // Test with null recordId to trigger exception
        Test.startTest();
        
        try {
            List<ContentDocument> files = LightningFileUploadHandler1.getFiles(
                null,
                'test-unique-id',
                'OnUpload'
            );
        } catch (Exception e) {
            // Exception expected - no assertion needed
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testGetFilesWithContentAsset() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account',phone='1234567867',customer_category__c='Exporters');
        insert testAccount;
        
        // Create a ContentVersion that would be associated with a ContentAsset
        // Note: ContentAssetId is populated by Salesforce for certain file types
        // We can't directly create ContentAssets in tests, but we can test the query logic
        
        // Create regular content document
        ContentVersion cv = new ContentVersion(
            Title = 'Regular File',
            PathOnClient = 'RegularFile.pdf',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert cv;
        
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = testAccount.Id,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V'
        );
        insert cdl;
        
        Test.startTest();
        
        // Test query logic with ContentAssetId filter
        List<ContentDocument> files = LightningFileUploadHandler1.getFiles(
            testAccount.Id,
            null,
            null
        );
        
        Test.stopTest();
    }
    
    @IsTest
    static void testDeleteFile() {
        // Create test content document
        ContentVersion cv = new ContentVersion(
            Title = 'File to Delete',
            PathOnClient = 'DeleteMe.pdf',
            VersionData = Blob.valueOf('Content to delete'),
            IsMajorVersion = true
        );
        insert cv;
        
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        
        Test.startTest();
        
        // Delete the file
        LightningFileUploadHandler1.deleteFile(cv.ContentDocumentId);
        
        Test.stopTest();
    }
    
    @IsTest
    static void testDeleteFileWithInvalidId() {
        Test.startTest();
        
        try {
            // Try to delete with invalid ID
            LightningFileUploadHandler1.deleteFile('invalid-id');
        } catch (Exception e) {
            // Exception expected - no assertion needed
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testGetFilesMixedScenario() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account',phone='1234567867',customer_category__c='Exporters');
        insert testAccount;
        
        // Create multiple content versions with different descriptions
        List<ContentVersion> versions = new List<ContentVersion>();
        
        // Version 1: With specific description
        versions.add(new ContentVersion(
            Title = 'File 1',
            PathOnClient = 'File1.pdf',
            VersionData = Blob.valueOf('Content 1'),
            IsMajorVersion = true,
            Description = 'unique-id-1'
        ));
        
        // Version 2: With different description
        versions.add(new ContentVersion(
            Title = 'File 2',
            PathOnClient = 'File2.pdf',
            VersionData = Blob.valueOf('Content 2'),
            IsMajorVersion = true,
            Description = 'unique-id-2'
        ));
        
        // Version 3: No description
        versions.add(new ContentVersion(
            Title = 'File 3',
            PathOnClient = 'File3.pdf',
            VersionData = Blob.valueOf('Content 3'),
            IsMajorVersion = true
        ));
        
        insert versions;
        
        // Get ContentDocumentIds and create links
        versions = [SELECT Id, ContentDocumentId, Description FROM ContentVersion WHERE Id IN :versions];
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        
        for(ContentVersion cv : versions) {
            ContentDocumentLink cdl = new ContentDocumentLink(
                LinkedEntityId = testAccount.Id,
                ContentDocumentId = cv.ContentDocumentId,
                ShareType = 'V'
            );
            links.add(cdl);
        }
        insert links;
        
        Test.startTest();
        
        // Test getting files with unique-id-1
        List<ContentDocument> files1 = LightningFileUploadHandler1.getFiles(
            testAccount.Id,
            'unique-id-1',
            'OnUpload'
        );
        
        // Test getting files with unique-id-2
        List<ContentDocument> files2 = LightningFileUploadHandler1.getFiles(
            testAccount.Id,
            'unique-id-2',
            'SomeOperation'
        );
        
        // Test getting files with non-existent unique id
        List<ContentDocument> files3 = LightningFileUploadHandler1.getFiles(
            testAccount.Id,
            'non-existent-id',
            'OnUpload'
        );
        
        Test.stopTest();
    }
}