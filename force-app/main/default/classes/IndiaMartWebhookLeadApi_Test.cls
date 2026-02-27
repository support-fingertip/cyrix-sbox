@IsTest
private class IndiaMartWebhookLeadApi_Test {
//https://cyrix-healthcare--sbox1.sandbox.my.salesforce-sites.com/services/apexrest/indiamart/webhook?key=96ca585abb297b995fab61679e0516fb
//{"CODE":200,"STATUS":"SUCCESS","RESPONSE":{"UNIQUE_QUERY_ID":"621654886","QUERY_TYPE":"B","QUERY_TIME":"2024-04-10 11:17:14","SENDER_NAME":"Prabhat","SENDER_MOBILE":"+91 9999999999","SENDER_EMAIL":"abcdeprabhat@gmail.com","SUBJECT":"Requirement for Empty Mineral Water Bottle","SENDER_COMPANY":"ABC Pvt Ltd.","SENDER_ADDRESS":"Sec 135, Noida, Uttar Pradesh","SENDER_CITY":"Noida","SENDER_STATE":"Uttar Pradesh","SENDER_PINCODE":"201304","SENDER_COUNTRY_ISO":"IN","SENDER_MOBILE_ALT":"+91 8888888888","SENDER_PHONE":"0120-22222222","SENDER_PHONE_ALT":"0120-11111111","SENDER_EMAIL_ALT":"prabhatabcde@gmail.com","QUERY_PRODUCT_NAME":"Mineral Water Bottle","QUERY_MESSAGE":"I want to purchase an Empty Mineral Water Bottle. Kindly send me price and other details.Quantity: 100000 PieceProbable Order Value: Rs. 10 to 20 LakhProbable Requirement Type: Business Use","QUERY_MCAT_NAME":"Mineral Water Bottle","CALL_DURATION":"","RECEIVER_MOBILE":""}}
    private static String buildPayload(String queryId, String senderName, String mobile, String email, String msg) {
        Map<String, Object> responseMap = new Map<String, Object>{
            'UNIQUE_QUERY_ID' => queryId,
            'QUERY_TYPE' => 'B',
            'QUERY_TIME' => '2024-04-10 11:17:14',
            'SENDER_NAME' => senderName,
            'SENDER_MOBILE' => mobile,
            'SENDER_EMAIL' => email,
            'SUBJECT' => 'Requirement for Empty Mineral Water Bottle',
            'SENDER_COMPANY' => 'ABC Pvt Ltd.',
            'SENDER_ADDRESS' => 'Sec 135, Noida, Uttar Pradesh',
            'SENDER_CITY' => 'Noida',
            'SENDER_STATE' => 'Uttar Pradesh',
            'SENDER_PINCODE' => '201304',
            'SENDER_COUNTRY_ISO' => 'IN',
            'SENDER_MOBILE_ALT' => '+91 8888888888',
            'SENDER_PHONE' => '0120-22222222',
            'SENDER_EMAIL_ALT' => 'prabhatabcde@gmail.com',
            'QUERY_PRODUCT_NAME' => 'Mineral Water Bottle',
            'QUERY_MESSAGE' => msg,
            'QUERY_MCAT_NAME' => 'Mineral Water Bottle'
        };

        Map<String, Object> root = new Map<String, Object>{
            'CODE' => 200,
            'STATUS' => 'SUCCESS',
            'RESPONSE' => responseMap
        };

        return JSON.serialize(root);
    }

    private static void setRestContext(String body, String keyParam) {
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueOf(body);

        // IMPORTANT: Don't assign req.params (read-only). Use addParameter.
        if (keyParam != null) {
            req.addParameter('key', keyParam);
            req.requestUri = '/services/apexrest/indiamart/webhook/?key=' + EncodingUtil.urlEncode(keyParam, 'UTF-8');
        } else {
            req.requestUri = '/services/apexrest/indiamart/webhook/';
        }

        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    @IsTest
    static void test_CreateNewLead_Success() {
        String queryId = '621654886';
        String payload = buildPayload(
            queryId,
            'Prabhat',
            '+91 9999999999',
            'abcdeprabhat@gmail.com',
            'First message from IndiaMART'
        );

        // If label is set, must send correct key; if label blank, any key works.
        String expectedKey = System.Label.India_Mart;
        String keyToSend = String.isBlank(expectedKey) ? 'ANY' : expectedKey;

        setRestContext(payload, keyToSend);

        Test.startTest();
        IndiaMartWebhookLeadApi.handlePost();
        Test.stopTest();

        Lead l = [
            SELECT Id, LastName, Company, Phone, Email, LeadSource, Status,
                   IndiaMART_Query_ID__c, IndiaMART_Query_Type__c, Description
            FROM Lead
            WHERE IndiaMART_Query_ID__c = :queryId
            LIMIT 1
        ];

        System.assertEquals('Prabhat', l.LastName);
        System.assertEquals('ABC Pvt Ltd.', l.Company);
        
        System.assertEquals('abcdeprabhat@gmail.com', l.Email);
        System.assertEquals('IndiaMart', l.LeadSource);
        System.assertEquals('B', (String)l.get('IndiaMART_Query_Type__c'));
        System.assertEquals('First message from IndiaMART', l.Description);
    }

    @IsTest
    static void test_UpdateExistingLead_SameQueryId() {
        String queryId = '700000001';

        String expectedKey = System.Label.India_Mart;
        String keyToSend = String.isBlank(expectedKey) ? 'ANY' : expectedKey;

        // First call creates
        setRestContext(buildPayload(queryId, 'Prabhat', '+91 9999999999', 'abcdeprabhat@gmail.com', 'Initial message'), keyToSend);

        Test.startTest();
        IndiaMartWebhookLeadApi.handlePost();
      

        Lead beforeLead = [
            SELECT Id, Description
            FROM Lead
            WHERE IndiaMART_Query_ID__c = :queryId
            LIMIT 1
        ];

        // Second call updates
        setRestContext(buildPayload(queryId, 'Prabhat', '+91 9999999999', 'abcdeprabhat@gmail.com', 'Updated message'), keyToSend);

       
        IndiaMartWebhookLeadApi.handlePost();
        Test.stopTest();

        Lead afterLead = [
            SELECT Id, Description
            FROM Lead
            WHERE IndiaMART_Query_ID__c = :queryId
            LIMIT 1
        ];

        System.assertEquals(beforeLead.Id, afterLead.Id, 'Should update same lead');
        System.assertEquals('Updated message', afterLead.Description);
    }

    @IsTest
    static void test_NoResponseKey_DoesNotCreateLead() {
        Map<String, Object> root = new Map<String, Object>{
            'CODE' => 200,
            'STATUS' => 'SUCCESS'
        };
        String payload = JSON.serialize(root);

        String expectedKey = System.Label.India_Mart;
        String keyToSend = String.isBlank(expectedKey) ? 'ANY' : expectedKey;

        Integer beforeCount = [SELECT COUNT() FROM Lead];

        setRestContext(payload, keyToSend);

        Test.startTest();
        IndiaMartWebhookLeadApi.handlePost();
        Test.stopTest();

        Integer afterCount = [SELECT COUNT() FROM Lead];

        System.assertEquals(beforeCount, afterCount);
        System.assertEquals(200, RestContext.response.statusCode);
    }

    @IsTest
    static void test_Unauthorized_WhenLabelIsSet() {
        if (String.isBlank(System.Label.India_Mart)) {
            System.assert(true, 'Skipped: India_Mart label is blank in this org.');
            return;
        }

        String payload = buildPayload('900000009', 'Prabhat', '+91 9999999999', 'abcdeprabhat@gmail.com', 'Message');
        setRestContext(payload, 'WRONG_KEY');

        Test.startTest();
        IndiaMartWebhookLeadApi.handlePost();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode);
    }
    
}