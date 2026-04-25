public with sharing class OrderPDFEmailController {

    /**
     * Get Order details for the email form (mirror of QuotePDFEmailController.getQuoteDetails).
     */
    @AuraEnabled
    public static OrderEmailWrapper getOrderDetails(Id orderId) {
        List<Order> orders = [
            SELECT Id, Name, OrderNumber, Quote_Id__c,
                   AccountId, Account.Name,
                   BillToContactId, BillToContact.Name, BillToContact.Email,
                   OpportunityId, Opportunity.Name, Opportunity.Email__c,
                   OwnerId, Owner.Name, Owner.Email, Owner.Title
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];

        OrderEmailWrapper wrapper = new OrderEmailWrapper();

        if (orders.isEmpty()) {
            return wrapper;
        }

        Order o = orders[0];
        wrapper.orderId = o.Id;
        wrapper.orderName = o.Name;
        wrapper.orderNumber = o.OrderNumber;
        wrapper.accountName = o.AccountId != null ? o.Account.Name : '';
        wrapper.contactEmail = o.BillToContactId != null ? o.BillToContact.Email : '';
        wrapper.contactName = o.BillToContactId != null ? o.BillToContact.Name : '';
        wrapper.opportunityEmail = o.OpportunityId != null ? o.Opportunity.Email__c : '';
        wrapper.ownerEmail = o.OwnerId != null ? o.Owner.Email : '';

        if (String.isNotBlank(wrapper.opportunityEmail)) {
            wrapper.defaultToAddress = wrapper.opportunityEmail;
        } else if (String.isNotBlank(wrapper.contactEmail)) {
            wrapper.defaultToAddress = wrapper.contactEmail;
        } else if (String.isNotBlank(wrapper.ownerEmail)) {
            wrapper.defaultToAddress = wrapper.ownerEmail;
        } else {
            wrapper.defaultToAddress = '';
        }

        wrapper.defaultSubject = 'Order ' + o.Name;

        String greetingName = String.isNotBlank(wrapper.contactName)
            ? wrapper.contactName
            : (String.isNotBlank(wrapper.accountName) ? wrapper.accountName : 'Sir/Madam');
        String opportunityName = o.OpportunityId != null && String.isNotBlank(o.Opportunity.Name)
            ? o.Opportunity.Name
            : o.Name;
        String ownerName = o.OwnerId != null && String.isNotBlank(o.Owner.Name) ? o.Owner.Name : '';
        String ownerTitle = o.OwnerId != null && String.isNotBlank(o.Owner.Title) ? o.Owner.Title : '';

        wrapper.defaultBody =
            '<p>Dear ' + greetingName + ',</p>' +
            '<p>I hope this email finds you well.</p>' +
            '<p>Please find attached the order document for ' + opportunityName + '.</p>' +
            '<p>Best regards,</p>' +
            '<p><strong>For Cyrix Healthcare Pvt. Ltd</strong></p>' +
            '<p>' + ownerName +
            (String.isNotBlank(ownerTitle) ? '<br/>' + ownerTitle : '') +
            '</p>';
        return wrapper;
    }

    /**
     * Generate the Order PDF and send it as an email attachment.
     */
    @AuraEnabled
    public static String sendOrderEmail(Id orderId, String toAddress, String ccAddress,
                                         String bccAddress, String subject, String body) {
        try {
            PageReference pdfPage = new PageReference('/apex/ProductOrder');
            pdfPage.getParameters().put('id', orderId);
            Blob pdfBlob;

            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test PDF');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }

            Order o = [SELECT Name, OrderNumber FROM Order WHERE Id = :orderId LIMIT 1];
            String fileName = o.Name + '_' + o.OrderNumber + '.pdf';

            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName(fileName);
            attachment.setBody(pdfBlob);
            attachment.setContentType('application/pdf');

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(parseEmails(toAddress));
            email.setSubject(subject);
            email.setHtmlBody(body);
            email.setFileAttachments(new Messaging.EmailFileAttachment[]{ attachment });

            if (String.isNotBlank(ccAddress)) {
                email.setCcAddresses(parseEmails(ccAddress));
            }
            if (String.isNotBlank(bccAddress)) {
                email.setBccAddresses(parseEmails(bccAddress));
            }

            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ email });

            if (results[0].isSuccess()) {
                savePDFToOrder(orderId, fileName, pdfBlob);
                logEmailActivity(orderId, toAddress, ccAddress, bccAddress, subject, body, fileName);
                return 'SUCCESS';
            } else {
                return 'ERROR: ' + results[0].getErrors()[0].getMessage();
            }
        } catch (Exception e) {
            return 'ERROR: ' + e.getMessage();
        }
    }

    private static void savePDFToOrder(Id orderId, String fileName, Blob pdfBlob) {
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName.removeEnd('.pdf');
        cv.PathOnClient = fileName;
        cv.VersionData = pdfBlob;
        insert cv;

        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = contentDocId;
        cdl.LinkedEntityId = orderId;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';
        insert cdl;
    }

    private static void logEmailActivity(Id orderId, String toAddress, String ccAddress,
                                          String bccAddress, String subject, String body,
                                          String fileName) {
        try {
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
                WhatId = orderId,
                Subject = 'Email: ' + (String.isNotBlank(subject) ? subject : 'Order PDF'),
                Status = 'Completed',
                Priority = 'Normal',
                ActivityDate = Date.today(),
                Description = description,
                Type = 'Email',
                TaskSubtype = 'Email'
            );
            insert emailTask;
        } catch (Exception e) {
            System.debug('Failed to log email activity: ' + e.getMessage());
        }
    }

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

    public class OrderEmailWrapper {
        @AuraEnabled public Id orderId;
        @AuraEnabled public String orderName;
        @AuraEnabled public String orderNumber;
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
