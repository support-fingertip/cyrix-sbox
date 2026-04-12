@isTest
public class DailyLogVisitMapControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create test user
        Profile salesProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'dlvmusr',
            Email = 'dlvmuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'DLVMTest',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = salesProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'dlvmtestuser@test.com.cyrix'
        );
        insert testUser;

        // Create Daily Log
        Daily_Log__c dailyLog = new Daily_Log__c(
            Day_started_Time__c = Datetime.newInstance(Date.today(), Time.newInstance(9, 0, 0, 0)),
            OwnerId = testUser.Id
        );
        insert dailyLog;

        // Create Account
        Account testAccount = new Account(
            Name = 'DLVM Test Account',
            Phone = '1234567890',
            Customer_Category__c = 'Exporters'
        );
        insert testAccount;

        // Create Lead
        Lead testLead = new Lead(
            LastName = 'DLVM Lead',
            Company = 'DLVM Company',
            Status = 'Open',
            Phone = '9876543210'
        );
        insert testLead;

        // Create Visits with Check-In/Check-Out locations
        Visit__c visit1 = new Visit__c(
            Daily_Log__c = dailyLog.Id,
            Account__c = testAccount.Id,
            Visit_for__c = 'Customer',
            Visit_Start__c = Datetime.now().addHours(-3),
            Visit_End__c = Datetime.now().addHours(-2),
            Visit_Purpose__c = 'Demo',
            Status__c = 'Completed',
            Address__c = 'Test Address 1',
            Check_In_Location__Latitude__s = 12.9716,
            Check_In_Location__Longitude__s = 77.5946,
            Check_Out_Location__Latitude__s = 12.9720,
            Check_Out_Location__Longitude__s = 77.5950
        );
        insert visit1;

        Visit__c visit2 = new Visit__c(
            Daily_Log__c = dailyLog.Id,
            Lead__c = testLead.Id,
            Visit_for__c = 'Lead',
            Visit_Start__c = Datetime.now().addHours(-1),
            Visit_Purpose__c = 'Follow Up',
            Status__c = 'Completed',
            Check_In_Location__Latitude__s = 13.0827,
            Check_In_Location__Longitude__s = 80.2707
        );
        insert visit2;
    }

    @isTest
    static void testGetVisitLocations() {
        Daily_Log__c log = [SELECT Id FROM Daily_Log__c LIMIT 1];

        Test.startTest();
        List<DailyLogVisitMapController.VisitMapWrapper> results =
            DailyLogVisitMapController.getVisitLocations(log.Id);
        Test.stopTest();

        System.assert(results.size() > 0, 'Should return visit locations');
    }

    @isTest
    static void testGetVisitLocationsByUserAndDate() {
        User u = [SELECT Id FROM User WHERE UserName = 'dlvmtestuser@test.com.cyrix' LIMIT 1];

        Test.startTest();
        List<DailyLogVisitMapController.VisitMapWrapper> results =
            DailyLogVisitMapController.getVisitLocationsByUserAndDate(u.Id, Date.today());
        Test.stopTest();

        System.assert(results.size() > 0, 'Should return visit locations for user and date');
    }

    @isTest
    static void testGetVisitLocationsByUserAndDateNoLog() {
        User u = [SELECT Id FROM User WHERE UserName = 'dlvmtestuser@test.com.cyrix' LIMIT 1];

        Test.startTest();
        List<DailyLogVisitMapController.VisitMapWrapper> results =
            DailyLogVisitMapController.getVisitLocationsByUserAndDate(u.Id, Date.today().addDays(10));
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty list when no log found');
    }
}
