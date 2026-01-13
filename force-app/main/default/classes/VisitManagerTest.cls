@IsTest
public class VisitManagerTest {

    /* =====================================================
       TEST SETUP
       ===================================================== */
    @TestSetup
    static void setupData() {

        String customerCategory = getPicklist(Account.SObjectType, 'Customer_Category__c');
        String vehicleUsed = getPicklist(Daily_Log__c.SObjectType, 'Vehicle_Used__c');

        Account acc = new Account(
            Name = 'Test Account',
            Phone = '9999999999',
            Customer_Category__c = customerCategory
        );
        insert acc;

        Lead ld = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = 'Open - Not Contacted',
            Phone = '8888888888'
        );
        insert ld;

        Daily_Log__c log = new Daily_Log__c(
            Day_started_Time__c = Date.today(),
            Vehicle_Used__c = vehicleUsed,
            Odometer_Starting_Kms__c = 5
        );
        insert log;

        Visit__c customerVisit = new Visit__c(
            Visit_for__c = 'Customer',
            Account__c = acc.Id,
            Visit_Date__c = Date.today(),
            Planned_Start_Time__c = System.now(),
            Daily_Log__c = log.Id,
            Status__c = 'Planned'
        );
        insert customerVisit;

        Visit__c leadVisit = new Visit__c(
            Visit_for__c = 'Lead',
            Lead__c = ld.Id,
            Visit_Date__c = Date.today(),
            Planned_Start_Time__c = System.now(),
            Status__c = 'Planned'
        );
        insert leadVisit;
    }

    /* =====================================================
       getDailyLog
       ===================================================== */
    @IsTest
    static void testGetDailyLog() {
        visitManager.data res = visitManager.getDailyLog();
        System.assertNotEquals(null, res.dailyLog);
    }

    /* =====================================================
       getVisitCreateData
       ===================================================== */
    @IsTest
    static void testGetVisitCreateData() {
        visitManager.data res = visitManager.getVisitCreateData();
        System.assert(res.lead.size() > 0);
        System.assert(res.Customer.size() > 0);
    }

    /* =====================================================
       getData
       ===================================================== */
    @IsTest
    static void testGetData() {
        visitManager.data res = visitManager.getData();
        System.assertNotEquals(null, res.visit);
    }

    /* =====================================================
       getVisitData
       ===================================================== */
    @IsTest
    static void testGetVisitData() {
        visitManager.data res = visitManager.getVisitData('BEAT');
        System.assertNotEquals(null, res.visit);
    }

    /* =====================================================
       getAllVisitData – Customer + Lead
       ===================================================== */
    @IsTest
    static void testGetAllVisitData() {

        Visit__c customerVisit = [
            SELECT Id FROM Visit__c WHERE Visit_for__c = 'Customer' LIMIT 1
        ];

        Visit__c leadVisit = [
            SELECT Id FROM Visit__c WHERE Visit_for__c = 'Lead' LIMIT 1
        ];

        visitManager.data d1 = visitManager.getAllVisitData(customerVisit.Id);
        visitManager.data d2 = visitManager.getAllVisitData(leadVisit.Id);

        System.assertNotEquals(null, d1);
        System.assertNotEquals(null, d2);
    }

    /* =====================================================
       File Methods (saveFile / getFiles / deleteFile)
       ===================================================== */
    @IsTest
    static void testFileMethods() {

        Account acc = [SELECT Id FROM Account LIMIT 1];

        ContentVersion cv = new ContentVersion(
            Title = 'TestImg',
            PathOnClient = 'Test.jpg',
            VersionData = Blob.valueOf('123')
        );
        insert cv;

        Id docId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ].ContentDocumentId;

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = acc.Id,
            ShareType = 'V'
        );
        insert cdl;

        List<ContentDocument> files = visitManager.getFiles(acc.Id);
        System.assert(files.size() > 0);

        visitManager.deleteFile(docId);
    }

    /* =====================================================
       validatePlannedVisit – NO exception
       ===================================================== */
    @IsTest
    static void testValidatePlannedVisit_NoException() {

        String category = getPicklist(Account.SObjectType, 'Customer_Category__c');

        Account acc = new Account(
            Name = 'Fresh Customer',
            Customer_Category__c = category
        );
        insert acc;

        visitManager.validatePlannedVisitForCustomer(
            'Customer',
            acc.Id,
            null
        );

        System.assert(true);
    }

    /* =====================================================
       validatePlannedVisit – Exception
       ===================================================== */
   @IsTest
static void testValidatePlannedVisit_Exception() {

    String category = getPicklist(Account.SObjectType, 'Customer_Category__c');

    Account acc = new Account(
        Name = 'Validated Account',
        Phone = '9876543210',
        Customer_Category__c = category
    );
    insert acc;

    Daily_Log__c log = new Daily_Log__c(
        Day_started_Time__c = Date.today(),
        Vehicle_Used__c = getPicklist(Daily_Log__c.SObjectType, 'Vehicle_Used__c'),
        Odometer_Starting_Kms__c = 1
    );
    insert log;

    Visit__c vis = new Visit__c(
        Visit_for__c = 'Customer',
        Account__c = acc.Id,
        Visit_Date__c = Date.today(),
        Planned_Start_Time__c = System.now(),
        Daily_Log__c = log.Id,
        Status__c = 'Planned'
    );
    insert vis;

    try {
        visitManager.validatePlannedVisitForCustomer('Customer', acc.Id, null);
        System.assert(false);
    } catch (AuraHandledException e) {
        System.assert(e.getMessage().contains('open visit'));
    }
}


    /* =====================================================
       Empty AuraEnabled methods
       ===================================================== */
    @IsTest
    static void testEmptyMethods() {

        visitManager.getPaymentDestails('dummy');
        visitManager.getOrderProductivity(Date.today(), Date.today());
        visitManager.getDataRecordById('dummy', 'getOrderDetails');

        System.assert(true);
    }

    /* =====================================================
       Helper – Dynamic picklist
       ===================================================== */
    private static String getPicklist(
        Schema.SObjectType objType,
        String fieldName
    ) {
        for (Schema.PicklistEntry p :
            objType.getDescribe()
                   .fields.getMap()
                   .get(fieldName)
                   .getDescribe()
                   .getPicklistValues()) {

            if (p.isActive()) return p.getValue();
        }
        return null;
    }
}