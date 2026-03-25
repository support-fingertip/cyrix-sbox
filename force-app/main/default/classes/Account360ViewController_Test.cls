@isTest
private class Account360ViewController_Test {

    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(
            Name = 'Test Account 360',
            Phone = '1234567890',
            Status__c = 'Active'
        );
        insert testAccount;

        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id,
            Email = 'test@example.com',
            Phone = '0987654321'
        );
        insert testContact;

        Daily_Log__c dailyLog = new Daily_Log__c(
            Day_started_time__c = Date.today()
        );
        insert dailyLog;

        List<Visit__c> visits = new List<Visit__c>();
        visits.add(new Visit__c(
            Account__c = testAccount.Id,
            Visit_Date__c = Date.today(),
            Status__c = 'Completed',
            Visit_for__c = 'Customer',
            Planned_Start_Time__c = DateTime.now().addHours(-2),
            Daily_Log__c = dailyLog.Id
        ));
        visits.add(new Visit__c(
            Account__c = testAccount.Id,
            Visit_Date__c = Date.today().addDays(1),
            Status__c = 'Planned',
            Visit_for__c = 'Customer',
            Planned_Start_Time__c = DateTime.now().addDays(1),
            Daily_Log__c = dailyLog.Id
        ));
        insert visits;
    }

    @isTest
    static void testGetAccountDetails() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account 360' LIMIT 1];

        Test.startTest();
        Account360ViewController.AccountData result = Account360ViewController.getAccountDetails(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('Test Account 360', result.account.Name, 'Account name should match');
        System.assertEquals(2, result.totalVisits, 'Should have 2 visits');
        System.assertEquals(1, result.completedVisits, 'Should have 1 completed visit');
        System.assertEquals(1, result.plannedVisits, 'Should have 1 planned visit');
        System.assertNotEquals(null, result.contacts, 'Contacts should not be null');
        System.assertEquals(1, result.contacts.size(), 'Should have 1 contact');
    }

    @isTest
    static void testGetAccountDetailsInvalidId() {
        Test.startTest();
        try {
            Account360ViewController.getAccountDetails('001000000000000AAA');
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assertEquals('Account not found.', e.getMessage());
        }
        Test.stopTest();
    }
}