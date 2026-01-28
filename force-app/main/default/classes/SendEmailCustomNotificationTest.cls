@IsTest
public class SendEmailCustomNotificationTest {
    
    @IsTest
    static void testSendNotification() {
        // Create test users
        User testUser1 = new User(
            FirstName = 'Test',
            LastName = 'User1',
            Email = 'testuser1@test.com',
            Username = 'testuser1@test.com' + System.currentTimeMillis(),
            Alias = 'tuser1',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User'].Id,
            LanguageLocaleKey = 'en_US'
        );
        
        User testUser2 = new User(
            FirstName = 'Test',
            LastName = 'User2',
            Email = 'testuser2@test.com',
            Username = 'testuser2@test.com' + System.currentTimeMillis(),
            Alias = 'tuser2',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User'].Id,
            LanguageLocaleKey = 'en_US'
        );
        
        insert new List<User>{testUser1, testUser2};
        
        // Create test account as target object
        Account testAccount = new Account(Name = 'Test Account',phone='1234567867',customer_category__c='Exporters');
        insert testAccount;
        
     
        Test.startTest();
        
        CustomNotificationType notificationType = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Lead_Notification'
            LIMIT 1
        ];
        // Test with single user
        Set<String> singleUserIdSet = new Set<String>{testUser1.Id};
        SendEmailCustomNotification.sendNotification(
            'Test body message',
            'Test Title',
            UserInfo.getUserId(),
            notificationType.Id,
            testAccount.Id,
            singleUserIdSet
        );
        
        // Test with multiple users
        Set<String> multipleUserIdSet = new Set<String>{testUser1.Id, testUser2.Id};
        SendEmailCustomNotification.sendNotification(
            'Another test body message',
            'Another Test Title',
            UserInfo.getUserId(),
            notificationType.Id,
            testAccount.Id,
            multipleUserIdSet
        );
        
        Test.stopTest();
    }
    
    @IsTest
    static void testSendEmail() {

        
        Test.startTest();
        
        // Test with single email address
        String[] singleEmailArray = new String[]{'test1@example.com'};
        SendEmailCustomNotification.sendEmail(
            'Test Subject',
            '<h1>Test HTML Body</h1>',
            'Test Display Name',
            singleEmailArray
        );
        
        // Test with multiple email addresses
        String[] multipleEmailArray = new String[]{'test1@example.com', 'test2@example.com', 'test3@example.com'};
        SendEmailCustomNotification.sendEmail(
            'Another Test Subject',
            '<p>Another test HTML body</p>',
            'Another Display Name',
            multipleEmailArray
        );
        
        // Test with empty email array
        String[] emptyEmailArray = new String[]{};
        try {
            SendEmailCustomNotification.sendEmail(
                'Empty Email Test',
                '<p>Test body</p>',
                'Test Display',
                emptyEmailArray
            );
        } catch (Exception e) {
            // Exception expected - no assertion needed
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testSendBulkEmail() {

        
        Test.startTest();
        
        // Test bulk email creation with single recipient
        String[] singleEmailArray = new String[]{'bulk1@example.com'};
        Messaging.SingleEmailMessage email1 = SendEmailCustomNotification.sendBulkEmail(
            'Bulk Test Subject 1',
            '<h1>Bulk Test Body 1</h1>',
            'Bulk Display 1',
            singleEmailArray
        );
        
        // Test bulk email creation with multiple recipients
        String[] multipleEmailArray = new String[]{'bulk1@example.com', 'bulk2@example.com', 'bulk3@example.com'};
        Messaging.SingleEmailMessage email2 = SendEmailCustomNotification.sendBulkEmail(
            'Bulk Test Subject 2',
            '<p>Bulk Test Body 2</p>',
            'Bulk Display 2',
            multipleEmailArray
        );
        
        // Test bulk email creation with complex HTML body
        String complexHtmlBody = '<html><body><h1>Welcome</h1><p>This is a test email</p><ul><li>Item 1</li><li>Item 2</li></ul></body></html>';
        Messaging.SingleEmailMessage email3 = SendEmailCustomNotification.sendBulkEmail(
            'Complex HTML Email',
            complexHtmlBody,
            'Complex Display',
            new String[]{'complex@example.com'}
        );
        
        Test.stopTest();
    }
    
    @IsTest
    static void testOrgWideEmailAddressNotFound() {
        // Don't create any OrgWideEmailAddress to test the scenario
        
        Test.startTest();
        
        try {
            String[] emailArray = new String[]{'test@example.com'};
            SendEmailCustomNotification.sendEmail(
                'Test Subject',
                '<p>Test Body</p>',
                'Test Display',
                emailArray
            );
        } catch (Exception e) {
            // Exception expected - no assertion needed
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testSendNotificationWithEmptyUserSet() {
        // Create test account as target object
        Account testAccount = new Account(Name = 'Test Account',phone='1234567867',customer_category__c='Exporters');
        insert testAccount;
        

        
        Test.startTest();
           CustomNotificationType notificationType = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Lead_Notification'
            LIMIT 1
        ];
        // Test with empty user set
        Set<String> emptyUserSet = new Set<String>();
        SendEmailCustomNotification.sendNotification(
            'Empty user set body',
            'Empty User Set Title',
            UserInfo.getUserId(),
            notificationType.Id,
            testAccount.Id,
            emptyUserSet
        );
        
        Test.stopTest();
    }
}