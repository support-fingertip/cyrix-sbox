@isTest
private class DistanceMatrixControllerForVisitTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test users with proper assignment
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        
        // First create users
        User testUser1 = new User(
            Alias = 'testusr1',
            Email = 'testuser1@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing1',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuser1@testorg.com.testclass',
            Phone = '1234567890'  // Add phone for user
        );
        
        User testUser2 = new User(
            Alias = 'testusr2',
            Email = 'testuser2@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing2',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuser2@testorg.com.testclass',
            Phone = '1234567891'  // Add phone for user
        );
        
        insert new List<User>{testUser1, testUser2};
        
        // Switch to system context for data creation
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // Create test accounts with Customer Category
            List<Account> testAccounts = new List<Account>();
            for(Integer i = 0; i < 3; i++) {
                testAccounts.add(new Account(
                    Name = 'Test Account ' + i,
                    OwnerId = testUser1.Id,  // Assign ownership to test user
                    Customer_Category__c = 'Exporters',  // Add required Customer Category
                    Phone = '1234567890'  // Add phone for account
                ));
            }
            insert testAccounts;
            
            // Create test lead with phone (if needed)
            Lead testLead = new Lead(
                LastName = 'Test Lead',
                Company = 'Test Company',
                Phone = '1234567890',  // Required phone
                Status = 'Open - Not Contacted'
            );
            insert testLead;
            
            // Create daily logs for user 1
            Daily_Log__c dailyLog1 = new Daily_Log__c(
                Clock_In_Location__Latitude__s = 37.7749,
                Clock_In_Location__Longitude__s = -122.4194,
                OwnerId = testUser1.Id,
                Day_started_Time__c=system.now()
            );
            insert dailyLog1;
            
            // Create visits for user 1 with Lead and Account
            List<Visit__c> visitsUser1 = new List<Visit__c>();
            DateTime visitDate = DateTime.newInstance(2024, 1, 15, 9, 0, 0);
            
            // Visit with Account
            visitsUser1.add(new Visit__c(
                Visit_Start__c = visitDate,
                Check_In_Location__Latitude__s = 37.7749,
                Check_In_Location__Longitude__s = -122.4194,
                Daily_Log__c = dailyLog1.Id,
                OwnerId = testUser1.Id,
                  Planned_Start_Time__c=system.now(),
                Account__c = testAccounts[0].Id,
                Visit_for__c = 'Customer'  // Specify visit type
            ));
            
            // Visit with Lead
            visitsUser1.add(new Visit__c(
                Visit_Start__c = visitDate.addHours(2),
                Check_In_Location__Latitude__s = 37.7849,
                Check_In_Location__Longitude__s = -122.4094,
                Daily_Log__c = dailyLog1.Id,
                OwnerId = testUser1.Id,
                Lead__c = testLead.Id,
                  Planned_Start_Time__c=system.now(),
                Visit_for__c = 'Lead'  // Specify visit type
            ));
            
            // Another visit with Account
            visitsUser1.add(new Visit__c(
                Visit_Start__c = visitDate.addHours(4),
                Check_In_Location__Latitude__s = 37.7949,
                Check_In_Location__Longitude__s = -122.3994,
                Daily_Log__c = dailyLog1.Id,
                OwnerId = testUser1.Id,
                Account__c = testAccounts[1].Id,
                Planned_Start_Time__c=system.now(),
                Visit_for__c = 'Customer'  // Specify visit type
            ));
            
            insert visitsUser1;
        }
    }
    
    @isTest
    static void testDistanceCalculationEmptyInput() {
        Test.startTest();
        DistanceMatrixControllerForVisit.distanceCalculation(new List<String>());
        DistanceMatrixControllerForVisit.distanceCalculation(null);
        Test.stopTest();
    }
    
    @isTest
    static void testDistanceCalculationSingleVisit() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser1@testorg.com.testclass' LIMIT 1];
        
        System.runAs(testUser) {
            List<Visit__c> visits = [SELECT Id FROM Visit__c WHERE OwnerId = :testUser.Id ORDER BY Visit_Start__c LIMIT 1];
            
            Test.startTest();
            DistanceMatrixControllerForVisit.distanceCalculation(new List<String>{visits[0].Id});
            Test.stopTest();
        }
    }
    
    @isTest
    static void testDistanceCalculationMultipleVisits() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser1@testorg.com.testclass' LIMIT 1];
        
        System.runAs(testUser) {
            List<Visit__c> visits = [SELECT Id FROM Visit__c WHERE OwnerId = :testUser.Id];
            
            List<String> visitIds = new List<String>();
            for(Visit__c v : visits) {
                visitIds.add(v.Id);
            }
            
            Test.startTest();
            DistanceMatrixControllerForVisit.distanceCalculation(visitIds);
            Test.stopTest();
        }
    }
    
    @isTest
    static void testDistanceCalculationNoCoordinates() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser1@testorg.com.testclass' LIMIT 1];
        
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Account testAccount = [SELECT Id FROM Account WHERE Customer_Category__c = 'Exporters' LIMIT 1];
            Daily_Log__c dailyLog = [SELECT Id FROM Daily_Log__c LIMIT 1];
            
            // Create visit without coordinates
            Visit__c visitWithoutCoords = new Visit__c(
                Visit_Start__c = DateTime.now(),
                Daily_Log__c = dailyLog.Id,
                OwnerId = testUser.Id,
                Account__c = testAccount.Id,
                Visit_for__c = 'Customer',
                  Planned_Start_Time__c=system.now()
            );
            insert visitWithoutCoords;
            
            Test.startTest();
            DistanceMatrixControllerForVisit.distanceCalculation(new List<String>{visitWithoutCoords.Id});
            Test.stopTest();
        }
    }
    
    @isTest
    static void testDistanceCalculationWithoutDailyLog() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser1@testorg.com.testclass' LIMIT 1];
        
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Account testAccount = [SELECT Id FROM Account WHERE Customer_Category__c = 'Exporters' LIMIT 1];
            
            // Create visit without daily log
            Visit__c visitWithoutLog = new Visit__c(
                Visit_Start__c = DateTime.now(),
                Check_In_Location__Latitude__s = 37.7749,
                Check_In_Location__Longitude__s = -122.4194,
                OwnerId = testUser.Id,
                Account__c = testAccount.Id,
                Visit_for__c = 'Customer',
                  Planned_Start_Time__c=system.now()
            );
            insert visitWithoutLog;
            
            Test.startTest();
            DistanceMatrixControllerForVisit.distanceCalculation(new List<String>{visitWithoutLog.Id});
            Test.stopTest();
        }
    }
    
    @isTest
    static void testDistanceCalculationBulk() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser1@testorg.com.testclass' LIMIT 1];
        
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Account testAccount = [SELECT Id FROM Account WHERE Customer_Category__c = 'Exporters' LIMIT 1];
            Daily_Log__c dailyLog = [SELECT Id FROM Daily_Log__c LIMIT 1];
            
            // Create bulk visits
            List<Visit__c> bulkVisits = new List<Visit__c>();
            DateTime baseTime = DateTime.newInstance(2024, 1, 16, 8, 0, 0);
            
            for(Integer i = 0; i < 10; i++) {
                bulkVisits.add(new Visit__c(
                    Visit_Start__c = baseTime.addMinutes(i * 30),
                    Check_In_Location__Latitude__s = 37.7749 + (i * 0.005),
                    Check_In_Location__Longitude__s = -122.4194 + (i * 0.005),
                    Daily_Log__c = dailyLog.Id,
                    OwnerId = testUser.Id,
                    Account__c = testAccount.Id,
                    Visit_for__c = 'Customer',
                      Planned_Start_Time__c=system.now()
                ));
            }
            insert bulkVisits;
            
            List<String> visitIds = new List<String>();
            for(Visit__c v : bulkVisits) {
                visitIds.add(v.Id);
            }
            
            Test.startTest();
            DistanceMatrixControllerForVisit.distanceCalculation(visitIds);
            Test.stopTest();
        }
    }
    
    @isTest
    static void testHaversineDistanceMethod() {
        Test.startTest();
        
        // Test with same coordinates
        Decimal distance1 = DistanceMatrixControllerForVisit.calculateHaversineDistance(
            37.7749, -122.4194,
            37.7749, -122.4194
        );
        
        // Test with different coordinates
        Decimal distance2 = DistanceMatrixControllerForVisit.calculateHaversineDistance(
            37.7749, -122.4194,
            34.0522, -118.2437
        );
        
        // Test with close coordinates
        Decimal distance3 = DistanceMatrixControllerForVisit.calculateHaversineDistance(
            37.7749, -122.4194,
            37.7750, -122.4195
        );
        
        Test.stopTest();
    }
    
    @isTest
    static void testDistanceCalculationForNewUser() {
        // Create new user
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User newUser = new User(
            Alias = 'newuser',
            Email = 'newuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'NewUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'newuser@testorg.com.testclass',
            Phone = '1234567892'
        );
        insert newUser;
        
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // Create data as system admin
            
            // Create account with required fields
            Account newAccount = new Account(
                Name = 'New Account',
                OwnerId = newUser.Id,
                Customer_Category__c = 'Exporters',
                Phone = '1234567892'
            );
            insert newAccount;
            
            Daily_Log__c newDailyLog = new Daily_Log__c(
                Clock_In_Location__Latitude__s = 40.7128,
                Clock_In_Location__Longitude__s = -74.0060,
                OwnerId = newUser.Id,
                Day_started_Time__c=system.now()
            );
            insert newDailyLog;
            
            Visit__c newVisit = new Visit__c(
                Visit_Start__c = DateTime.now(),
                Check_In_Location__Latitude__s = 40.7228,
                Check_In_Location__Longitude__s = -74.0060,
                Daily_Log__c = newDailyLog.Id,
                OwnerId = newUser.Id,
                Account__c = newAccount.Id,
                Visit_for__c = 'Customer',
                  Planned_Start_Time__c=system.now()
            );
            insert newVisit;
            
            Test.startTest();
            DistanceMatrixControllerForVisit.distanceCalculation(new List<String>{newVisit.Id});
            Test.stopTest();
        }
    }
    
    @isTest
    static void testDistanceCalculationDailyLogNoCoordinates() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser1@testorg.com.testclass' LIMIT 1];
        
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Account testAccount = [SELECT Id FROM Account WHERE Customer_Category__c = 'Exporters' LIMIT 1];
            
            // Create daily log without coordinates
            Daily_Log__c dailyLogNoCoords = new Daily_Log__c(
                OwnerId = testUser.Id,
                Day_started_Time__c=system.now()
            );
            insert dailyLogNoCoords;
            
            Visit__c visitWithDailyLogNoCoords = new Visit__c(
                Visit_Start__c = DateTime.now(),
                Check_In_Location__Latitude__s = 37.7749,
                Check_In_Location__Longitude__s = -122.4194,
                Daily_Log__c = dailyLogNoCoords.Id,
                OwnerId = testUser.Id,
                Account__c = testAccount.Id,
                Visit_for__c = 'Customer',
                  Planned_Start_Time__c=system.now()
            );
            insert visitWithDailyLogNoCoords;
            
            Test.startTest();
            DistanceMatrixControllerForVisit.distanceCalculation(new List<String>{visitWithDailyLogNoCoords.Id});
            Test.stopTest();
        }
    }
    
    @isTest
    static void testDistanceCalculationForLeadVisits() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser1@testorg.com.testclass' LIMIT 1];
        
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // Create another lead with required phone
            Lead newLead = new Lead(
                LastName = 'New Test Lead',
                Company = 'New Test Company',
                Phone = '1234567893',  // Required phone
                Status = 'Open - Not Contacted'
            );
            insert newLead;
            
            Daily_Log__c dailyLog = [SELECT Id FROM Daily_Log__c LIMIT 1];
            
            // Create visit for lead
            Visit__c leadVisit = new Visit__c(
                Visit_Start__c = DateTime.now().addHours(6),
                Check_In_Location__Latitude__s = 37.8049,
                Check_In_Location__Longitude__s = -122.3894,
                Daily_Log__c = dailyLog.Id,
                OwnerId = testUser.Id,
                Lead__c = newLead.Id,
                Visit_for__c = 'Lead',
                  Planned_Start_Time__c=system.now()
            );
            insert leadVisit;
            
            Test.startTest();
            DistanceMatrixControllerForVisit.distanceCalculation(new List<String>{leadVisit.Id});
            Test.stopTest();
        }
    }
    
    @isTest
    static void testDistanceCalculationMixedVisitTypes() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testuser1@testorg.com.testclass' LIMIT 1];
        
        System.runAs(testUser) {
            List<Visit__c> visits = [SELECT Id FROM Visit__c WHERE OwnerId = :testUser.Id];
            
            // Get visits of all types (Account and Lead)
            List<String> visitIds = new List<String>();
            for(Visit__c v : visits) {
                visitIds.add(v.Id);
            }
            
            Test.startTest();
            DistanceMatrixControllerForVisit.distanceCalculation(visitIds);
            Test.stopTest();
        }
    }
}