@isTest
public class FileUploadControllerTest {

    @TestSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Test Doc Upload Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Doc Upload Opp',
            AccountId = acc.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
    }

    @isTest
    static void testHandleDocumentUpload_WO() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        FileUploadController.handleDocumentUpload(opp.Id, 'WO');
        Test.stopTest();

        Opportunity result = [SELECT WO_Uploaded__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(true, result.WO_Uploaded__c, 'WO checkbox should be checked');
    }

    @isTest
    static void testHandleDocumentUpload_AllTypes() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        FileUploadController.handleDocumentUpload(opp.Id, 'PO');
        FileUploadController.handleDocumentUpload(opp.Id, 'Cheque');
        FileUploadController.handleDocumentUpload(opp.Id, 'DD');
        FileUploadController.handleDocumentUpload(opp.Id, 'Cash');
        FileUploadController.handleDocumentUpload(opp.Id, 'UPI');
        Test.stopTest();

        Opportunity result = [
            SELECT PO_Uploaded__c, Cheque_Uploaded__c, DD_Uploaded__c,
                   Cash_Uploaded__c, UPI_Uploaded__c
            FROM Opportunity WHERE Id = :opp.Id
        ];
        System.assertEquals(true, result.PO_Uploaded__c);
        System.assertEquals(true, result.Cheque_Uploaded__c);
        System.assertEquals(true, result.DD_Uploaded__c);
        System.assertEquals(true, result.Cash_Uploaded__c);
        System.assertEquals(true, result.UPI_Uploaded__c);
    }

    @isTest
    static void testHandleDocumentUpload_InvalidType() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        FileUploadController.handleDocumentUpload(opp.Id, 'InvalidType');
        Test.stopTest();

        Opportunity result = [
            SELECT WO_Uploaded__c, PO_Uploaded__c
            FROM Opportunity WHERE Id = :opp.Id
        ];
        System.assertEquals(false, result.WO_Uploaded__c);
        System.assertEquals(false, result.PO_Uploaded__c);
    }

    @isTest
    static void testHandleDocumentUpload_BlankInputs() {
        Test.startTest();
        FileUploadController.handleDocumentUpload(null, 'WO');
        FileUploadController.handleDocumentUpload('', 'WO');
        Test.stopTest();
    }

    @isTest
    static void testGetDocumentStatus() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        opp.WO_Uploaded__c = true;
        opp.Cash_Uploaded__c = true;
        update opp;

        Test.startTest();
        Map<String, Boolean> status = FileUploadController.getDocumentStatus(opp.Id);
        Test.stopTest();

        System.assertEquals(true, status.get('WO'));
        System.assertEquals(true, status.get('Cash'));
        System.assertEquals(false, status.get('PO'));
        System.assertEquals(false, status.get('DD'));
    }

    @isTest
    static void testRenameUploadedFile() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        ContentVersion cv = new ContentVersion(
            Title = 'OriginalFile',
            PathOnClient = 'OriginalFile.pdf',
            VersionData = Blob.valueOf('Test file content')
        );
        insert cv;

        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = insertedCv.ContentDocumentId,
            LinkedEntityId = opp.Id,
            ShareType = 'V'
        );
        insert cdl;

        Test.startTest();
        FileUploadController.renameUploadedFile(opp.Id, 'WO');
        Test.stopTest();

        ContentVersion renamed = [
            SELECT Title FROM ContentVersion
            WHERE ContentDocumentId = :insertedCv.ContentDocumentId AND IsLatest = true
        ];
        String expectedPrefix = 'WO_' + Datetime.now().format('yyyy-MM-dd');
        System.assertEquals(expectedPrefix, renamed.Title, 'File should be renamed with doc type and date');
    }
}
