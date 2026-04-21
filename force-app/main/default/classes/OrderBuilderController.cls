/**
 * Controller for the New / Edit Order LWC (newOrderCmp).
 * Mirrors QuoteBuilderController but operates against the Order /
 * OrderItem schema. Header create/update is handled client-side via
 * lightning-record-edit-form; this controller handles context fetch,
 * product search, and OrderItem insert/update.
 */
public with sharing class OrderBuilderController {

    @AuraEnabled(cacheable=true)
    public static OrderContext getOpportunityContext(Id opportunityId) {
        Opportunity opp = [
            SELECT Id, Name, AccountId, Account.Name,
                   Account.BillingStreet, Account.BillingCity,
                   Account.BillingStateCode, Account.BillingPostalCode,
                   Account.BillingCountryCode,
                   Pricebook2Id, CurrencyIsoCode, Buisness_Vertical__c,
                   Region__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        OrderContext ctx = new OrderContext();
        ctx.opportunityId = opp.Id;
        ctx.opportunityName = opp.Name;
        ctx.accountId = opp.AccountId;
        ctx.accountName = opp.Account != null ? opp.Account.Name : '';
        ctx.pricebookId = opp.Pricebook2Id;
        ctx.currencyCode = opp.CurrencyIsoCode;
        ctx.vertical = opp.Buisness_Vertical__c;
        ctx.regionId = opp.Region__c;

        List<Pricebook2> stdPbs = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        if (!stdPbs.isEmpty()) {
            ctx.standardPricebookId = stdPbs[0].Id;
        }

        if (opp.Account != null) {
            ctx.billingName = opp.Account.Name;
            ctx.billingStreet = opp.Account.BillingStreet;
            ctx.billingCity = opp.Account.BillingCity;
            ctx.billingState = opp.Account.BillingStateCode;
            ctx.billingPostalCode = opp.Account.BillingPostalCode;
            ctx.billingCountry = opp.Account.BillingCountryCode;
        }

        return ctx;
    }

    @AuraEnabled(cacheable=true)
    public static OrderContext getAccountContext(Id accountId) {
        Account a = [
            SELECT Id, Name,
                   BillingStreet, BillingCity, BillingStateCode,
                   BillingPostalCode, BillingCountryCode,
                   CurrencyIsoCode
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        OrderContext ctx = new OrderContext();
        ctx.accountId = a.Id;
        ctx.accountName = a.Name;
        ctx.currencyCode = a.CurrencyIsoCode;
        ctx.billingName = a.Name;
        ctx.billingStreet = a.BillingStreet;
        ctx.billingCity = a.BillingCity;
        ctx.billingState = a.BillingStateCode;
        ctx.billingPostalCode = a.BillingPostalCode;
        ctx.billingCountry = a.BillingCountryCode;

        List<Pricebook2> stdPbs = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        if (!stdPbs.isEmpty()) {
            ctx.standardPricebookId = stdPbs[0].Id;
            ctx.pricebookId = stdPbs[0].Id;
        }
        return ctx;
    }

    @AuraEnabled
    public static OrderEditContext getQuoteContext(Id quoteId) {
        Quote q = [
            SELECT Id, Name, QuoteNumber, OpportunityId, Opportunity.Name,
                   Opportunity.AccountId, Opportunity.Account.Name,
                   Opportunity.Buisness_Vertical__c, Opportunity.Region__c,
                   Pricebook2Id, CurrencyIsoCode,
                   Business_Vertical__c, Shipping_Mode__c, Delivery__c,
                   Contract_Period_From_Date__c, Contract_Period_End_Date__c,
                   BillingName, BillingStreet, BillingCity,
                   BillingStateCode, BillingPostalCode, BillingCountryCode,
                   ShippingName, ShippingStreet, ShippingCity,
                   ShippingStateCode, ShippingPostalCode, ShippingCountryCode
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        OrderEditContext ctx = new OrderEditContext();
        ctx.accountId = q.Opportunity != null ? q.Opportunity.AccountId : null;
        ctx.accountName = (q.Opportunity != null && q.Opportunity.Account != null)
            ? q.Opportunity.Account.Name : '';
        ctx.opportunityId = q.OpportunityId;
        ctx.opportunityName = q.Opportunity != null ? q.Opportunity.Name : '';
        ctx.pricebookId = q.Pricebook2Id;
        ctx.sourceQuoteId = q.Id;
        ctx.sourceQuoteName = q.QuoteNumber;
        ctx.businessVertical = q.Business_Vertical__c;
        ctx.shippingMode = q.Shipping_Mode__c;
        ctx.delivery = q.Delivery__c;
        ctx.contractPeriodFrom = q.Contract_Period_From_Date__c;
        ctx.contractPeriodEnd = q.Contract_Period_End_Date__c;

        ctx.billingStreet = q.BillingStreet;
        ctx.billingCity = q.BillingCity;
        ctx.billingState = q.BillingStateCode;
        ctx.billingPostalCode = q.BillingPostalCode;
        ctx.billingCountry = q.BillingCountryCode;
        ctx.shippingStreet = q.ShippingStreet;
        ctx.shippingCity = q.ShippingCity;
        ctx.shippingState = q.ShippingStateCode;
        ctx.shippingPostalCode = q.ShippingPostalCode;
        ctx.shippingCountry = q.ShippingCountryCode;

        List<Pricebook2> stdPbs = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        if (!stdPbs.isEmpty()) {
            ctx.standardPricebookId = stdPbs[0].Id;
        }

        ctx.lineItems = new List<OrderLineResult>();
        for (QuoteLineItem qli : [
            SELECT Id, Product2Id, Product2.Name, Product2.ProductCode,
                   Product2.QuantityUnitOfMeasure,
                   PricebookEntryId, PricebookEntry.Tax__c,
                   Quantity, ListPrice, UnitPrice
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            ORDER BY SortOrder ASC, Id ASC
        ]) {
            OrderLineResult item = new OrderLineResult();
            item.productId = qli.Product2Id;
            item.pricebookEntryId = qli.PricebookEntryId;
            item.productName = qli.Product2.Name;
            item.productCode = qli.Product2.ProductCode;
            item.uom = qli.Product2.QuantityUnitOfMeasure != null ? qli.Product2.QuantityUnitOfMeasure : 'Nos';
            item.quantity = qli.Quantity;
            item.listPrice = qli.ListPrice;
            item.unitPrice = qli.UnitPrice;
            item.taxPercent = qli.PricebookEntry.Tax__c != null ? qli.PricebookEntry.Tax__c : 0;
            ctx.lineItems.add(item);
        }

        ctx.paymentTerms = new List<PaymentTermResult>();
        for (Payment_Term__c pt : [
            SELECT Id, Payment_Term__c, Percentage__c
            FROM Payment_Term__c
            WHERE Quote__c = :quoteId
            ORDER BY CreatedDate ASC
        ]) {
            PaymentTermResult ptr = new PaymentTermResult();
            ptr.paymentTerm = pt.Payment_Term__c;
            ptr.percentage = pt.Percentage__c;
            ctx.paymentTerms.add(ptr);
        }

        return ctx;
    }

    @AuraEnabled
    public static OrderEditContext getOrderForEdit(Id orderId) {
        Order o = [
            SELECT Id, AccountId, Account.Name, OpportunityId, Opportunity.Name,
                   QuoteId, Quote.QuoteNumber,
                   Pricebook2Id, EffectiveDate, Status, Description,
                   BillingStreet, BillingCity, BillingStateCode,
                   BillingPostalCode, BillingCountryCode,
                   ShippingStreet, ShippingCity, ShippingStateCode,
                   ShippingPostalCode, ShippingCountryCode
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];

        OrderEditContext ctx = new OrderEditContext();
        ctx.orderId = o.Id;
        ctx.accountId = o.AccountId;
        ctx.accountName = o.Account != null ? o.Account.Name : '';
        ctx.opportunityId = o.OpportunityId;
        ctx.opportunityName = o.Opportunity != null ? o.Opportunity.Name : '';
        ctx.pricebookId = o.Pricebook2Id;
        ctx.effectiveDate = o.EffectiveDate;
        ctx.status = o.Status;
        ctx.description = o.Description;
        ctx.sourceQuoteId = o.QuoteId;
        ctx.sourceQuoteName = o.Quote != null ? o.Quote.QuoteNumber : null;

        ctx.billingStreet = o.BillingStreet;
        ctx.billingCity = o.BillingCity;
        ctx.billingState = o.BillingStateCode;
        ctx.billingPostalCode = o.BillingPostalCode;
        ctx.billingCountry = o.BillingCountryCode;
        ctx.shippingStreet = o.ShippingStreet;
        ctx.shippingCity = o.ShippingCity;
        ctx.shippingState = o.ShippingStateCode;
        ctx.shippingPostalCode = o.ShippingPostalCode;
        ctx.shippingCountry = o.ShippingCountryCode;

        List<Pricebook2> stdPbs = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        if (!stdPbs.isEmpty()) {
            ctx.standardPricebookId = stdPbs[0].Id;
        }

        ctx.lineItems = new List<OrderLineResult>();
        for (OrderItem oi : [
            SELECT Id, Product2Id, Product2.Name, Product2.ProductCode,
                   Product2.QuantityUnitOfMeasure,
                   PricebookEntryId, PricebookEntry.Tax__c,
                   Quantity, ListPrice, UnitPrice
            FROM OrderItem
            WHERE OrderId = :orderId
            ORDER BY Id ASC
        ]) {
            OrderLineResult item = new OrderLineResult();
            item.lineItemId = oi.Id;
            item.productId = oi.Product2Id;
            item.pricebookEntryId = oi.PricebookEntryId;
            item.productName = oi.Product2.Name;
            item.productCode = oi.Product2.ProductCode;
            item.uom = oi.Product2.QuantityUnitOfMeasure != null ? oi.Product2.QuantityUnitOfMeasure : 'Nos';
            item.quantity = oi.Quantity;
            item.listPrice = oi.ListPrice;
            item.unitPrice = oi.UnitPrice;
            item.taxPercent = oi.PricebookEntry.Tax__c != null ? oi.PricebookEntry.Tax__c : 0;
            ctx.lineItems.add(item);
        }

        ctx.paymentTerms = new List<PaymentTermResult>();
        for (Payment_Term__c pt : [
            SELECT Id, Payment_Term__c, Percentage__c
            FROM Payment_Term__c
            WHERE Order__c = :orderId
            ORDER BY CreatedDate ASC
        ]) {
            PaymentTermResult ptr = new PaymentTermResult();
            ptr.paymentTerm = pt.Payment_Term__c;
            ptr.percentage = pt.Percentage__c;
            ctx.paymentTerms.add(ptr);
        }

        return ctx;
    }

    @AuraEnabled
    public static void savePaymentTerms(Id orderId, String paymentTermsJSON, Boolean deleteExisting) {
        try {
            List<PaymentTermInput> terms = (List<PaymentTermInput>) JSON.deserialize(
                paymentTermsJSON, List<PaymentTermInput>.class
            );

            if (deleteExisting) {
                List<Payment_Term__c> existing = [
                    SELECT Id FROM Payment_Term__c WHERE Order__c = :orderId
                ];
                if (!existing.isEmpty()) delete existing;
            }

            if (terms == null || terms.isEmpty()) return;

            List<Payment_Term__c> ptList = new List<Payment_Term__c>();
            for (PaymentTermInput t : terms) {
                Payment_Term__c pt = new Payment_Term__c();
                pt.Order__c = orderId;
                pt.Payment_Term__c = t.paymentTerm;
                pt.Percentage__c = t.percentage;
                ptList.add(pt);
            }
            insert ptList;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Payment terms save failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void saveOrderItems(Id orderId, String lineItemsJSON) {
        try {
            List<LineInput> lineItems = (List<LineInput>) JSON.deserialize(lineItemsJSON, List<LineInput>.class);
            if (lineItems == null || lineItems.isEmpty()) {
                throw new AuraHandledException('At least one order item is required.');
            }

            List<OrderItem> items = new List<OrderItem>();
            for (LineInput li : lineItems) {
                OrderItem oi = new OrderItem();
                oi.OrderId = orderId;
                oi.Product2Id = li.productId;
                oi.PricebookEntryId = li.pricebookEntryId;
                oi.Quantity = li.quantity;
                oi.UnitPrice = li.unitPrice;
                items.add(oi);
            }
            insert items;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Order item save failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateOrderItems(Id orderId, String lineItemsJSON) {
        try {
            List<LineInput> lineItems = (List<LineInput>) JSON.deserialize(lineItemsJSON, List<LineInput>.class);
            if (lineItems == null || lineItems.isEmpty()) {
                throw new AuraHandledException('At least one order item is required.');
            }

            List<OrderItem> existing = [SELECT Id FROM OrderItem WHERE OrderId = :orderId];
            if (!existing.isEmpty()) delete existing;

            List<OrderItem> items = new List<OrderItem>();
            for (LineInput li : lineItems) {
                OrderItem oi = new OrderItem();
                oi.OrderId = orderId;
                oi.Product2Id = li.productId;
                oi.PricebookEntryId = li.pricebookEntryId;
                oi.Quantity = li.quantity;
                oi.UnitPrice = li.unitPrice;
                items.add(oi);
            }
            insert items;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Order item update failed: ' + e.getMessage());
        }
    }

    // ===== Inner Classes =====
    public class LineInput {
        public Id productId;
        public Id pricebookEntryId;
        public Decimal quantity;
        public Decimal unitPrice;
    }

    public class PaymentTermInput {
        public String paymentTerm;
        public Decimal percentage;
    }

    public class PaymentTermResult {
        @AuraEnabled public String paymentTerm;
        @AuraEnabled public Decimal percentage;
    }

    public class OrderContext {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Id pricebookId;
        @AuraEnabled public Id standardPricebookId;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public String vertical;
        @AuraEnabled public Id regionId;
        @AuraEnabled public String billingName;
        @AuraEnabled public String billingStreet;
        @AuraEnabled public String billingCity;
        @AuraEnabled public String billingState;
        @AuraEnabled public String billingPostalCode;
        @AuraEnabled public String billingCountry;
    }

    public class OrderEditContext {
        @AuraEnabled public Id orderId;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public Id pricebookId;
        @AuraEnabled public Id standardPricebookId;
        @AuraEnabled public Date effectiveDate;
        @AuraEnabled public String status;
        @AuraEnabled public String description;
        @AuraEnabled public Id sourceQuoteId;
        @AuraEnabled public String sourceQuoteName;
        @AuraEnabled public String businessVertical;
        @AuraEnabled public String shippingMode;
        @AuraEnabled public String delivery;
        @AuraEnabled public Date contractPeriodFrom;
        @AuraEnabled public Date contractPeriodEnd;
        @AuraEnabled public String billingStreet;
        @AuraEnabled public String billingCity;
        @AuraEnabled public String billingState;
        @AuraEnabled public String billingPostalCode;
        @AuraEnabled public String billingCountry;
        @AuraEnabled public String shippingStreet;
        @AuraEnabled public String shippingCity;
        @AuraEnabled public String shippingState;
        @AuraEnabled public String shippingPostalCode;
        @AuraEnabled public String shippingCountry;
        @AuraEnabled public List<OrderLineResult> lineItems;
        @AuraEnabled public List<PaymentTermResult> paymentTerms;
    }

    public class OrderLineResult {
        @AuraEnabled public Id lineItemId;
        @AuraEnabled public Id productId;
        @AuraEnabled public Id pricebookEntryId;
        @AuraEnabled public String productName;
        @AuraEnabled public String productCode;
        @AuraEnabled public String uom;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal listPrice;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal taxPercent;
    }
}
