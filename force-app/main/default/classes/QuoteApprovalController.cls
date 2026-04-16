public with sharing class QuoteApprovalController {

    /**
     * Fetches quote line items with their approval status for a given Quote.
     */
    @AuraEnabled(cacheable=true)
    public static QuoteApprovalWrapper getQuoteLineItems(Id quoteId) {
        QuoteApprovalWrapper wrapper = new QuoteApprovalWrapper();

        Quote qt = [
            SELECT Id, Name, QuoteNumber, OpportunityId, Opportunity.Name,
                   Opportunity.OwnerId, Opportunity.Owner.Name,
                   Price_Status__c, ContactId, Account.Name
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
        wrapper.quote = qt;

        List<QuoteLineItemWrapper> items = new List<QuoteLineItemWrapper>();
        for (QuoteLineItem qli : [
            SELECT Id, QuoteId, Product2Id, Product2.Name, Quantity,
                   UnitPrice, TotalPrice, Discount, ListPrice,
                   Price_Status__c, Tax_Type__c,
                   Product_Line_Description__c, Product_Detailed_Description__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            ORDER BY CreatedDate ASC
        ]) {
            items.add(new QuoteLineItemWrapper(qli));
        }
        wrapper.lineItems = items;
        return wrapper;
    }

    /**
     * Submits quote line items for approval.
     * Sets Price_Status__c to 'Approval Required' on selected line items
     * and updates the parent Quote status.
     */
    @AuraEnabled
    public static void submitForApproval(List<Id> lineItemIds, Id quoteId, String comments) {
        List<QuoteLineItem> itemsToSubmit = [
            SELECT Id, Price_Status__c, Product2.Name, UnitPrice, Discount
            FROM QuoteLineItem
            WHERE Id IN :lineItemIds
        ];

        Quote qt = [
            SELECT Id, Name, QuoteNumber, Price_Status__c,
                   OpportunityId, Opportunity.OwnerId, Opportunity.Owner.ManagerId
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        for (QuoteLineItem item : itemsToSubmit) {
            item.Price_Status__c = 'Approval Required';
        }
        update itemsToSubmit;

        // Update parent Quote status
        qt.Price_Status__c = 'Approval Required';
        update qt;

        // Send notification to Opportunity Owner's Manager
        String currentUserName = UserInfo.getName();
        Set<String> targetUserIds = new Set<String>();
        if (qt.Opportunity.Owner.ManagerId != null) {
            targetUserIds.add(qt.Opportunity.Owner.ManagerId);
        }
        if (qt.Opportunity.OwnerId != null) {
            targetUserIds.add(qt.Opportunity.OwnerId);
        }

        if (!targetUserIds.isEmpty()) {
            sendQuoteNotification(
                'Quote Approval Requested by ' + currentUserName,
                'Quote #' + qt.QuoteNumber + ' has ' + itemsToSubmit.size() +
                ' line item(s) submitted for approval.' +
                (String.isNotBlank(comments) ? '\nComments: ' + comments : ''),
                qt.Id,
                targetUserIds
            );
        }
    }

    /**
     * Approves selected quote line items.
     * Sets Price_Status__c to 'Approved' and updates parent Quote if all items are approved.
     */
    @AuraEnabled
    public static void approveLineItems(List<Id> lineItemIds, Id quoteId, String comments) {
        List<QuoteLineItem> itemsToApprove = [
            SELECT Id, Price_Status__c, Product2.Name
            FROM QuoteLineItem
            WHERE Id IN :lineItemIds
        ];

        for (QuoteLineItem item : itemsToApprove) {
            item.Price_Status__c = 'Approved';
        }
        update itemsToApprove;

        // Check if all line items are now approved
        Integer pendingCount = [
            SELECT COUNT()
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            AND Price_Status__c != 'Approved'
            AND Price_Status__c != 'Not Required'
        ];

        Quote qt = [
            SELECT Id, QuoteNumber, Price_Status__c, OpportunityId, Opportunity.OwnerId
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        if (pendingCount == 0) {
            qt.Price_Status__c = 'Approved';
            update qt;
        }

        // Notify the Opportunity Owner
        String currentUserName = UserInfo.getName();
        sendQuoteNotification(
            'Quote Line Items Approved by ' + currentUserName,
            'Quote #' + qt.QuoteNumber + ': ' + itemsToApprove.size() +
            ' line item(s) approved.' +
            (String.isNotBlank(comments) ? '\nComments: ' + comments : ''),
            qt.Id,
            new Set<String>{ qt.Opportunity.OwnerId }
        );
    }

    /**
     * Rejects selected quote line items.
     * Reverts their Price_Status__c to 'Approval Required' (so they can be
     * resubmitted) and flips the parent Quote to 'Rejected'.
     */
    @AuraEnabled
    public static void rejectLineItems(List<Id> lineItemIds, Id quoteId, String comments) {
        List<QuoteLineItem> itemsToReject = [
            SELECT Id, Price_Status__c, Product2.Name
            FROM QuoteLineItem
            WHERE Id IN :lineItemIds
        ];

        for (QuoteLineItem item : itemsToReject) {
            item.Price_Status__c = 'Approval Required';
        }
        update itemsToReject;

        Quote qt = [
            SELECT Id, QuoteNumber, Price_Status__c, OpportunityId, Opportunity.OwnerId
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        qt.Price_Status__c = 'Rejected';
        update qt;

        // Notify the Opportunity Owner
        String currentUserName = UserInfo.getName();
        sendQuoteNotification(
            'Quote Line Items Rejected by ' + currentUserName,
            'Quote #' + qt.QuoteNumber + ': ' + itemsToReject.size() +
            ' line item(s) rejected.' +
            (String.isNotBlank(comments) ? '\nReason: ' + comments : ''),
            qt.Id,
            new Set<String>{ qt.Opportunity.OwnerId }
        );
    }

    /**
     * Evaluates discount thresholds on quote line items.
     * Automatically sets Price_Status__c based on discount vs product-level limits.
     */
    @AuraEnabled
    public static void evaluateDiscountThresholds(Id quoteId) {
        List<QuoteLineItem> lineItems = [
            SELECT Id, Product2Id, Product2.Manager_Discount_Up_to__c,
                   Product2.VP_Sales_Discount_Up_to__c,
                   Product2.CEO_Sales_Discount_Up_to__c,
                   Discount, Price_Status__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
        ];

        for (QuoteLineItem qli : lineItems) {
            Decimal discount = qli.Discount != null ? qli.Discount / 100 : 0;
            Decimal managerLimit = qli.Product2.Manager_Discount_Up_to__c != null
                ? qli.Product2.Manager_Discount_Up_to__c / 100 : 0;
            Decimal vpLimit = qli.Product2.VP_Sales_Discount_Up_to__c != null
                ? qli.Product2.VP_Sales_Discount_Up_to__c / 100 : 0;
            Decimal ceoLimit = qli.Product2.CEO_Sales_Discount_Up_to__c != null
                ? qli.Product2.CEO_Sales_Discount_Up_to__c / 100 : 0;

            if (discount > ceoLimit && ceoLimit > 0) {
                qli.Price_Status__c = 'Approval Required';
            } else if (discount > vpLimit && vpLimit > 0) {
                qli.Price_Status__c = 'Approval Required';
            } else if (discount > managerLimit && managerLimit > 0) {
                qli.Price_Status__c = 'Approval Required';
            } else {
                qli.Price_Status__c = 'Not Required';
            }
        }
        update lineItems;
    }

    /**
     * Helper: Sends a custom notification for quote approval events.
     */
    private static void sendQuoteNotification(String title, String body, Id targetId, Set<String> targetUserIds) {
        if (targetUserIds == null || targetUserIds.isEmpty()) return;
        try {
            CustomNotificationType notificationType = [
                SELECT Id
                FROM CustomNotificationType
                WHERE DeveloperName = 'Quote_Approval_Notification'
                LIMIT 1
            ];
            CustomNotificationService.notificationSend(
                title, targetId, body, targetUserIds, notificationType.Id
            );
        } catch (Exception e) {
            System.debug('Quote notification error: ' + e.getMessage());
        }
    }

    // ---- Wrapper Classes ----

    public class QuoteApprovalWrapper {
        @AuraEnabled public Quote quote;
        @AuraEnabled public List<QuoteLineItemWrapper> lineItems;
    }

    public class QuoteLineItemWrapper {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String productName;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal totalPrice;
        @AuraEnabled public Decimal discount;
        @AuraEnabled public Decimal listPrice;
        @AuraEnabled public String priceStatus;
        @AuraEnabled public String taxType;
        @AuraEnabled public String lineDescription;
        @AuraEnabled public String detailedDescription;

        public QuoteLineItemWrapper(QuoteLineItem qli) {
            this.recordId = qli.Id;
            this.productName = qli.Product2 != null ? qli.Product2.Name : '';
            this.quantity = qli.Quantity;
            this.unitPrice = qli.UnitPrice;
            this.totalPrice = qli.TotalPrice;
            this.discount = qli.Discount;
            this.listPrice = qli.ListPrice;
            this.priceStatus = qli.Price_Status__c;
            this.taxType = qli.Tax_Type__c;
            this.lineDescription = qli.Product_Line_Description__c;
            this.detailedDescription = qli.Product_Detailed_Description__c;
        }
    }
}