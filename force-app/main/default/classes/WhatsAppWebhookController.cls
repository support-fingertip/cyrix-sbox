@RestResource(urlMapping='/whatsapp/webhook/*')
global  without sharing class WhatsAppWebhookController {

    @HttpPost
    global static void handlePost() {
          Integer maxSize = 32000;
        RestRequest req = RestContext.request;  // Get the incoming request
        RestResponse res = RestContext.response; // Get the outgoing response
           String requestBody = req.requestBody.toString(); // Get the JSON body
        Log__c log = new Log__c();
        log.Object__c='Whatsapp';
        if(requestBody.length() > maxSize ){
            log.Request__c = requestBody.substring(0, maxSize);
        }else{
            log.Request__c = requestBody;
        }
        // Read the body of the request
        String body = (req.requestBody == null) ? null : req.requestBody.toString();
        
        // If the body is blank, return a 400 error
        if (String.isBlank(body)) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('Missing request body');
             log.Response__c= 'Missing request body';
            log.Status_Code__c='400';
            insert log;
            return;
        }

        try {
            // Deserialize the incoming JSON into a Map
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(body);

            // Extract the first "value" from the entry/changes array (messages event)
            Map<String, Object> value = extractFirstValue(root);

            // If no value is found, acknowledge and return
            if (value == null) {
                res.statusCode = 200;
                res.responseBody = Blob.valueOf('No message value found');
                log.Response__c= string.valueof(res.responseBody);
                log.Status_Code__c='200';
                insert log;
                return;
            }

            // Process the extracted value (this will be the WhatsApp message)
            string waLeadId= processValue(value);
            if(waLeadId !=null){ log.Lead__c=waLeadId;}
            // Successfully processed the payload, send back a 200 OK
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('OK');
              log.Response__c= string.valueof(res.responseBody);
                log.Status_Code__c='200';
                insert log;
        } catch (Exception ex) {
            // Catch any errors (e.g., invalid JSON format) and return 400
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('Invalid JSON: ' + ex.getMessage());
              log.Response__c= string.valueof(res.responseBody);
                log.Status_Code__c='400';
                insert log;
        }
    }

    /* =========================
       Extraction + Processing
       ========================= */

    // Extracts the first message value from the entry/changes array
    private static Map<String, Object> extractFirstValue(Map<String, Object> root) {
        if (root == null) return null;

        List<Object> entry = (List<Object>) root.get('entry');
        if (entry == null || entry.isEmpty()) return null;

        for (Object eObj : entry) {
            Map<String, Object> e = (Map<String, Object>) eObj;
            if (e == null) continue;

            // Extract changes from entry
            List<Object> changes = (List<Object>) e.get('changes');
            if (changes == null || changes.isEmpty()) continue;

            for (Object cObj : changes) {
                Map<String, Object> c = (Map<String, Object>) cObj;
                if (c == null) continue;

                // Extract value from change
                Map<String, Object> value = (Map<String, Object>) c.get('value');
                if (value == null) continue;

                // If the field is 'messages' or if messages exist, return the value
                String field = (String) c.get('field');
                List<Object> messages = (List<Object>) value.get('messages');
                if (field == 'messages' || (messages != null && !messages.isEmpty())) {
                    return value;
                }
            }
        }
        return null;
    }

    // Processes the extracted value and updates or creates a Lead
    private static string processValue(Map<String, Object> v) {
        if (v == null) return null;

        // Extract metadata (for phone number details)
        Map<String, Object> metadata = (Map<String, Object>) v.get('metadata');

        // Extract first contact (if available)
        Map<String, Object> contact0 = null;
        List<Object> contacts = (List<Object>) v.get('contacts');
        if (contacts != null && !contacts.isEmpty()) {
            contact0 = (Map<String, Object>) contacts[0];
        }

        // Extract first message (if available)
        Map<String, Object> msg0 = null;
        List<Object> messages = (List<Object>) v.get('messages');
        if (messages != null && !messages.isEmpty()) {
            msg0 = (Map<String, Object>) messages[0];
        }

        // Get the WhatsApp ID (phone number) from either contact or message
        String waId = (contact0 != null) ? (String) contact0.get('wa_id') : null;
        if (String.isBlank(waId) && msg0 != null) {
            waId = (String) msg0.get('from'); // Use "from" field from messages if no "wa_id"
        }
        if (String.isBlank(waId)) return null; // Exit if no WhatsApp ID (phone number) found

        // Extract full name from the contact profile (if available)
        String fullName = null;
        if (contact0 != null) {
            Map<String, Object> profile = (Map<String, Object>) contact0.get('profile');
            if (profile != null) {
                fullName = (String) profile.get('name');
            }
        }

        // Extract message body (text)
        String messageBody = null;
        String msgType = (msg0 != null) ? (String) msg0.get('type') : null;
        if (msg0 != null && msgType == 'text') {
            Map<String, Object> text = (Map<String, Object>) msg0.get('text');
            if (text != null) {
                messageBody = (String) text.get('body');
            }
        }

        // Extract message timestamp
        String ts = (msg0 != null) ? (String) msg0.get('timestamp') : null;
        Datetime messageTime = parseUnixSeconds(ts);

        // Find existing lead by WhatsApp ID
        Lead existing = findLeadByWaId(waId);

        // If lead exists, update it. Otherwise, create a new lead.
        if (existing == null) {
            Lead l = new Lead();
            applyLeadValues(l, waId, fullName, metadata, messageBody, messageTime);

            // Set required Lead fields
            if (String.isBlank(l.Company)) l.Company = 'WhatsApp Lead';
            if (String.isBlank(l.LastName)) l.LastName = deriveLastName(fullName);
         list<user> users =[select id from user where Default_TeleCaller__c=true];
                if(users.size() > 0){
                   l.OwnerId= users[0].Id;  
                }
             upsert l WhatsApp_WA_ID__c;
            return l.Id;
        } else {
            applyLeadValues(existing, waId, fullName, metadata, messageBody, messageTime);
            update existing;
            return existing.Id;
        }
    }

    /* =========================
       Lead helpers
       ========================= */

    // Finds a Lead by WhatsApp ID (waId)
    private static Lead findLeadByWaId(String waId) {
        List<Lead> leads = [
            SELECT Id, FirstName, LastName, Company,
                   WhatsApp_WA_ID__c,
                   Last_WhatsApp_Message__c,
                   Last_WhatsApp_Message_Time__c,
                   WhatsApp_PhoneNumberId__c,
                   WhatsApp_DisplayPhone__c
            FROM Lead
            WHERE WhatsApp_WA_ID__c = :waId
            LIMIT 1
        ];
        return leads.isEmpty() ? null : leads[0];
    }

    // Applies values to a Lead object
    private static void applyLeadValues(
        Lead l,
        String waId,
        String fullName,
        Map<String, Object> metadata,
        String messageBody,
        Datetime messageTime
    ) {
        // Set the WhatsApp ID
        l.WhatsApp_WA_ID__c = waId;

        // Set phone number to the "from" field (WhatsApp phone number)
        l.Phone = waId;  // Set the phone number field in Lead to the "from" number

        // Set the LeadSource to WhatsApp
        l.LeadSource = 'WhatsApp'; // Set Lead Source to "WhatsApp"

        // Name (don’t overwrite good CRM data)
        if (!String.isBlank(fullName)) {
            if (String.isBlank(l.FirstName) && String.isBlank(l.LastName)) {
                setNamesFromFullName(l, fullName);
            } else if (String.isBlank(l.LastName)) {
                l.LastName = deriveLastName(fullName);
            }
        }

        // Meta (for phone number details)
        if (metadata != null) {
            l.WhatsApp_DisplayPhone__c = (String) metadata.get('display_phone_number');
            l.WhatsApp_PhoneNumberId__c = (String) metadata.get('phone_number_id');
        }

        // Set message details
        if (!String.isBlank(messageBody)) {
            l.Last_WhatsApp_Message__c = messageBody;
        }
        if (messageTime != null) {
            l.Last_WhatsApp_Message_Time__c = messageTime;
        }
    }

    // Set names from full name (split into first and last names)
    private static void setNamesFromFullName(Lead l, String fullName) {
        String cleaned = fullName == null ? null : fullName.trim();
        if (String.isBlank(cleaned)) return;

        List<String> parts = cleaned.split('\\s+');

        if (parts.size() == 1) {
            l.LastName = parts[0];
            return;
        }

        l.FirstName = parts[0];

        String lastName = '';
        for (Integer i = 1; i < parts.size(); i++) {
            lastName += (i == 1 ? '' : ' ') + parts[i];
        }
        l.LastName = lastName;
    }

    // Derives a last name if not provided
    private static String deriveLastName(String fullName) {
        if (String.isBlank(fullName)) return 'WhatsApp';
        String cleaned = fullName.trim();
        return cleaned.length() > 80 ? cleaned.substring(0, 80) : cleaned;
    }

    // Convert Unix timestamp to Datetime
    private static Datetime parseUnixSeconds(String unixSecondsStr) {
        if (String.isBlank(unixSecondsStr)) return null;
        try {
            Long secsLong = Long.valueOf(unixSecondsStr);
            Integer secs = (secsLong > 2147483647) ? 2147483647 : Integer.valueOf(secsLong);
            return Datetime.newInstance(1970, 1, 1, 0, 0, 0).addSeconds(secs);
        } catch (Exception e) {
            return null;
        }
    }
}