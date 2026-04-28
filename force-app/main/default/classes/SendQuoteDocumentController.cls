public without sharing class SendQuoteDocumentController {

    // Single back-end for the sendQuoteDocument LWC. Folds together what
    // used to live in QuotePDFEmailController (email path) and
    // WhatsAppQuoteSender (WhatsApp path) so the LWC can fetch every
    // default in one round-trip and dispatch to either channel.

    @AuraEnabled
    public static QuoteDocumentInfo getQuoteDocumentInfo(Id quoteId) {
        QuoteDocumentInfo info = new QuoteDocumentInfo();

        // From always shows the running rep's email, even when the
        // Quote isn't resolvable yet — the LWC binds it on first
        // render and the rep should always see who they're sending as.
        info.fromAddress = UserInfo.getUserEmail();

        if (quoteId == null) {
            return info;
        }

        List<Quote> quotes = [
            SELECT Id, Name, QuoteNumber, Quote_Id__c,
                   AccountId, Account.Name,
                   ContactId, Contact.Name, Contact.Email,
                   OpportunityId, Opportunity.Name, Opportunity.Email__c,
                   Opportunity.Country_Code_Phone__c, Opportunity.Phone__c,
                   OwnerId, Owner.Name, Owner.Email, Owner.Title
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        if (quotes.isEmpty()) {
            return info;
        }

        Quote q = quotes[0];

        info.quoteId = q.Id;
        info.quoteName = q.Name;
        info.quoteNumber = q.QuoteNumber;
        info.accountName = q.AccountId != null ? q.Account.Name : '';
        info.contactName = q.ContactId != null ? q.Contact.Name : '';
        info.contactEmail = q.ContactId != null ? q.Contact.Email : '';
        info.opportunityName = q.OpportunityId != null ? q.Opportunity.Name : '';
        info.opportunityEmail = q.OpportunityId != null ? q.Opportunity.Email__c : '';
        info.ownerEmail = q.OwnerId != null ? q.Owner.Email : '';
        info.fileName = buildFileName(q);

        // To address is sourced strictly from the Opportunity's
        // Email__c field — that's the customer-facing address the
        // sales team curates. Falling back to Contact / Owner email
        // here would silently mail the wrong person if the
        // opportunity field was just left blank, so leave it empty
        // and let the rep fill it in.
        info.defaultToAddress = info.opportunityEmail;

        // Default subject: Quote ref + opportunity/account context.
        String quoteRef = String.isNotBlank(q.Quote_Id__c)
            ? q.Quote_Id__c
            : (String.isNotBlank(q.QuoteNumber) ? q.QuoteNumber : q.Name);
        String contextName = String.isNotBlank(info.opportunityName)
            ? info.opportunityName
            : info.accountName;
        if (String.isNotBlank(quoteRef) && String.isNotBlank(contextName)) {
            info.defaultSubject = 'Quotation ' + quoteRef + ' - ' + contextName;
        } else if (String.isNotBlank(quoteRef)) {
            info.defaultSubject = 'Quotation ' + quoteRef;
        } else {
            info.defaultSubject = '';
        }

        // Default HTML body: same template the LWC used to render itself.
        String greetingName = String.isNotBlank(info.contactName)
            ? info.contactName
            : (String.isNotBlank(info.accountName) ? info.accountName : 'Sir/Madam');
        String projectName = String.isNotBlank(info.opportunityName)
            ? info.opportunityName
            : info.quoteName;
        String ownerName = q.OwnerId != null && String.isNotBlank(q.Owner.Name) ? q.Owner.Name : '';
        String ownerTitle = q.OwnerId != null && String.isNotBlank(q.Owner.Title) ? q.Owner.Title : '';

        info.defaultBody =
            '<p>Dear ' + greetingName + ',</p>' +
            '<p>I hope this email finds you well.</p>' +
            '<p>Following our recent discussions, I am pleased to present our detailed ' +
            'proposal for ' + projectName + '. Attached to this email, you will find ' +
            'the proposal document which includes a comprehensive estimate for the project.</p>' +
            '<p>Best regards,</p>' +
            '<p><strong>For Cyrix Healthcare Pvt. Ltd</strong></p>' +
            '<p>' + ownerName +
            (String.isNotBlank(ownerTitle) ? '<br/>' + ownerTitle : '') +
            '</p>';

        // WhatsApp number is sourced from the Opportunity:
        //   country code  <- Opportunity.Country_Code_Phone__c
        //   local number  <- Opportunity.Phone__c
        // The two are kept in separate wrapper fields so the LWC's
        // country-code dropdown can pre-select without re-parsing.
        if (q.OpportunityId != null) {
            info.phoneCountryCode = normalizeCountryCode(q.Opportunity.Country_Code_Phone__c);
            info.phone = q.Opportunity.Phone__c;
        } else {
            info.phoneCountryCode = '';
            info.phone = '';
        }

        info.recipientName = String.isNotBlank(info.contactName)
            ? info.contactName
            : info.accountName;

        try {
            info.whatsappTemplateName = System.Label.WhatsApp_Template_Name;
        } catch (Exception ignored) {
            info.whatsappTemplateName = '';
        }

        return info;
    }

    @AuraEnabled
    public static String sendQuoteEmail(Id quoteId, String toAddress, String ccAddress,
                                         String bccAddress, String subject, String body) {
        try {
            Blob pdfBlob = renderQuotePdf(quoteId);

            Quote q = [SELECT Name, QuoteNumber FROM Quote WHERE Id = :quoteId LIMIT 1];
            String fileName = buildFileName(q);

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

            Messaging.SendEmailResult[] results = Messaging.sendEmail(
                new Messaging.SingleEmailMessage[]{ email }
            );

            if (results[0].isSuccess()) {
                savePDFToQuote(quoteId, fileName, pdfBlob);
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
     * Step 1 (sync): generate the PDF, persist it as ContentVersion +
     * ContentDistribution, capture the public download URL.
     *
     * Step 2 (async): hand the URL off to sendWhatsAppCalloutAsync
     * which performs the actual WhatsApp HTTP callout. Splitting DML
     * and the callout across two transactions is required because
     * Salesforce blocks callouts that follow uncommitted DML in the
     * same transaction ("uncommitted work pending").
     */
    @AuraEnabled
    public static String sendQuoteViaWhatsApp(Id quoteId, String phone, String recipientName) {
        try {
            Blob pdfBlob = renderQuotePdf(quoteId);

            List<Quote> quotes = [SELECT Name, QuoteNumber FROM Quote WHERE Id = :quoteId LIMIT 1];
            if (quotes.isEmpty()) {
                throw new AuraHandledException('Quote not found.');
            }
            String fileName = buildFileName(quotes[0]);

            String pdfUrl = savePDFAndGetPublicUrl(quoteId, fileName, pdfBlob);
            sendWhatsAppCalloutAsync(quoteId, phone, recipientName, pdfUrl, fileName);
            return 'SUCCESS';
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Async callout — runs after the calling transaction commits, so the
     * DML done by savePDFAndGetPublicUrl is no longer "pending" and
     * Salesforce permits the HTTP callout. The Activity log insert at
     * the end is in this transaction too — fine because it happens
     * after the callout completes.
     */
    @future(callout=true)
    public static void sendWhatsAppCalloutAsync(Id quoteId, String phone, String recipientName,
                                                 String pdfUrl, String fileName) {
        String requestBodyForLog = '';
        Integer statusCode = 0;
        String responseBody = '';
        String errorMessage = '';
        try {
            BitvoiceCall result = callWhatsAppAPIWithDetails(phone, recipientName, pdfUrl);
            requestBodyForLog = result.requestBody;
            statusCode = result.statusCode;
            responseBody = result.responseBody;
            logWhatsAppActivity(quoteId, phone, recipientName, fileName);
        } catch (Exception ex) {
            errorMessage = ex.getMessage();
            System.debug('WhatsApp callout failed: ' + errorMessage);
        } finally {
            // Always write a Log__c so we can see what Bitvoice actually
            // returned, even on 2xx responses (Bitvoice can return 200
            // with an error body when the template/phone is wrong).
            writeWhatsAppLog(quoteId, requestBodyForLog, responseBody, statusCode, errorMessage);
        }
    }

    private static String normalizeCountryCode(String raw) {
        if (String.isBlank(raw)) return '';
        String trimmed = raw.trim();
        // Custom Text(10) field — values arrive as "+91", "91", "91-",
        // etc. Strip everything except digits and a single leading +.
        Boolean leadingPlus = trimmed.startsWith('+');
        String digits = trimmed.replaceAll('[^0-9]', '');
        if (String.isBlank(digits)) return '';
        return '+' + digits;
    }

    private static Blob renderQuotePdf(Id quoteId) {
        PageReference pdfPage = new PageReference('/apex/ProductQuotation');
        pdfPage.getParameters().put('id', quoteId);
        if (Test.isRunningTest()) {
            return Blob.valueOf('Test PDF');
        }
        return pdfPage.getContentAsPDF();
    }

    private static String buildFileName(Quote q) {
        String base = String.isNotBlank(q.Name) ? q.Name : 'Quote';
        if (String.isNotBlank(q.QuoteNumber)) {
            return base + '_' + q.QuoteNumber + '.pdf';
        }
        return base + '.pdf';
    }

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

    private static String savePDFAndGetPublicUrl(Id quoteId, String fileName, Blob pdfBlob) {
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

        ContentDistribution cd = new ContentDistribution();
        cd.Name = fileName;
        cd.ContentVersionId = cv.Id;
        cd.PreferencesAllowViewInBrowser = true;
        cd.PreferencesNotifyOnVisit = false;
        cd.PreferencesAllowOriginalDownload = true;
        insert cd;

        ContentDistribution dist = [
            SELECT DistributionPublicUrl, ContentDownloadUrl
            FROM ContentDistribution
            WHERE Id = :cd.Id
        ];

        return dist.ContentDownloadUrl;
    }

    private static void logEmailActivity(Id quoteId, String toAddress, String ccAddress,
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
            System.debug('Failed to log email activity: ' + e.getMessage());
        }
    }

    private static void logWhatsAppActivity(Id quoteId, String phone, String recipientName, String fileName) {
        try {
            Task t = new Task(
                WhatId = quoteId,
                Subject = 'WhatsApp: Quote PDF sent to ' + recipientName,
                Status = 'Completed',
                Priority = 'Normal',
                ActivityDate = Date.today(),
                Description = 'Quote PDF (' + fileName + ') sent via WhatsApp to ' + phone,
                Type = 'Call'
            );
            insert t;
        } catch (Exception e) {
            System.debug('Failed to log WhatsApp activity: ' + e.getMessage());
        }
    }

    private static void writeWhatsAppLog(Id quoteId, String reqBody, String resBody,
                                          Integer statusCode, String errorMessage) {
        try {
            Integer maxSize = 32000;
            if (reqBody != null && reqBody.length() > maxSize) {
                reqBody = reqBody.substring(0, maxSize);
            }
            String fullResponse = (errorMessage != null && errorMessage.length() > 0)
                ? 'ERROR: ' + errorMessage + (resBody != null ? '\n\nResponseBody: ' + resBody : '')
                : resBody;
            if (fullResponse != null && fullResponse.length() > maxSize) {
                fullResponse = fullResponse.substring(0, maxSize);
            }

            Log__c rec = new Log__c();
            rec.Object__c      = 'WhatsApp Quote';
            rec.Request__c     = reqBody;
            rec.Response__c    = fullResponse;
            rec.Status_Code__c = String.valueOf(statusCode);
            insert rec;
        } catch (Exception e) {
            System.debug('WhatsApp log insert failed: ' + e.getMessage());
        }
    }

    /**
     * Custom exception used by callWhatsAppAPIWithDetails for non-2xx
     * responses. AuraHandledException can't be thrown from a @future
     * method — only from VF / Aura / LWC contexts — so we use a plain
     * subclass that works in both async and sync callers.
     */
    public class WhatsAppApiException extends Exception {}

    private static BitvoiceCall callWhatsAppAPIWithDetails(String phone, String recipientName, String pdfUrl) {
        String apiUrl = System.Label.WhatsApp_API_URL;
        String apiKey = System.Label.WhatsApp_API_Key;
        String templateName = System.Label.WhatsApp_Template_Name;

        Map<String, Object> requestBody = new Map<String, Object>();
        requestBody.put('phone', phone);
        requestBody.put('template_name', templateName);
        requestBody.put('language_code', 'en');

        Map<String, Object> headerParam = new Map<String, Object>();
        headerParam.put('type', 'document');
        Map<String, Object> docObj = new Map<String, Object>();
        docObj.put('link', pdfUrl);
        headerParam.put('document', docObj);

        Map<String, Object> headerComponent = new Map<String, Object>();
        headerComponent.put('type', 'header');
        headerComponent.put('parameters', new List<Object>{ headerParam });

        Map<String, Object> bodyParam = new Map<String, Object>();
        bodyParam.put('type', 'text');
        bodyParam.put('text', recipientName);

        Map<String, Object> bodyComponent = new Map<String, Object>();
        bodyComponent.put('type', 'body');
        bodyComponent.put('parameters', new List<Object>{ bodyParam });

        requestBody.put('components', new List<Object>{ headerComponent, bodyComponent });

        String jsonBody = JSON.serialize(requestBody);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(apiUrl);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        // Bitvoice expects an X-API-Key header, not Authorization Bearer.
        req.setHeader('X-API-Key', apiKey);
        req.setBody(jsonBody);
        req.setTimeout(30000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        BitvoiceCall result = new BitvoiceCall();
        result.requestBody  = jsonBody;
        result.statusCode   = res.getStatusCode();
        result.responseBody = res.getBody();

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            return result;
        } else {
            throw new WhatsAppApiException(
                'WhatsApp API error (' + res.getStatusCode() + '): ' + res.getBody()
            );
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

    private class BitvoiceCall {
        public String requestBody;
        public Integer statusCode;
        public String responseBody;
    }

    public class QuoteDocumentInfo {
        @AuraEnabled public Id quoteId;
        @AuraEnabled public String quoteName;
        @AuraEnabled public String quoteNumber;
        @AuraEnabled public String fileName;
        @AuraEnabled public String accountName;
        @AuraEnabled public String contactName;
        @AuraEnabled public String contactEmail;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public String opportunityEmail;
        @AuraEnabled public String ownerEmail;
        @AuraEnabled public String fromAddress;
        @AuraEnabled public String defaultToAddress;
        @AuraEnabled public String defaultSubject;
        @AuraEnabled public String defaultBody;
        @AuraEnabled public String phoneCountryCode;
        @AuraEnabled public String phone;
        @AuraEnabled public String recipientName;
        @AuraEnabled public String whatsappTemplateName;
    }
}
