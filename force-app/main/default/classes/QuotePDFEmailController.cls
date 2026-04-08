public with sharing class QuotePDFEmailController {

    /**
     * Get Quote details for the email form
     */
    @AuraEnabled
    public static QuoteEmailWrapper getQuoteDetails(Id quoteId) {
        List<Quote> quotes = [
            SELECT Id, Name, QuoteNumber, Quote_Id__c, Vertical__c,
                   AccountId, Account.Name,
                   ContactId, Contact.Name, Contact.Email,
                   OwnerId, Owner.Name, Owner.Email
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        QuoteEmailWrapper wrapper = new QuoteEmailWrapper();

        if (quotes.isEmpty()) {
            return wrapper;
        }

        Quote q = quotes[0];
        wrapper.quoteId = q.Id;
        wrapper.quoteName = q.Name;
        wrapper.quoteNumber = q.QuoteNumber;
        wrapper.vertical = q.Vertical__c;
        wrapper.accountName = q.AccountId != null ? q.Account.Name : '';
        wrapper.contactEmail = q.ContactId != null ? q.Contact.Email : '';
        wrapper.contactName = q.ContactId != null ? q.Contact.Name : '';
        wrapper.ownerEmail = q.OwnerId != null ? q.Owner.Email : '';
        wrapper.defaultSubject = 'Quotation for ' +
            (q.Vertical__c != null ? q.Vertical__c : '') +
            ' - ' + q.Name;
        wrapper.defaultBody = 'Dear Sir/Madam,\n\n' +
            'Please find attached the quotation for your kind consideration.\n\n' +
            'Should you require any further clarification or technical discussion, ' +
            'we will be glad to assist at your convenience.\n\n' +
            'With Regards,\n' +
            'For Cyrix Healthcare Pvt. Ltd';
        return wrapper;
    }

    /**
     * Generate PDF and send email
     */
    @AuraEnabled
    public static String sendQuoteEmail(Id quoteId, String toAddress, String ccAddress,
                                         String bccAddress, String subject, String body) {
        try {
            // Generate PDF from VF page
            PageReference pdfPage = new PageReference('/apex/ProductQuotation');
            pdfPage.getParameters().put('id', quoteId);
            Blob pdfBlob;

            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test PDF');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }

            // Get Quote name for file name
            Quote q = [SELECT Name, QuoteNumber FROM Quote WHERE Id = :quoteId LIMIT 1];
            String fileName = q.Name + '_' + q.QuoteNumber + '.pdf';

            // Create email attachment
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName(fileName);
            attachment.setBody(pdfBlob);
            attachment.setContentType('application/pdf');

            // Build email
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(parseEmails(toAddress));
            email.setSubject(subject);
            email.setPlainTextBody(body);
            email.setFileAttachments(new Messaging.EmailFileAttachment[]{ attachment });

            // Set CC if provided
            if (String.isNotBlank(ccAddress)) {
                email.setCcAddresses(parseEmails(ccAddress));
            }

            // Set BCC if provided
            if (String.isNotBlank(bccAddress)) {
                email.setBccAddresses(parseEmails(bccAddress));
            }

            // Send email
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ email });

            if (results[0].isSuccess()) {
                // Save PDF as file on the Quote
                savePDFToQuote(quoteId, fileName, pdfBlob);
                return 'SUCCESS';
            } else {
                return 'ERROR: ' + results[0].getErrors()[0].getMessage();
            }
        } catch (Exception e) {
            return 'ERROR: ' + e.getMessage();
        }
    }

    /**
     * Save PDF as a file attached to the Quote
     */
    private static void savePDFToQuote(Id quoteId, String fileName, Blob pdfBlob) {
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName.removeEnd('.pdf');
        cv.PathOnClient = fileName;
        cv.VersionData = pdfBlob;
        insert cv;

        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = contentDocId;
        cdl.LinkedEntityId = quoteId;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';
        insert cdl;
    }

    /**
     * Parse comma-separated email string into list
     */
    private static List<String> parseEmails(String emailString) {
        List<String> emails = new List<String>();
        if (String.isNotBlank(emailString)) {
            for (String e : emailString.split('[,;]')) {
                String trimmed = e.trim();
                if (String.isNotBlank(trimmed)) {
                    emails.add(trimmed);
                }
            }
        }
        return emails;
    }

    // Wrapper class
    public class QuoteEmailWrapper {
        @AuraEnabled public Id quoteId;
        @AuraEnabled public String quoteName;
        @AuraEnabled public String quoteNumber;
        @AuraEnabled public String vertical;
        @AuraEnabled public String accountName;
        @AuraEnabled public String contactEmail;
        @AuraEnabled public String contactName;
        @AuraEnabled public String ownerEmail;
        @AuraEnabled public String defaultSubject;
        @AuraEnabled public String defaultBody;
    }
}