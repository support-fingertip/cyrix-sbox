@RestResource(urlMapping='/WhatsAppWebhookApi')
global class WhatsAppLeadCreator {
    
    @HttpPost
    global static void createLeadFromWhatsApp() {
        try {
            RestRequest req = RestContext.request;
            String requestBody = req.requestBody.toString();
            System.debug('Received payload: ' + requestBody);
            
            // Parse the JSON payload
            WhatsAppWebhookPayload payload = (WhatsAppWebhookPayload) JSON.deserialize(requestBody, WhatsAppWebhookPayload.class);
            
            // Validate payload structure
            if (payload == null || 
                payload.whatsapp_webhook_payload == null || 
                payload.whatsapp_webhook_payload.entry == null || 
                payload.whatsapp_webhook_payload.entry.isEmpty() ||
                payload.whatsapp_webhook_payload.entry[0].changes == null ||
                payload.whatsapp_webhook_payload.entry[0].changes.isEmpty() ||
                payload.whatsapp_webhook_payload.entry[0].changes[0].value.messages == null ||
                payload.whatsapp_webhook_payload.entry[0].changes[0].value.messages.isEmpty()) {
                
                RestContext.response.statusCode = 400;
                RestContext.response.responseBody = Blob.valueOf(JSON.serialize(new Response('Error', 'Invalid payload structure', null)));
                return;
            }
            
            // Extract relevant data
            Message msg = payload.whatsapp_webhook_payload.entry[0].changes[0].value.messages[0];
            String contactPhone = msg.from_number;
            String messageBody = msg.text != null ? msg.text.body : '';
            String messageType = msg.type;
            
            // Skip non-text messages
            if (messageType != 'text') {
                RestContext.response.statusCode = 200;
                RestContext.response.responseBody = Blob.valueOf(JSON.serialize(new Response('Success', 'Non-text message ignored', null)));
                return;
            }
            
            // Extract contact info with null checks
            String firstName = payload.contact != null && payload.contact.first_name != null ? 
                              payload.contact.first_name.replace('~', '') : '';
            String lastName = payload.contact != null && payload.contact.last_name != null ? 
                             payload.contact.last_name.trim() : '';
            String email = payload.contact != null ? payload.contact.email : null;
            String country = payload.contact != null ? payload.contact.country : null;
            String contactUid = payload.contact != null ? payload.contact.uid : null;
            
            // Try to get name from WhatsApp profile if contact name is empty
            if (String.isBlank(firstName) && String.isBlank(lastName)) {
                if (payload.whatsapp_webhook_payload.entry[0].changes[0].value.contacts != null &&
                   !payload.whatsapp_webhook_payload.entry[0].changes[0].value.contacts.isEmpty() &&
                   payload.whatsapp_webhook_payload.entry[0].changes[0].value.contacts[0].profile != null) {
                    String profileName = payload.whatsapp_webhook_payload.entry[0].changes[0].value.contacts[0].profile.name;
                    if (String.isNotBlank(profileName)) {
                        // Simple name parsing - split by space
                        List<String> nameParts = profileName.split(' ');
                        if (nameParts.size() >= 1) {
                            firstName = nameParts[0];
                            if (nameParts.size() > 1) {
                                // Build last name from remaining parts
                                lastName = '';
                                for (Integer i = 1; i < nameParts.size(); i++) {
                                    if (i > 1) lastName += ' ';
                                    lastName += nameParts[i];
                                }
                            }
                        }
                    }
                }
            }
            
            // Create Lead
            Lead newLead = new Lead();
            newLead.FirstName = String.isNotBlank(firstName) ? firstName : 'WhatsApp';
            newLead.LastName = String.isNotBlank(lastName) ? lastName : 'Contact';
            newLead.Email = email;
            newLead.Country = country;
            newLead.Company = 'WhatsApp Prospect';
            newLead.Phone = formatPhoneNumber(contactPhone);
            newLead.LeadSource = 'WhatsApp';
            newLead.Status = 'Open - Not Contacted';
            
            // Build description
            String description = 'Created from WhatsApp message: ' + messageBody + '\n';
            description += 'Message Type: ' + messageType + '\n';
            description += 'Message ID: ' + msg.id + '\n';
            description += 'Timestamp: ' + Datetime.newInstance(Long.valueOf(msg.timestamp) * 1000) + '\n';
            if (String.isNotBlank(contactUid)) {
                description += 'Contact UID: ' + contactUid + '\n';
            }
            
            newLead.Description = description;
            
            // Check for duplicates based on email or phone
            Lead existingLead = findDuplicateLead(email, newLead.Phone);
            
            if (existingLead != null) {
                // Update existing lead
                String existingDesc = existingLead.Description != null ? existingLead.Description : '';
                existingLead.Description = existingDesc + '\n--- New WhatsApp Message ---\n' + 
                                          Datetime.now().format() + ': ' + messageBody + '\n';
                
                // Update other fields if they're empty
                if (String.isBlank(existingLead.FirstName) && String.isNotBlank(firstName)) {
                    existingLead.FirstName = firstName;
                }
                if (String.isBlank(existingLead.LastName) && String.isNotBlank(lastName)) {
                    existingLead.LastName = lastName;
                }
                if (String.isBlank(existingLead.Email) && String.isNotBlank(email)) {
                    existingLead.Email = email;
                }
                if (String.isBlank(existingLead.Country) && String.isNotBlank(country)) {
                    existingLead.Country = country;
                }
                
                update existingLead;
                
                RestContext.response.statusCode = 200;
                RestContext.response.responseBody = Blob.valueOf(JSON.serialize(new Response('Success', 'Lead updated', existingLead.Id)));
            } else {
                // Insert new lead
                insert newLead;
                
                RestContext.response.statusCode = 201;
                RestContext.response.responseBody = Blob.valueOf(JSON.serialize(new Response('Success', 'Lead created', newLead.Id)));
            }
            
        } catch (Exception e) {
            System.debug('Error creating lead: ' + e.getMessage() + ' | ' + e.getStackTraceString());
            RestContext.response.statusCode = 500;
            RestContext.response.responseBody = Blob.valueOf(JSON.serialize(new Response('Error', e.getMessage(), null)));
        }
    }
    
    private static Lead findDuplicateLead(String email, String phone) {
        List<Lead> existingLeads = new List<Lead>();
        
        if (String.isNotBlank(email)) {
            existingLeads = [SELECT Id, FirstName, LastName, Email, Phone, Description 
                            FROM Lead 
                            WHERE (Email = :email OR Phone = :phone) 
                            AND IsConverted = false 
                            LIMIT 1];
        } else if (String.isNotBlank(phone)) {
            existingLeads = [SELECT Id, FirstName, LastName, Email, Phone, Description 
                            FROM Lead 
                            WHERE Phone = :phone 
                            AND IsConverted = false 
                            LIMIT 1];
        }
        
        return existingLeads.isEmpty() ? null : existingLeads[0];
    }
    
    private static String formatPhoneNumber(String phone) {
        if (String.isBlank(phone)) return null;
        
        // Remove non-numeric characters
        String cleanedPhone = phone.replaceAll('\\D', '');
        
        // If it starts with 91 and has 12 digits (country code + 10 digits)
        if (cleanedPhone.startsWith('91') && cleanedPhone.length() == 12) {
            return '+' + cleanedPhone;
        } 
        // If it's 10 digits, add +91
        else if (cleanedPhone.length() == 10) {
            return '+91' + cleanedPhone;
        }
        // If it's already in international format
        else if (cleanedPhone.length() > 10) {
            return '+' + cleanedPhone;
        }
        
        return phone;
    }
    
    // Inner classes for JSON parsing
    public class WhatsAppWebhookPayload {
        public ContactInfo contact;
        public WhatsAppWebhookPayloadData whatsapp_webhook_payload;
    }
    
    public class ContactInfo {
        public String status;
        public String uid;
        public String first_name;
        public String last_name;
        public String email;
        public String language_code;
        public String country;
    }
    
    public class WhatsAppWebhookPayloadData {
        // Use a custom property to handle reserved keyword 'object'
        public String object_type { get; set; }
        
        // Custom deserialization for 'object' field
        public void setObject(String obj) {
            this.object_type = obj;
        }
        
        public List<Entry> entry;
    }
    
    public class Entry {
        public String id;
        public List<Change> changes;
    }
    
    public class Change {
        public ChangeValue value;
        public String field;
    }
    
    public class ChangeValue {
        public String messaging_product;
        public Metadata metadata;
        public List<Contact> contacts;
        public List<Message> messages;
    }
    
    public class Metadata {
        public String display_phone_number;
        public String phone_number_id;
    }
    
    public class Contact {
        public Profile profile;
        public String wa_id;
    }
    
    public class Profile {
        public String name;
    }
    
    public class Message {
        // Custom property to handle reserved keyword 'from'
        public String from_number { get; set; }
        
        // Custom deserialization for 'from' field
        public void setFrom(String fromValue) {
            this.from_number = fromValue;
        }
        
        public String id;
        public String timestamp;
        public Text text;
        public String type;
    }
    
    public class Text {
        public String body;
    }
    
    // Response wrapper class
    public class Response {
        public String status;
        public String message;
        public String leadId;
        
        public Response(String status, String message, String leadId) {
            this.status = status;
            this.message = message;
            this.leadId = leadId;
        }
    }
}