@RestResource(urlMapping='/indiamart/webhook/*')
global without sharing class IndiaMartWebhookLeadApi {

    @HttpPost
    global static void handlePost() {

        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        Log__c log = new Log__c();
        log.Object__c = 'IndiaMART';

        Lead ld = new Lead();

        try {

            // ========= API KEY CHECK =========
            String expectedKey = System.Label.India_Mart;
            String incomingKey = req.params.get('key');

            if (String.isNotBlank(expectedKey) && incomingKey != expectedKey) {
                res.statusCode = 401;
                res.responseBody = Blob.valueOf('Unauthorized');
                log.Status_Code__c = '401';
                log.Response__c = 'Unauthorized';
                insert log;
                return;
            }

            // ========= RAW BODY =========
            if (req.requestBody == null) {
                res.statusCode = 200;
                res.responseBody = Blob.valueOf('Empty');
                return;
            }

            String raw = req.requestBody.toString();
            log.Request__c = raw.length() > 32000 ? raw.substring(0, 32000) : raw;

            // ========= PARSE JSON =========
            Map<String, Object> root =
                (Map<String, Object>) JSON.deserializeUntyped(raw);

            if (root == null || !root.containsKey('RESPONSE')) {
                res.statusCode = 200;
                res.responseBody = Blob.valueOf('No RESPONSE');
                insert log;
                return;
            }

            Map<String, Object> responseData =
                (Map<String, Object>) root.get('RESPONSE');

            // ========= EXTRACT VALUES =========
            String queryId     = getString(responseData, 'UNIQUE_QUERY_ID');
            String senderName  = getString(responseData, 'SENDER_NAME');
            String mobile      = normalizePhone(getString(responseData, 'SENDER_MOBILE'));
            String email       = getString(responseData, 'SENDER_EMAIL');
            String company     = getString(responseData, 'SENDER_COMPANY');
            String message     = getString(responseData, 'QUERY_MESSAGE');
            String product     = getString(responseData, 'QUERY_PRODUCT_NAME');
            String enquiryTime = getString(responseData, 'QUERY_TIME');
            String queryType   = getString(responseData, 'QUERY_TYPE');
            String subject     = getString(responseData, 'SUBJECT');
            String address     = getString(responseData, 'SENDER_ADDRESS');
            String city        = getString(responseData, 'SENDER_CITY');
            String state       = getString(responseData, 'SENDER_STATE');
            String pincode     = getString(responseData, 'SENDER_PINCODE');
            String country     = getString(responseData, 'SENDER_COUNTRY_ISO');
            String altMobile   = normalizePhone(getString(responseData, 'SENDER_MOBILE_ALT'));
            String altEmail    = getString(responseData, 'SENDER_EMAIL_ALT');
            String phone       = getString(responseData, 'SENDER_PHONE');
            String mcat        = getString(responseData, 'QUERY_MCAT_NAME');

            // ========= FIND EXISTING =========
            Lead existing = findLeadByQueryId(queryId);

            if (existing != null) {
                ld.Id = existing.Id;
            }

            // ========= REQUIRED FIELDS =========
            ld.LastName = String.isNotBlank(senderName) ? senderName : 'IndiaMART Lead';
            ld.Company  = String.isNotBlank(company) ? company : 'N/A';

            // ========= CORE FIELDS =========
            ld.Phone       = mobile;
            ld.Email       = email;
            ld.Description = message;
            ld.LeadSource  = 'IndiaMART';

            if (existing == null) {
                ld.Status = 'New';
            }

            // ========= CUSTOM FIELD MAPPING =========
            ld.put('IndiaMART_Query_ID__c', queryId);
            ld.put('IndiaMART_Query_Type__c', queryType);
            ld.put('IndiaMART_Product_Name__c', product);
            ld.put('IndiaMART_Enquiry_Date_Time__c', enquiryTime);
            ld.put('India_Mart_Subject__c', subject);
            ld.put('Address__c', address);
            ld.put('Location__c', city);
            ld.put('Webform_State__c', state);
            ld.put('Pin_Code__c', pincode);
            ld.put('webLead_country__c', country);
            ld.put('MobilePhone', altMobile);
            ld.put('Secondary_Email__c', altEmail);
            ld.put('India_Mart_Phone_No__c', phone);
            ld.put('India_Mart_MCAT_Name__c', mcat);

            // ========= ASSIGN DEFAULT TELECALLER (only for new leads) =========
            if (existing == null) {
                List<User> users = [
                    SELECT Id FROM User
                    WHERE Default_TeleCaller__c = true
                      AND IsActive = true
                    LIMIT 1
                ];
                if (!users.isEmpty()) {
                    string leadId =users[0].Id;
                    ld.put('OwnerId', leadId);
                }
            }

            // ========= SAVE =========
            if (Schema.sObjectType.Lead.fields.IndiaMART_Query_ID__c.isExternalId()) {
                Database.UpsertResult ur = Database.upsert(ld, Lead.Fields.IndiaMART_Query_ID__c, false);
                if (!ur.isSuccess()) {
                    String errMsg = '';
                    for (Database.Error err : ur.getErrors()) {
                        errMsg += err.getStatusCode() + ': ' + err.getMessage() + '; ';
                    }
                    log.Response__c = 'DML Error: ' + errMsg;
                    log.Status_Code__c = '500';
                    log.Data__c = String.valueOf(ld);
                    insert log;
                    res.statusCode = 200;
                    res.responseBody = Blob.valueOf('DML Error');
                    return;
                }
            } else {
                upsert ld;
            }
            log.Lead__c = ld.Id;
            log.Status_Code__c = '200';
            log.Response__c = 'Success';
            log.Data__c = String.valueOf(ld);
            insert log;

            res.statusCode = 200;
            res.responseBody = Blob.valueOf('Success');

        } catch (Exception e) {

            log.Status_Code__c = '500';
            log.Response__c = e.getMessage();
            insert log;

            Error_Log__c err = new Error_Log__c(
                LineNumber__c = e.getLineNumber(),
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Type__c = e.getTypeName(),
                User__c = UserInfo.getUserId(),
                RecordData__c = String.valueOf(ld)
            );
            insert err;

            res.statusCode = 200; // avoid retries
            res.responseBody = Blob.valueOf('Error');
        }
    }

    // ========= HELPERS =========

    private static String getString(Map<String, Object> data, String key) {
        if (data == null || !data.containsKey(key)) return null;
        Object val = data.get(key);
        return val == null ? null : String.valueOf(val).trim();
    }

    private static String normalizePhone(String s) {
        if (String.isBlank(s)) return null;
        return s.replaceAll('[^0-9+]', '');
    }

    private static Lead findLeadByQueryId(String queryId) {
        if (String.isBlank(queryId)) return null;

        List<Lead> lds = [
            SELECT Id
            FROM Lead
            WHERE IndiaMART_Query_ID__c = :queryId
            LIMIT 1
        ];
        return lds.isEmpty() ? null : lds[0];
    }
}