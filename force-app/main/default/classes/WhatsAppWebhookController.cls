@RestResource(urlMapping='/whatsapp/webhook/*')
global without sharing class WhatsAppWebhookController {

    @HttpPost
    global static void handlePost() {
        Integer maxSize = 32000;
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestBody = req.requestBody.toString();

        Log__c log = new Log__c();
        log.Object__c = 'Whatsapp';
        if (requestBody.length() > maxSize) {
            log.Request__c = requestBody.substring(0, maxSize);
        } else {
            log.Request__c = requestBody;
        }

        String body = (req.requestBody == null) ? null : req.requestBody.toString();

        if (String.isBlank(body)) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('Missing request body');
            log.Response__c = 'Missing request body';
            log.Status_Code__c = '400';
            insert log;
            return;
        }

        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(body);
            Map<String, Object> value = extractFirstValue(root);

            if (value == null) {
                res.statusCode = 200;
                res.responseBody = Blob.valueOf('No message value found');
                log.Response__c = 'No message value found';
                log.Status_Code__c = '200';
                insert log;
                return;
            }

            String waLeadId = processValue(value);
            if (waLeadId != null) {
                log.Lead__c = waLeadId;
            }

            res.statusCode = 200;
            res.responseBody = Blob.valueOf('OK');
            log.Response__c = 'OK';
            log.Status_Code__c = '200';
            insert log;

        } catch (Exception ex) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('Invalid JSON: ' + ex.getMessage());
            log.Response__c = 'Invalid JSON: ' + ex.getMessage();
            log.Status_Code__c = '400';
            insert log;
        }
    }

    /* =========================
       Extraction
       ========================= */

    private static Map<String, Object> extractFirstValue(Map<String, Object> root) {
        if (root == null) return null;

        List<Object> entry = (List<Object>) root.get('entry');
        if (entry == null || entry.isEmpty()) return null;

        for (Object eObj : entry) {
            Map<String, Object> e = (Map<String, Object>) eObj;
            if (e == null) continue;

            List<Object> changes = (List<Object>) e.get('changes');
            if (changes == null || changes.isEmpty()) continue;

            for (Object cObj : changes) {
                Map<String, Object> c = (Map<String, Object>) cObj;
                if (c == null) continue;

                Map<String, Object> value = (Map<String, Object>) c.get('value');
                if (value == null) continue;

                String field = (String) c.get('field');
                List<Object> messages = (List<Object>) value.get('messages');
                if (field == 'messages' || (messages != null && !messages.isEmpty())) {
                    return value;
                }
            }
        }
        return null;
    }

    /* =========================
       Main Processing (Lead + Messages)
       ========================= */

    private static String processValue(Map<String, Object> v) {
        if (v == null) return null;

        // Extract metadata
        Map<String, Object> metadata = (Map<String, Object>) v.get('metadata');

        // Extract first contact (profile info)
        Map<String, Object> contact0 = null;
        List<Object> contacts = (List<Object>) v.get('contacts');
        if (contacts != null && !contacts.isEmpty()) {
            contact0 = (Map<String, Object>) contacts[0];
        }

        // Extract all messages
        List<Object> messages = (List<Object>) v.get('messages');
        if (messages == null || messages.isEmpty()) {
            return null; // no messages to process
        }

        // Get sender WhatsApp ID (from the first message)
        Map<String, Object> firstMsg = (Map<String, Object>) messages[0];
        String waId = (String) firstMsg.get('from');
        if (String.isBlank(waId) && contact0 != null) {
            waId = (String) contact0.get('wa_id');
        }
        if (String.isBlank(waId)) return null;

        // Extract name from contact profile
        String fullName = null;
        if (contact0 != null) {
            Map<String, Object> profile = (Map<String, Object>) contact0.get('profile');
            if (profile != null) {
                fullName = (String) profile.get('name');
            }
        }

        // --- LEAD HANDLING ---
        Lead existingLead = findLeadByWaId(waId);
        Id leadId;

        if (existingLead == null) {
            // Create new Lead
            Lead newLead = new Lead();
            applyLeadValues(newLead, waId, fullName, metadata, null, null);
            if (String.isBlank(newLead.Company)) newLead.Company = 'WhatsApp Lead';
            if (String.isBlank(newLead.LastName)) newLead.LastName = deriveLastName(fullName);

            List<User> users = [SELECT Id FROM User WHERE Default_TeleCaller__c = true LIMIT 1];
            if (!users.isEmpty()) {
                newLead.OwnerId = users[0].Id;
            }

            upsert newLead WhatsApp_WA_ID__c;  // uses external id
            leadId = newLead.Id;
        } else {
            // Optionally update existing Lead with latest info (e.g., name)
            applyLeadValues(existingLead, waId, fullName, metadata, null, null);
            update existingLead;
            leadId = existingLead.Id;
        }

        // --- MESSAGE STORAGE ---
        List<WhatsApp_Message__c> msgRecords = new List<WhatsApp_Message__c>();
        for (Object msgObj : messages) {
            Map<String, Object> msg = (Map<String, Object>) msgObj;
            WhatsApp_Message__c msgRec = createMessageRecord(leadId, msg, metadata, waId);
            if (msgRec != null) {
                msgRecords.add(msgRec);
            }
        }
        if (!msgRecords.isEmpty()) {
            insert msgRecords;
        }

        return leadId;
    }

    /* =========================
       Helper: Create Message Record
       ========================= */

    private static WhatsApp_Message__c createMessageRecord(
            Id leadId,
            Map<String, Object> msg,
            Map<String, Object> metadata,
            String waId) {

        if (msg == null) return null;

        WhatsApp_Message__c m = new WhatsApp_Message__c();
        m.Lead__c = leadId;
        m.From__c = waId;
        m.Message_ID__c = (String) msg.get('id');

        // Timestamp
        String ts = (String) msg.get('timestamp');
        if (String.isNotBlank(ts)) {
            m.Timestamp__c = parseUnixSeconds(ts);
        }

        // To (your display phone number)
        if (metadata != null) {
            m.To__c = (String) metadata.get('display_phone_number');
        }

        // Type
        String type = (String) msg.get('type');
        m.Type__c = type;

        // Handle different content types
        if ('text'.equals(type)) {
            Map<String, Object> textMap = (Map<String, Object>) msg.get('text');
            if (textMap != null) {
                m.Message__c = (String) textMap.get('body');
            }
        } else if ('document'.equals(type)) {
            Map<String, Object> docMap = (Map<String, Object>) msg.get('document');
            if (docMap != null) {
                m.Document_Filename__c = (String) docMap.get('filename');
                m.Document_MimeType__c = (String) docMap.get('mime_type');
                m.Document_URL__c = (String) docMap.get('url');
                m.Media_ID__c = (String) docMap.get('id');
            }
        }
        // Add support for other types (image, audio, video, location, etc.) as needed

        return m;
    }

    /* =========================
       Lead Helpers
       ========================= */

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

    private static void applyLeadValues(Lead l,String waId, String fullName,
            Map<String, Object> metadata,String messageBody,Datetime messageTime) {

        l.WhatsApp_WA_ID__c = waId;
        l.Phone = '+'+waId;
        l.LeadSource = 'WhatsApp';

        // Set name if not already present (but don't overwrite good data)
        if (!String.isBlank(fullName)) {
            if (String.isBlank(l.FirstName) && String.isBlank(l.LastName)) {
                setNamesFromFullName(l, fullName);
            } else if (String.isBlank(l.LastName)) {
                l.LastName = deriveLastName(fullName);
            }
        }

        if (metadata != null) {
            l.WhatsApp_DisplayPhone__c = (String) metadata.get('display_phone_number');
            l.WhatsApp_PhoneNumberId__c = (String) metadata.get('phone_number_id');
        }

        if (!String.isBlank(messageBody)) {
            l.Last_WhatsApp_Message__c = messageBody;
        }
        if (messageTime != null) {
            l.Last_WhatsApp_Message_Time__c = messageTime;
        }
    }

    public static void setNamesFromFullName(Lead l, String fullName) {
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

    private static String deriveLastName(String fullName) {
        if (String.isBlank(fullName)) return 'WhatsApp';
        String cleaned = fullName.trim();
        return cleaned.length() > 80 ? cleaned.substring(0, 80) : cleaned;
    }

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