@isTest
public with sharing class visitManagerTest {
    
    @TestSetup
    static void setupTestData() {
        Profile salesProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'testusr',
            Email = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = salesProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuser111@testttt.com'
        );
        insert testUser;
        
        System.runAs(testUser) {
            List<Account> testAccounts = new List<Account>();
            for(Integer i = 0; i < 5; i++) {
                testAccounts.add(new Account(
                    Name = 'Test Account ' + i,
                    Phone = '987654321' + i,
                    Customer_Category__c='Exporters'
                ));
            }
            insert testAccounts;
            
            List<Lead> testLeads = new List<Lead>();
            for(Integer i = 0; i < 3; i++) {
                testLeads.add(new Lead(
                    LastName = 'Test Lead ' + i,
                    Company = 'Test Company ' + i,
                    Phone = '987654321' + i,
                    MobilePhone = '9876564321' + i,
                    Status = 'Open'
                ));
            }
            insert testLeads;
            
            Daily_Log__c dailyLog = new Daily_Log__c(
                Day_started_time__c = DateTime.now(),
                Clock_In_Location__Longitude__s = 76.1234,
                Clock_In_Location__Latitude__s = 11.1234,
                Vehicle_Used__c = 'Office',
                Odometer_Starting_Kms__c = 1000
            );
            insert dailyLog;
            
            List<Visit__c> testVisits = new List<Visit__c>();
            for(Integer i = 0; i < 3; i++) {
                testVisits.add(new Visit__c(
                    Account__c = testAccounts[i].Id,
                    Visit_for__c = 'Customer',
                    Visit_Date__c = Date.today(),
                    Planned_Start_Time__c = DateTime.now().addHours(i),
                    Status__c = 'Planned',
                    Daily_Log__c = dailyLog.Id,
                    Visit_Type__c = 'Regular',
                    Check_In_Location__Longitude__s = 76.1234,
                    Check_In_Location__Latitude__s = 11.1234
                ));
            }
            
            testVisits.add(new Visit__c(
                Account__c = testAccounts[3].Id,
                Visit_for__c = 'Customer',
                Visit_Date__c = Date.today(),
                Planned_Start_Time__c = DateTime.now().addHours(-2),
                Visit_Start__c = DateTime.now().addHours(-2),
                Visit_End__c = DateTime.now().addHours(-1),
                Status__c = 'Completed',
                Daily_Log__c = dailyLog.Id,
                Visit_Type__c = 'Regular'
            ));
            
            testVisits.add(new Visit__c(
                Lead__c = testLeads[0].Id,
                Visit_for__c = 'Lead',
                Visit_Date__c = Date.today(),
                Planned_Start_Time__c = DateTime.now().addHours(1),
                Status__c = 'Planned',
                Daily_Log__c = dailyLog.Id,
                Visit_Type__c = 'Regular'
            ));
            
            insert testVisits;
            
        
            
            ContentVersion contentVersion = new ContentVersion(
                Title = 'Test Photo',
                PathOnClient = 'test.jpg',
                VersionData = Blob.valueOf('Test Content'),
                IsMajorVersion = true
            );
            insert contentVersion;
            
            ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id];
            
            ContentDocumentLink cdl = new ContentDocumentLink(
                LinkedEntityId = testVisits[0].Id,
                ContentDocumentId = cv.ContentDocumentId,
                ShareType = 'V'
            );
            insert cdl;
        }
    }
    
    @isTest
    static void testGetAllVisitData() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser111@testttt.com' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            
            Visit__c testVisit = [SELECT Id FROM Visit__c WHERE Visit_for__c = 'Customer' LIMIT 1];
            
            visitManager.data result = visitManager.getAllVisitData(testVisit.Id);
            
            Test.stopTest();
        }
    }
    
    @isTest
    static void testGetDailyLog() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser111@testttt.com' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            
            visitManager.data result = visitManager.getDailyLog();
            
            Test.stopTest();
        }
    }
    
    @isTest
    static void testGetVisitCreateData() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser111@testttt.com' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            
            visitManager.data result = visitManager.getVisitCreateData();
            
            Test.stopTest();
        }
    }
    
    @isTest
    static void testGetData() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser111@testttt.com' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            
            visitManager.data result = visitManager.getData();
            
            Test.stopTest();
        }
    }
    
    @isTest
    static void testGetVisitData() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser111@testttt.com' LIMIT 1];
        
        System.runAs(testUser) {
            Account testAccount = [SELECT Id FROM Account LIMIT 1];
            
            Test.startTest();
            
            visitManager.data result = visitManager.getVisitData(testAccount.Id);
            
            Test.stopTest();
        }
    }
    
    @isTest
    static void testGetFiles() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser111@testttt.com' LIMIT 1];
        
        System.runAs(testUser) {
            Visit__c testVisit = [SELECT Id FROM Visit__c WHERE Visit_for__c = 'Customer' LIMIT 1];
            
            Test.startTest();
            
            List<ContentDocument> result = visitManager.getFiles(testVisit.Id);
            
            Test.stopTest();
        }
    }
    
    @isTest
    static void testDeleteFile() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser111@testttt.com' LIMIT 1];
        
        System.runAs(testUser) {
            ContentDocument testDoc = [SELECT Id FROM ContentDocument LIMIT 1];
            
            Test.startTest();
            
            visitManager.deleteFile(testDoc.Id);
            
            Test.stopTest();
        }
    }
    
    @isTest
    static void testSaveFile() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser111@testttt.com' LIMIT 1];
        
        System.runAs(testUser) {
            Visit__c testVisit = [SELECT Id FROM Visit__c WHERE Visit_for__c = 'Customer' LIMIT 1];
            
            Test.startTest();
            
            String base64Data = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
            String result = visitManager.saveFile(testVisit.Id, 'test.jpg', base64Data);
            
            Test.stopTest();
        }
    }
    
    @isTest
    static void testValidatePlannedVisitForCustomer_Positive() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser111@testttt.com' LIMIT 1];
        
        System.runAs(testUser) {
            Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account 0' LIMIT 1];
            
            Test.startTest();
            
            try {
                visitManager.validatePlannedVisitForCustomer('Customer', testAccount.Id, null);
            } catch (Exception e) {
            }
            
            Test.stopTest();
        }
    }
    
    @isTest
    static void testValidatePlannedVisitForCustomer_Negative() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser111@testttt.com' LIMIT 1];
        
        System.runAs(testUser) {
            Visit__c openVisit = [SELECT Id, Status__c FROM Visit__c 
                                 WHERE Account__r.Name = 'Test Account 0' LIMIT 1];
            openVisit.Status__c = 'In Progress';
            update openVisit;
            
            Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account 0' LIMIT 1];
            
            Test.startTest();
            
            try {
                visitManager.validatePlannedVisitForCustomer('Customer', testAccount.Id, null);
            } catch (Exception e) {
            }
            
            Test.stopTest();
        }
    }
    
    @isTest
    static void testValidatePlannedVisitForLead() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser111@testttt.com' LIMIT 1];
        
        System.runAs(testUser) {
            Lead testLead = [SELECT Id FROM Lead LIMIT 1];
            
            Test.startTest();
            
            try {
                visitManager.validatePlannedVisitForCustomer('Lead', null, testLead.Id);
            } catch (Exception e) {
            }
            
            Test.stopTest();
        }
    }
    
    @isTest
    static void testDataClass() {
        Test.startTest();
        
        visitManager.data testData = new visitManager.data();
        
        visitManager.VisitDataSummary summary = new visitManager.VisitDataSummary();
        summary.visitId = '001';
        summary.visitType = 'Regular';
        summary.ownerId = UserInfo.getUserId();
        summary.visDate = '2024-01-01';
        summary.TotalOrd = 10;
        summary.ExeName = 'Test User';
        
        visitManager.visitData visit = new visitManager.visitData();
        visit.id = '001';
        visit.Name = 'Test Visit';
        visit.VisitDate = Date.today();
        visit.formattedVisitDate = '24/12/2024';
        visit.accountName = 'Test Account';
        visit.status = 'Planned';
        visit.ClockInLatitude = 11.1234;
        visit.ClockinLongitude = 76.1234;
        visit.visitTypes = 'Customer';
        
        Test.stopTest();
    }
    
    @isTest
    static void testGetVisitDataWithNullBeatId() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser111@testttt.com' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            
            visitManager.data result = visitManager.getVisitData(null);
            
            Test.stopTest();
        }
    }
    
    @isTest
    static void testGetAllVisitDataWithNoOrders() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser111@testttt.com' LIMIT 1];
        
        System.runAs(testUser) {
            Account testAccount = new Account(
                Name = 'Test Account No Orders',
                Customer_Category__c='Exporters',
                phone='1234567867'
            );
            insert testAccount;
            
            Daily_Log__c dailyLog = [SELECT Id FROM Daily_Log__c LIMIT 1];
            
            Visit__c testVisit = new Visit__c(
                Account__c = testAccount.Id,
                Visit_for__c = 'Customer',
                Visit_Date__c = Date.today(),
                Planned_Start_Time__c = DateTime.now(),
                Status__c = 'Planned',
                Daily_Log__c = dailyLog.Id
            );
            insert testVisit;
            
            Test.startTest();
            
            visitManager.data result = visitManager.getAllVisitData(testVisit.Id);
            
            Test.stopTest();
        }
    }
}