public with sharing class QuotePDFEmailController {

    /**
     * Get Quote details for the email form
     */
    @AuraEnabled
    public static QuoteEmailWrapper getQuoteDetails(Id quoteId) {
        List<Quote> quotes = [
            SELECT Id, Name, QuoteNumber, Quote_Id__c, 
                   AccountId, Account.Name,
                   ContactId, Contact.Name, Contact.Email,
                   OpportunityId, Opportunity.Name, Opportunity.Email__c,
                   OwnerId, Owner.Name, Owner.Email, Owner.Title
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
        wrapper.accountName = q.AccountId != null ? q.Account.Name : '';
        wrapper.contactEmail = q.ContactId != null ? q.Contact.Email : '';
        wrapper.opportunityEmail = q.OpportunityId != null ? q.Opportunity.Email__c : '';
        wrapper.contactName = q.ContactId != null ? q.Contact.Name : '';
        wrapper.ownerEmail = q.OwnerId != null ? q.Owner.Email : '';

        // Default To address: prefer Opportunity email, then Contact email, then Owner email
        if (String.isNotBlank(wrapper.opportunityEmail)) {
            wrapper.defaultToAddress = wrapper.opportunityEmail;
        } else if (String.isNotBlank(wrapper.contactEmail)) {
            wrapper.defaultToAddress = wrapper.contactEmail;
        } else if (String.isNotBlank(wrapper.ownerEmail)) {
            wrapper.defaultToAddress = wrapper.ownerEmail;
        } else {
            wrapper.defaultToAddress = '';
        }

        // Default subject: use Quote Name (e.g. C-KL/Ausum/QTN-009/2026-27)
        wrapper.defaultSubject = 'Quote ' + q.Name;

        // Default HTML body: professional template populated with quote context
        String greetingName = String.isNotBlank(wrapper.contactName)
            ? wrapper.contactName
            : (String.isNotBlank(wrapper.accountName) ? wrapper.accountName : 'Sir/Madam');
        String opportunityName = q.OpportunityId != null && String.isNotBlank(q.Opportunity.Name)
            ? q.Opportunity.Name
            : q.Name;
        String ownerName = q.OwnerId != null && String.isNotBlank(q.Owner.Name) ? q.Owner.Name : '';
        String ownerTitle = q.OwnerId != null && String.isNotBlank(q.Owner.Title) ? q.Owner.Title : '';

        wrapper.defaultBody =
            '<p>Dear ' + greetingName + ',</p>' +
            '<p>I hope this email finds you well.</p>' +
            '<p>Following our recent discussions, I am pleased to present our detailed proposal for ' +
            opportunityName + '. Attached to this email, you will find the proposal document which ' +
            'includes a comprehensive estimate for the project.</p>' +
            '<p>Best regards,</p>' +
            '<p><strong>For Cyrix Healthcare Pvt. Ltd</strong></p>' +
            '<p>' + ownerName +
            (String.isNotBlank(ownerTitle) ? '<br/>' + ownerTitle : '') +
            '</p>';
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
            email.setHtmlBody(body);
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
                // Log this email on the Quote's Activity timeline
                logEmailActivity(quoteId, toAddress, ccAddress, bccAddress, subject, body, fileName);
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
     * Log the sent email as a completed Task on the Quote's Activity timeline
     * so users can see that an email has been sent for this quote.
     */
    private static void logEmailActivity(Id quoteId, String toAddress, String ccAddress,
                                          String bccAddress, String subject, String body,
                                          String fileName) {
        try {
            // Strip HTML tags from body for the task description
            String plainBody = body != null
                ? body.replaceAll('<br\\s*/?>', '\n').replaceAll('</p>', '\n').replaceAll('<[^>]+>', '').trim()
                : '';

            String description = 'To: ' + (toAddress != null ? toAddress : '') + '\n';
            if (String.isNotBlank(ccAddress)) {
                description += 'CC: ' + ccAddress + '\n';
            }
            if (String.isNotBlank(bccAddress)) {
                description += 'BCC: ' + bccAddress + '\n';
            }
            description += 'Attachment: ' + fileName + '\n\n' + plainBody;

            Task emailTask = new Task(
                WhatId = quoteId,
                Subject = 'Email: ' + (String.isNotBlank(subject) ? subject : 'Quote PDF'),
                Status = 'Completed',
                Priority = 'Normal',
                ActivityDate = Date.today(),
                Description = description,
                Type = 'Email',
                TaskSubtype = 'Email'
            );
            insert emailTask;
        } catch (Exception e) {
            // Don't fail the send if activity logging fails — just log it
            System.debug('Failed to log email activity: ' + e.getMessage());
        }
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
        @AuraEnabled public String opportunityEmail;
        @AuraEnabled public String defaultToAddress;
    }
}