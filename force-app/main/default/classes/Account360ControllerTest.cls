@isTest
private class Account360ControllerTest {

    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(
            Name = 'Test Account 360',
            Phone = '1234567890',
            City__c = 'Mumbai',
            State__c = 'Maharashtra',
            Status__c = 'Active'
        );
        insert testAccount;

        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id,
            Email = 'test@example.com',
            Phone = '9876543210'
        );
        insert testContact;

        Daily_Log__c dailyLog = new Daily_Log__c(
            Day_started_time__c = Date.today()
        );
        insert dailyLog;

        List<Visit__c> visits = new List<Visit__c>();
        visits.add(new Visit__c(
            Account__c = testAccount.Id,
            Status__c = 'Completed',
            Visit_for__c = 'Customer',
            Visit_Date__c = Date.today().addDays(-1),
            Daily_Log__c = dailyLog.Id,
            Planned_Start_Time__c = DateTime.now().addDays(-1)
        ));
        visits.add(new Visit__c(
            Account__c = testAccount.Id,
            Status__c = 'Planned',
            Visit_for__c = 'Customer',
            Visit_Date__c = Date.today(),
            Daily_Log__c = dailyLog.Id,
            Planned_Start_Time__c = DateTime.now()
        ));
        insert visits;

        Task testTask = new Task(
            Subject = 'Follow up call',
            WhatId = testAccount.Id,
            Status = 'Not Started',
            Priority = 'Normal',
            ActivityDate = Date.today().addDays(3)
        );
        insert testTask;
    }

    @isTest
    static void testGetAccount360Data() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account 360' LIMIT 1];

        Test.startTest();
        Account360Controller.Account360Data result = Account360Controller.getAccount360Data(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.account, 'Account should not be null');
        System.assertEquals('Test Account 360', result.account.Name, 'Account name should match');
        System.assertEquals(2, result.totalVisits, 'Should have 2 visits');
        System.assertEquals(1, result.completedVisits, 'Should have 1 completed visit');
        System.assertEquals(1, result.plannedVisits, 'Should have 1 planned visit');
        System.assert(result.contacts.size() > 0, 'Should have contacts');
        System.assert(result.openTasks.size() > 0, 'Should have open tasks');
    }

    @isTest
    static void testGetAccount360DataNoVisits() {
        Account noVisitAccount = new Account(Name = 'No Visit Account');
        insert noVisitAccount;

        Test.startTest();
        Account360Controller.Account360Data result = Account360Controller.getAccount360Data(noVisitAccount.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.totalVisits, 'Should have 0 visits');
        System.assertEquals(0, result.totalOrders, 'Should have 0 orders');
    }
}
