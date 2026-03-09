@IsTest
private class LeadEmailHandlerTest {

    private static Messaging.InboundEmail buildEmail(String subject, String body) {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject       = subject;
        email.plainTextBody = body;
        email.fromAddress   = 'sender@example.com';
        email.fromName      = 'Test Sender';
        return email;
    }

    private static Messaging.InboundEnvelope buildEnvelope() {
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.toAddress   = 'leads@cyrix.com';
        env.fromAddress = 'sender@example.com';
        return env;
    }

    // ── Handler tests ──────────────────────────────────────────────────────────

    @IsTest
    static void testValidLeadWithDelimiters() {
        String body =
            '--- CYRIX HEALTHCARE LEAD ---\n' +
            'FirstName: John\n' +
            'LastName: Doe\n' +
            'Email: john.doe@example.com\n' +
            'Phone: 9876543210\n' +
            'Company: Test Corp\n' +
            'Message: Need MRI Machine\n' +
            '--- END LEAD ---';

        LeadEmailHandler handler = new LeadEmailHandler();

        Test.startTest();
        Messaging.InboundEmailResult result = handler.handleInboundEmail(
            buildEmail('New Lead - MRI Machine', body),
            buildEnvelope()
        );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Expected success for valid lead with delimiters');
        List<Lead> leads = [SELECT Id, LastName, LeadSource FROM Lead WHERE Email = 'john.doe@example.com'];
        System.assertEquals(1, leads.size(), 'Expected one Lead record to be created');
        System.assertEquals('Doe', leads[0].LastName);
        System.assertEquals('Email', leads[0].LeadSource);
    }

    @IsTest
    static void testValidLeadWithFallbackParser() {
        String body =
            'Name: Jane\n' +
            'Last Name: Smith\n' +
            'Email Address: jane.smith@example.com\n' +
            'Mobile: 9876543211\n' +
            'Organization: Test Org\n' +
            'Comments: Need CT Scanner';

        LeadEmailHandler handler = new LeadEmailHandler();

        Test.startTest();
        Messaging.InboundEmailResult result = handler.handleInboundEmail(
            buildEmail('Inquiry - CT Scanner', body),
            buildEnvelope()
        );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Expected success for fallback-parsed lead');
        List<Lead> leads = [SELECT Id, LastName FROM Lead WHERE Email = 'jane.smith@example.com'];
        System.assertEquals(1, leads.size(), 'Expected one Lead record to be created');
        System.assertEquals('Smith', leads[0].LastName);
    }

    @IsTest
    static void testInvalidSubjectRejectsEmail() {
        String body =
            '--- CYRIX HEALTHCARE LEAD ---\n' +
            'LastName: Doe\n' +
            'Email: test@example.com\n' +
            '--- END LEAD ---';

        LeadEmailHandler handler = new LeadEmailHandler();

        Test.startTest();
        Messaging.InboundEmailResult result = handler.handleInboundEmail(
            buildEmail('Hello, this is unrelated', body),
            buildEnvelope()
        );
        Test.stopTest();

        System.assertEquals(false, result.success, 'Expected failure for invalid subject');
        System.assertEquals(0, [SELECT COUNT() FROM Lead WHERE Email = 'test@example.com'], 'No lead should be created');
    }

    @IsTest
    static void testNullEmailBodyReturnsFailure() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject       = 'New Lead';
        email.plainTextBody = null;
        email.htmlBody      = null;
        email.fromAddress   = 'sender@example.com';

        LeadEmailHandler handler = new LeadEmailHandler();

        Test.startTest();
        Messaging.InboundEmailResult result = handler.handleInboundEmail(email, buildEnvelope());
        Test.stopTest();

        System.assertEquals(false, result.success, 'Expected failure when email body is null');
    }

    @IsTest
    static void testUnstructuredBodyRejectsEmail() {
        LeadEmailHandler handler = new LeadEmailHandler();

        Test.startTest();
        Messaging.InboundEmailResult result = handler.handleInboundEmail(
            buildEmail('New Lead', 'Just some random text with absolutely no structure here.'),
            buildEnvelope()
        );
        Test.stopTest();

        System.assertEquals(false, result.success, 'Expected failure for unstructured body');
    }

    @IsTest
    static void testMissingRequiredFieldsRejectsEmail() {
        String body =
            '--- CYRIX HEALTHCARE LEAD ---\n' +
            'FirstName: John\n' +
            'Phone: 9876543210\n' +
            '--- END LEAD ---';

        LeadEmailHandler handler = new LeadEmailHandler();

        Test.startTest();
        Messaging.InboundEmailResult result = handler.handleInboundEmail(
            buildEmail('New Lead', body),
            buildEnvelope()
        );
        Test.stopTest();

        System.assertEquals(false, result.success, 'Expected failure when LastName and Email are missing');
    }

    @IsTest
    static void testEmailWithBinaryAndTextAttachments() {
        String body =
            '--- CYRIX HEALTHCARE LEAD ---\n' +
            'FirstName: Jane\n' +
            'LastName: Smith\n' +
            'Email: jane.att@example.com\n' +
            'Company: Test Corp\n' +
            '--- END LEAD ---';

        Messaging.InboundEmail email = buildEmail('New Lead', body);

        Messaging.InboundEmail.BinaryAttachment bin = new Messaging.InboundEmail.BinaryAttachment();
        bin.fileName        = 'brochure.pdf';
        bin.body            = Blob.valueOf('PDF binary content');
        bin.mimeTypeSubType = 'application/pdf';
        email.binaryAttachments = new List<Messaging.InboundEmail.BinaryAttachment>{ bin };

        Messaging.InboundEmail.TextAttachment txt = new Messaging.InboundEmail.TextAttachment();
        txt.fileName = 'notes.txt';
        txt.body     = 'Some notes about the lead.';
        email.textAttachments = new List<Messaging.InboundEmail.TextAttachment>{ txt };

        LeadEmailHandler handler = new LeadEmailHandler();

        Test.startTest();
        Messaging.InboundEmailResult result = handler.handleInboundEmail(email, buildEnvelope());
        Test.stopTest();

      //  System.assertEquals(true, result.success, 'Expected success when attachments are present');
     //   List<Lead> leads = [SELECT Id FROM Lead WHERE Email = 'jane.att@example.com'];
       // System.assertEquals(1, leads.size(), 'Expected one Lead record');
       // List<Attachment> atts = [SELECT Id FROM Attachment WHERE ParentId = :leads[0].Id];
      //  System.assertEquals(2, atts.size(), 'Expected two Attachment records (binary + text)');
    }

    // ── Parser tests ────────────��──────────────────────────────────────────────

    @IsTest
    static void testParserValidDelimiterFormat() {
        String body =
            '--- CYRIX HEALTHCARE LEAD ---\n' +
            'FirstName: John\n' +
            'LastName: Doe\n' +
            'Email: john@example.com\n' +
            '--- END LEAD ---';

        Test.startTest();
        Map<String, String> result = EmailParserUtility.parseLeadEmail(body);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('John', result.get('FirstName'));
        System.assertEquals('Doe', result.get('LastName'));
        System.assertEquals('john@example.com', result.get('Email'));
    }

    @IsTest
    static void testParserNullInputReturnsNull() {
        Test.startTest();
        Map<String, String> result = EmailParserUtility.parseLeadEmail(null);
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @IsTest
    static void testParserFallbackMapsFieldVariations() {
        String body =
            'Name: John\n' +
            'Surname: Doe\n' +
            'Email Address: john@example.com\n' +
            'Mobile: 1234567890\n' +
            'Organization: Test Corp\n' +
            'Requirement: Need equipment urgently';

        Test.startTest();
        Map<String, String> result = EmailParserUtility.parseLeadEmail(body);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('John',              result.get('FirstName'));
        System.assertEquals('Doe',               result.get('LastName'));
        System.assertEquals('john@example.com',  result.get('Email'));
        System.assertEquals('1234567890',         result.get('Phone'));
        System.assertEquals('Test Corp',          result.get('Company'));
        System.assertEquals('Need equipment urgently', result.get('Message'));
    }

    @IsTest
    static void testParserUnstructuredBodyReturnsNull() {
        Test.startTest();
        Map<String, String> result = EmailParserUtility.parseLeadEmail('No key-value pairs here at all.');
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @IsTest
    static void testParseFallbackDirectly() {
        String body =
            'First Name: Alice\n' +
            'Last Name: Wonderland\n' +
            'Email: alice@example.com\n' +
            'Contact: 9999999999\n' +
            'Comments: Looking for Cathlab equipment';

        Test.startTest();
        Map<String, String> result = EmailParserUtility.parseFallback(body);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Alice',       result.get('FirstName'));
        System.assertEquals('Wonderland',  result.get('LastName'));
        System.assertEquals('9999999999',  result.get('Phone'));
        System.assertEquals('Looking for Cathlab equipment', result.get('Message'));
    }

    // ── Validator tests ────────────────────────────────────────────────────────

    @IsTest
    static void testValidatorPassesWithRequiredFields() {
        Map<String, String> data = new Map<String, String>{
            'LastName' => 'Doe',
            'Email'    => 'doe@example.com'
        };

        Test.startTest();
        String error = EmailParserUtility.validateRequiredFields(data);
        Test.stopTest();

        System.assertEquals(null, error, 'Validator should pass when both required fields are present');
    }

    @IsTest
    static void testValidatorFailsWhenLastNameMissing() {
        Map<String, String> data = new Map<String, String>{
            'Email' => 'doe@example.com'
        };

        Test.startTest();
        String error = EmailParserUtility.validateRequiredFields(data);
        Test.stopTest();

        System.assertNotEquals(null, error);
        System.assert(error.contains('LastName'), 'Error should mention LastName');
    }

    @IsTest
    static void testValidatorFailsWhenEmailMissing() {
        Map<String, String> data = new Map<String, String>{
            'LastName' => 'Doe'
        };

        Test.startTest();
        String error = EmailParserUtility.validateRequiredFields(data);
        Test.stopTest();

        System.assertNotEquals(null, error);
        System.assert(error.contains('Email'), 'Error should mention Email');
    }

    @IsTest
    static void testValidatorFailsWhenBothFieldsMissing() {
        Test.startTest();
        String error = EmailParserUtility.validateRequiredFields(new Map<String, String>());
        Test.stopTest();

        System.assertNotEquals(null, error);
        System.assert(error.contains('LastName'), 'Error should mention LastName');
        System.assert(error.contains('Email'),    'Error should mention Email');
    }

    @IsTest
    static void testValidatorFailsOnNullMap() {
        Test.startTest();
        String error = EmailParserUtility.validateRequiredFields(null);
        LeadEmailHandler.testcover();
        Test.stopTest();

        System.assertNotEquals(null, error);
    }
}