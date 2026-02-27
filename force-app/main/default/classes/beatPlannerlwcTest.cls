@IsTest
public class beatPlannerlwcTest {

    // =========================
    // TEST DATA SETUP
    // =========================
    @testSetup
    static void setupData() {

        // Account
        Account acc = new Account(
            Name = 'Test Account',
            Phone = '9999999999',
             Customer_Category__c = 'Dealer'
        );
        insert acc;

        // Lead
        Lead ld = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Phone = '8888888888',
            Status = 'Open - Not Contacted'
        );
        insert ld;

        // Visits (NO Name field – auto-number)
        DateTime startTime = DateTime.now();
        Visit__c visitCustomer = new Visit__c(
            Visit_for__c = 'Customer',
            Account__c = acc.Id,
            Status__c = 'Planned',
            Visit_Date__c = Date.today(),
            Planned_Start_Time__c = startTime 
            
        );

        Visit__c visitLead = new Visit__c(
            Visit_for__c = 'Lead',
            Lead__c = ld.Id,
            Status__c = 'Planned',
            Visit_Date__c = Date.today(),
            Planned_Start_Time__c = startTime 
        );

        insert new List<Visit__c>{ visitCustomer, visitLead };

        // Daily Log
        Daily_Log__c log = new Daily_Log__c(
            Day_started_time__c = DateTime.now(),
            Vehicle_Used__c = 'Office'
        );
        insert log;

        // Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert prod;
    }

    // =========================
    // saveFile()
    // =========================
    @IsTest
    static void testSaveFile() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        String result = beatPlannerlwc.saveFile(
            acc.Id,
            'test.png',
            EncodingUtil.base64Encode(Blob.valueOf('filedata'))
        );
        Test.stopTest();
    }

    // =========================
    // getAllVisitData()
    // =========================
    @IsTest
    static void testGetAllVisitData() {
        Visit__c v = [SELECT Id FROM Visit__c LIMIT 1];

        Test.startTest();
        beatPlannerlwc.data d = beatPlannerlwc.getAllVisitData(v.Id);
         beatPlannerlwc.getBeatPlanData(system.today(), system.today()+1);
         beatPlannerlwc.getVisitData('rr');
        Test.stopTest();
    }

    // =========================
    // getDailyLog()
    // =========================
    @IsTest
    static void testGetDailyLog() {
        Test.startTest();
        beatPlannerlwc.data d = beatPlannerlwc.getDailyLog();
        Test.stopTest();
    }

    // =========================
    // getVisitCreateData()
    // =========================
    @IsTest
    static void testGetVisitCreateData() {
        Test.startTest();
        beatPlannerlwc.data d = beatPlannerlwc.getVisitCreateData();
        Test.stopTest();
    }

    // =========================
    // getProductData()
    // =========================
    @IsTest
    static void testGetProductData() {
        Test.startTest();
        beatPlannerlwc.data d = beatPlannerlwc.getProductData();
        Test.stopTest();
    }

    // =========================
    // searchProducts()
    // =========================
    @IsTest
    static void testSearchProducts() {
        Test.startTest();
        beatPlannerlwc.data d1 = beatPlannerlwc.searchProducts('');
        beatPlannerlwc.data d2 = beatPlannerlwc.searchProducts('Test');
        Test.stopTest();
    }

    // =========================
    // validatePlannedVisitForCustomer – Customer
    // =========================
    @IsTest
    static void testValidatePlannedVisitCustomer() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        try {
            Test.startTest();
            beatPlannerlwc.validatePlannedVisitForCustomer(
                'Customer',
                acc.Id,
                null
            );
            Test.stopTest();
        } catch (Exception e) {
        }
    }

    // =========================
    // validatePlannedVisitForCustomer – Lead
    // =========================
    @IsTest
    static void testValidatePlannedVisitLead() {
        Lead ld = [SELECT Id FROM Lead LIMIT 1];

        try {
            Test.startTest();
            beatPlannerlwc.validatePlannedVisitForCustomer(
                'Lead',
                null,
                ld.Id
            );
            Test.stopTest();
        } catch (Exception e) {
        }
    }

    // =========================
    // getFiles() + deleteFile()
    // =========================
    @IsTest
    static void testGetAndDeleteFiles() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        ContentVersion cv = new ContentVersion(
            Title = 'TestDoc',
            PathOnClient = 'TestDoc.txt',
            VersionData = Blob.valueOf('Hello'),
            IsMajorVersion = true
        );
        insert cv;
        
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = acc.Id,
            ShareType = 'V'
        );
        insert cdl;

        Test.startTest();
        List<ContentDocument> docs = beatPlannerlwc.getFiles(acc.Id);
        
        if (!docs.isEmpty()) {
            beatPlannerlwc.deleteFile(docs[0].Id);
        }
        Test.stopTest();
    }
}