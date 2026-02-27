@isTest
private class WhatsAppWebhookControllerTest {

    @testSetup
    static void setup() {
        // Create a test user with Default_TeleCaller__c = true
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'tcaller',
            Email = 'testcaller@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'TeleCaller',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testcaller' + DateTime.now().getTime() + '@example.com',
            Default_TeleCaller__c = true
        );
        insert testUser;
    }

    @isTest
    static void testTextMessageNewLead() {
        String payload = '{' +
            '"object":"whatsapp_business_account",' +
            '"entry":[{ ' +
                '"id":"1385027422565974",' +
                '"changes":[{ ' +
                    '"value":{ ' +
                        '"messaging_product":"whatsapp",' +
                        '"metadata":{ ' +
                            '"display_phone_number":"918891199950",' +
                            '"phone_number_id":"773209739218458"' +
                        '},' +
                        '"contacts":[{ ' +
                            '"profile":{"name":"Steven Antalap"},' +
                            '"wa_id":"6745564029"' +
                        '}],' +
                        '"messages":[{ ' +
                            '"from":"6745564029",' +
                            '"id":"wamid.HBgKNjc0NTU2NDAyORUCABIYIEFDMTExOTc0NThFRDNBNjU2NUM0NTI0QzU4NjdEQjY0AA==",' +
                            '"timestamp":"1771820307",' +
                            '"type":"text",' +
                            '"text":{"body":"Hello from WhatsApp"}' +
                        '}]' +
                    '},' +
                    '"field":"messages"' +
                '}]' +
            '}]' +
        '}';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(payload);
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        WhatsAppWebhookController.handlePost();
        Test.stopTest();
    }

    @isTest
    static void testDocumentMessageNewLead() {
        String payload = '{' +
            '"object":"whatsapp_business_account",' +
            '"entry":[{ ' +
                '"id":"1385027422565974",' +
                '"changes":[{ ' +
                    '"value":{ ' +
                        '"messaging_product":"whatsapp",' +
                        '"metadata":{ ' +
                            '"display_phone_number":"918891199950",' +
                            '"phone_number_id":"773209739218458"' +
                        '},' +
                        '"contacts":[{ ' +
                            '"profile":{"name":"Steven Antalap"},' +
                            '"wa_id":"6745564029"' +
                        '}],' +
                        '"messages":[{ ' +
                            '"from":"6745564029",' +
                            '"id":"wamid.HBgKNjc0NTU2NDAyORUCABIYIEFDMTExOTc0NThFRDNBNjU2NUM0NTI0QzU4NjdEQjY0AA==",' +
                            '"timestamp":"1771820307",' +
                            '"type":"document",' +
                            '"document":{' +
                                '"filename":"2025 CV.docx",' +
                                '"mime_type":"application/vnd.openxmlformats-officedocument.wordprocessingml.document",' +
                                '"sha256":"/rTa8xOBCLuddFBmLkyrV0xh1q03lYBR2n9M+y0Wcn4=",' +
                                '"id":"921179920410821",' +
                                '"url":"https://lookaside.fbsbx.com/whatsapp_business/attachments/?mid=921179920410821&source=webhook&ext=1771820608&hash=ARl-bZvfCtQbuY0DBtowDAWuHcusvvsr7wZaNQosSwJCfw"' +
                            '}' +
                        '}]' +
                    '},' +
                    '"field":"messages"' +
                '}]' +
            '}]' +
        '}';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(payload);
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        WhatsAppWebhookController.handlePost();
        Test.stopTest();
    }

    @isTest
    static void testExistingLeadUpdate() {
        // Insert an existing Lead
        Lead existingLead = new Lead(
            LastName = 'Existing',
            Company = 'Test Co',
            WhatsApp_WA_ID__c = '6745564029',
            Phone = '6745564029'
        );
        insert existingLead;
WhatsAppWebhookController.setNamesFromFullName(existingLead,'yy');
        String payload = '{' +
            '"object":"whatsapp_business_account",' +
            '"entry":[{ ' +
                '"id":"1385027422565974",' +
                '"changes":[{ ' +
                    '"value":{ ' +
                        '"messaging_product":"whatsapp",' +
                        '"metadata":{ ' +
                            '"display_phone_number":"918891199950",' +
                            '"phone_number_id":"773209739218458"' +
                        '},' +
                        '"contacts":[{ ' +
                            '"profile":{"name":"Steven Antalap"},' +
                            '"wa_id":"6745564029"' +
                        '}],' +
                        '"messages":[{ ' +
                            '"from":"6745564029",' +
                            '"id":"wamid.HBgKNjc0NTU2NDAyORUCABIYIEFDMTExOTc0NThFRDNBNjU2NUM0NTI0QzU4NjdEQjY0AA==",' +
                            '"timestamp":"1771820307",' +
                            '"type":"text",' +
                            '"text":{"body":"Update message"}' +
                        '}]' +
                    '},' +
                    '"field":"messages"' +
                '}]' +
            '}]' +
        '}';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(payload);
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        WhatsAppWebhookController.handlePost();
        Test.stopTest();
    }

    @isTest
    static void testMultipleMessages() {
        String payload = '{' +
            '"object":"whatsapp_business_account",' +
            '"entry":[{ ' +
                '"id":"1385027422565974",' +
                '"changes":[{ ' +
                    '"value":{ ' +
                        '"messaging_product":"whatsapp",' +
                        '"metadata":{ ' +
                            '"display_phone_number":"918891199950",' +
                            '"phone_number_id":"773209739218458"' +
                        '},' +
                        '"contacts":[{ ' +
                            '"profile":{"name":"Steven Antalap"},' +
                            '"wa_id":"6745564029"' +
                        '}],' +
                        '"messages":[{ ' +
                            '"from":"6745564029",' +
                            '"id":"msg1",' +
                            '"timestamp":"1771820307",' +
                            '"type":"text",' +
                            '"text":{"body":"First message"}' +
                        '},' +
                        '{ ' +
                            '"from":"6745564029",' +
                            '"id":"msg2",' +
                            '"timestamp":"1771820308",' +
                            '"type":"text",' +
                            '"text":{"body":"Second message"}' +
                        '}]' +
                    '},' +
                    '"field":"messages"' +
                '}]' +
            '}]' +
        '}';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(payload);
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        WhatsAppWebhookController.handlePost();
        Test.stopTest();
    }


    @isTest
    static void testNoMessages() {
        String payload = '{' +
            '"object":"whatsapp_business_account",' +
            '"entry":[{ ' +
                '"id":"1385027422565974",' +
                '"changes":[{ ' +
                    '"value":{ ' +
                        '"messaging_product":"whatsapp",' +
                        '"metadata":{ ' +
                            '"display_phone_number":"918891199950",' +
                            '"phone_number_id":"773209739218458"' +
                        '},' +
                        '"contacts":[{ ' +
                            '"profile":{"name":"Steven Antalap"},' +
                            '"wa_id":"6745564029"' +
                        '}]' +
                    '},' +
                    '"field":"messages"' +
                '}]' +
            '}]' +
        '}';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(payload);
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        WhatsAppWebhookController.handlePost();
        Test.stopTest();
    }

    @isTest
    static void testInvalidJson() {
        String invalidPayload = 'This is not JSON';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(invalidPayload);
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        WhatsAppWebhookController.handlePost();
        Test.stopTest();
    }
}