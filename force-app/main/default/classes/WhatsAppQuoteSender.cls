public without sharing class WhatsAppQuoteSender {

    @AuraEnabled
    public static WhatsAppQuoteInfo getQuoteInfo(Id quoteId) {
        WhatsAppQuoteInfo info = new WhatsAppQuoteInfo();

        if (quoteId == null) {
            return info;
        }

        List<Quote> quotes = [
            SELECT Id, Name, QuoteNumber, Quote_Id__c,
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

        if (q.ContactId != null && String.isNotBlank(q.Contact.MobilePhone)) {
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

            Quote q = [SELECT Name, QuoteNumber FROM Quote WHERE Id = :quoteId LIMIT 1];
            String fileName = q.Name + '_' + q.QuoteNumber + '.pdf';

            String pdfUrl = savePDFAndGetPublicUrl(quoteId, fileName, pdfBlob);

            String result = callWhatsAppAPI(phone, recipientName, pdfUrl);

            logWhatsAppActivity(quoteId, phone, recipientName, fileName);

            return result;
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
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

    private static String callWhatsAppAPI(String phone, String recipientName, String pdfUrl) {
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
        req.setHeader('Authorization', 'Bearer ' + apiKey);
        req.setBody(jsonBody);
        req.setTimeout(30000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            return 'SUCCESS';
        } else {
            throw new AuraHandledException('WhatsApp API error (' + res.getStatusCode() + '): ' + res.getBody());
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