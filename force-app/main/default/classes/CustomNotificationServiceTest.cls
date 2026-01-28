@isTest
private class CustomNotificationServiceTest {
    
    @isTest
    static void testNotificationSend_Basic() {
        // Create test user
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'testu',
            Email = 'testusrrr54636785rer@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test',
            FirstName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuse2121r@example.com.test'
        );
        insert testUser;
        
        // Create test account
        lead testAccount = new lead(
            lastname = 'Test Account',
            phone='1234567891',
            email='test@gmail.com',
            Company='yy'
        );
        insert testAccount;
        
        // Test data
        Set<String> targetUserIds = new Set<String>{testUser.Id};
        String notificationTypeId = '0ML5g000000TNqjGAG';
        
        Test.startTest();
        CustomNotificationService.notificationSend(
            'Test Title',
            testAccount.Id,
            'Test Body',
            targetUserIds,
            notificationTypeId
        );
        Test.stopTest();
    }
    
}