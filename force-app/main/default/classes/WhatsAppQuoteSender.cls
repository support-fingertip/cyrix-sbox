public without sharing class WhatsAppQuoteSender {
    // WhatsApp quote sender — sync DML + async @future callout, with
    // request/response logging to Log__c for delivery debugging.

    @AuraEnabled
    public static WhatsAppQuoteInfo getQuoteInfo(Id quoteId) {
        WhatsAppQuoteInfo info = new WhatsAppQuoteInfo();

        if (quoteId == null) {
            return info;
        }

        List<Quote> quotes = [
            SELECT Id, Name, QuoteNumber, Quote_Id__c,
                   Phone, Email,
                   ContactId, Contact.Name, Contact.Phone, Contact.MobilePhone,
                   OpportunityId, Opportunity.Name,
                   Account.Name, Account.Phone,
                   OwnerId, Owner.Name
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
        info.contactName = q.ContactId != null ? q.Contact.Name : '';
        info.accountName = q.Account != null ? q.Account.Name : '';

        // Phone fallback: standard Quote.Phone (auto-populated from Contact/Account)
        // → Contact.MobilePhone → Contact.Phone → Account.Phone.
        if (String.isNotBlank(q.Phone)) {
            info.phone = q.Phone;
        } else if (q.ContactId != null && String.isNotBlank(q.Contact.MobilePhone)) {
            info.phone = q.Contact.MobilePhone;
        } else if (q.ContactId != null && String.isNotBlank(q.Contact.Phone)) {
            info.phone = q.Contact.Phone;
        } else if (q.Account != null && String.isNotBlank(q.Account.Phone)) {
            info.phone = q.Account.Phone;
        } else {
            info.phone = '';
        }

        info.recipientName = String.isNotBlank(info.contactName) ? info.contactName : info.accountName;

        return info;
    }

    /**
     * Step 1 (sync): generate PDF, persist it as ContentVersion +
     * ContentDistribution, capture the public download URL.
     *
     * Step 2 (async): hand the URL off to sendWhatsAppCalloutAsync,
     * which performs the actual WhatsApp HTTP callout. Splitting the
     * DML and the callout across two transactions is required
     * because Salesforce blocks callouts that follow uncommitted
     * DML in the same transaction ("uncommitted work pending").
     */
    @AuraEnabled
    public static String sendQuoteViaWhatsApp(Id quoteId, String phone, String recipientName) {
        try {
            PageReference pdfPage = new PageReference('/apex/ProductQuotation');
            pdfPage.getParameters().put('id', quoteId);
            Blob pdfBlob;

            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test PDF');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }

            List<Quote> quotes = [SELECT Name, QuoteNumber FROM Quote WHERE Id = :quoteId LIMIT 1];
            if (quotes.isEmpty()) {
                throw new AuraHandledException('Quote not found.');
            }
            String fileName = quotes[0].Name + '_' + quotes[0].QuoteNumber + '.pdf';

            String pdfUrl = savePDFAndGetPublicUrl(quoteId, fileName, pdfBlob);

            // Hand the URL to the @future for the actual callout —
            // runs in a fresh transaction once the current one commits.
            sendWhatsAppCalloutAsync(quoteId, phone, recipientName, pdfUrl, fileName);

            return 'SUCCESS';
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Async callout — runs after the calling transaction commits, so
     * the DML done by savePDFAndGetPublicUrl is no longer "pending"
     * and Salesforce permits the HTTP callout. The Activity log
     * insert at the end is in this transaction too — fine because
     * it happens after the callout completes.
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

    private class BitvoiceCall {
        public String requestBody;
        public Integer statusCode;
        public String responseBody;
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

    /**
     * Custom exception used by callWhatsAppAPI for non-2xx responses.
     * AuraHandledException can't be thrown from a @future method — only
     * from VF / Aura / LWC contexts — so we use a plain subclass that
     * works in both async and sync callers.
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

    public class WhatsAppQuoteInfo {
        @AuraEnabled public Id quoteId;
        @AuraEnabled public String quoteName;
        @AuraEnabled public String contactName;
        @AuraEnabled public String accountName;
        @AuraEnabled public String phone;
        @AuraEnabled public String recipientName;
    }
}
