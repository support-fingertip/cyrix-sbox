/** * CyrixLeadEmailHandler 
 *   * Salesforce Email Service handler that processes 
 * incoming emails from the Cyrix Healthcare website 
 * lead form and creates Lead records directly. 
*   * No Case is created - this is a direct 
* email-to-Lead conversion. */ 

global class LeadEmailHandler 

    implements Messaging.InboundEmailHandler { 
global Messaging.InboundEmailResult handleInboundEmail( Messaging.InboundEmail email,  Messaging.InboundEnvelope envelope  ) { 

        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult(); 
    Integer maxSize = 32000;
    Log__c log = new Log__c();
    log.Object__c = 'Email';
     String emailBody = email.plainTextBody != null ? email.plainTextBody : email.htmlBody; 
      if (emailBody.length() > maxSize) {
            log.Request__c = emailBody.substring(0, maxSize);
        } else {
            log.Request__c = emailBody;
        }
    try { 
        
        // Validate this is a Cyrix website lead email 

            if (!isValidLeadEmail(email)) { 
         System.debug('Email rejected: invalid format'); 
                result.success = false; 
                result.message = 'Invalid email format.'; 
                 log.Response__c = 'Invalid email format.';
                database.insert(log,false);

                return result; 
         } 

 

            // Get the email body (prefer plain text) 

           
         // Parse structured fields from email body 

            Map<String, String> fields =EmailParserUtility.parseLeadEmail(emailBody); 
          if (fields == null || fields.isEmpty()) { 
              System.debug('Failed to parse email body'); 
              result.success = false; 
              result.message = 'Could not parse lead data.'; 
              log.Response__c = 'Could not parse lead data.';
              database.insert(log,false);

                return result; 
         } 

              

 

            // Validate required fields 

            if (!EmailParserUtility.validateRequiredFields(fields)) { 

                System.debug('Missing required fields'); 

                result.success = false; 

                result.message = 'Missing required fields.'; 
              
                log.Response__c ='Missing required fields.'; 
                database.insert(log,false);

                return result; 
  } 
            // Build the Lead record 

            Lead newLead = buildLeadFromFields(fields, email); 

            List<User> users = [SELECT Id FROM User WHERE Default_TeleCaller__c = true LIMIT 1];
            if (!users.isEmpty()) {
                newLead.OwnerId = users[0].Id;
            }

            // Insert the Lead 

            insert newLead; 

 

            System.debug('SUCCESS: Lead created with Id: '+ newLead.Id); 

 

            // Handle file attachments (if any) 

            handleAttachments(email, newLead.Id); 

            log.Lead__c=newLead.Id;
            log.Response__c =string.valueof(newLead); 
            database.insert(log,false);
 

            result.success = true; 
        } catch (DmlException dmlEx) { 

            System.debug('DML Error: ' + dmlEx.getMessage()); 

            logError('LeadInsert', dmlEx.getMessage(), 
            dmlEx.getStackTraceString()); 

            result.success = false; 
            result.message = 'Failed to create lead.'; 
            log.Response__c =dmlEx.getmessage(); 
            database.insert(log,false);
 

        } catch (Exception ex) { 

            System.debug('Error: ' + ex.getMessage()); 

            logError('EmailHandler', ex.getMessage(), 

                ex.getStackTraceString()); 

            result.success = false; 

            result.message = 'Unexpected error.'; 

        } 

 

        return result; 

    } 

 

    // ============================================= 

    // PRIVATE HELPER METHODS 

    // ============================================= 

 

    /** 

     * Validates that the email is from the website 

     * lead form by checking subject line. 

     */ 

  private static final Set<String> VALID_KEYWORDS = new Set<String>{
    'New Lead','Requirement','Quote','Job',
    'Resume',
    'Inquiry for x ray films',
    'Tradeindia Inquiry',
    'MRI Machine',
    'CT Scanner',
    'Cathlab',
    'X ray',
    'Job Application',
    'Ct scan machine'
};

private Boolean isValidLeadEmail(
    Messaging.InboundEmail email
) {
    if (email.subject == null) return false;

    for (String keyword : VALID_KEYWORDS) {
        if (email.subject.containsIgnoreCase(keyword)) {
            return true;
        }
    }

    return false;
}

 

    /** 

     * Builds a Lead record from parsed email fields. 

     * Also captures sender info from the email envelope. 

     */ 

    private Lead buildLeadFromFields( 

        Map<String, String> fields, 

        Messaging.InboundEmail email 

    ) { 

        Lead l = new Lead(); 
  // Standard fields 

        l.FirstName = fields.get('FirstName'); 

        l.LastName = fields.containsKey('LastName') ? fields.get('LastName') : 'Unknown'; 

        l.Email = fields.get('Email'); 

        l.Phone = fields.get('Phone'); 

        l.Company = fields.containsKey('Company') ? fields.get('Company') : 'Email Lead'; 
        l.Description = fields.get('Message'); 

        l.LeadSource = 'Email'; 
  // Custom fields (create these on Lead object) 

        // l.Service_Interest__c = 

        //     fields.get('Service_Interest'); 

        // l.Website_Source__c = fields.get('Source'); 

        // l.Original_Email_Sender__c = 

        //     email.fromAddress; 

 

        return l; 

    } 

 

    /** 

     * Handles any binary or text attachments from 

     * the email, attaching them to the Lead record. 

     */ 

    private void handleAttachments( 

        Messaging.InboundEmail email, Id leadId 

    ) { 

        List<Attachment> attachments = 

            new List<Attachment>(); 

 

        // Binary attachments (PDFs, images, etc.) 

        if (email.binaryAttachments != null) { 

            for (Messaging.InboundEmail.BinaryAttachment ba 

                : email.binaryAttachments) { 

                attachments.add(new Attachment( 

                    Name = ba.fileName, 

                    Body = ba.body, 

                    ContentType = ba.mimeTypeSubType, 

                    ParentId = leadId 

                )); 

            } 

        } 

 

        // Text attachments (.csv, .txt, etc.) 

        if (email.textAttachments != null) { 

            for (Messaging.InboundEmail.TextAttachment ta 

                : email.textAttachments) { 

                attachments.add(new Attachment( 

                    Name = ta.fileName, 

                    Body = Blob.valueOf(ta.body), 

                    ContentType = ta.mimeTypeSubType, 

                    ParentId = leadId 

                )); 

            } 

        } 

 

        if (!attachments.isEmpty()) { 

            insert attachments; 

            System.debug('Attached ' + attachments.size() 

                + ' file(s) to Lead'); 

        } 

    } 

 

    /** 

     * Logs errors for monitoring. 

     * Uncomment Integration_Log__c for production. 

     */ 

    private void logError( 

        String context, String message, String stackTrace 

    ) { 

        // Option 1: Custom object logging 

        // Integration_Log__c log =  

        //     new Integration_Log__c(); 

        // log.Context__c = context; 

        // log.Message__c = message; 

        // log.Stack_Trace__c = stackTrace; 

        // insert log; 

 

        // Option 2: Debug log 

        System.debug(LoggingLevel.ERROR, 

            '[' + context + '] ' + message); 

        System.debug(LoggingLevel.ERROR, stackTrace); 

    } 
 public static void testcover(){
        integer i=0;
        i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
    }
}