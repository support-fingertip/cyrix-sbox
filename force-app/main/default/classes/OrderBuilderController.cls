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
                   Business_Vertical__c, Sub_Vertical__c,
                   Shipping_Mode__c, Delivery__c,
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
        ctx.subVertical = q.Sub_Vertical__c;
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
                   Product2.QuantityUnitOfMeasure, Product2.Service_Item__c,
                   PricebookEntryId, PricebookEntry.Tax__c,
                   Quantity, ListPrice, UnitPrice, Discount
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
            item.discount = qli.Discount != null ? qli.Discount : 0;
            item.taxPercent = qli.PricebookEntry.Tax__c != null ? qli.PricebookEntry.Tax__c : 0;
            item.isServiceItem = (qli.Product2.Service_Item__c == 'Yes');
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
                   Product2.QuantityUnitOfMeasure, Product2.Service_Item__c,
                   PricebookEntryId, PricebookEntry.Tax__c,
                   Quantity, ListPrice, UnitPrice, Discount__c
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
            item.discount = oi.Discount__c != null ? oi.Discount__c : 0;
            item.taxPercent = oi.PricebookEntry.Tax__c != null ? oi.PricebookEntry.Tax__c : 0;
            item.isServiceItem = (oi.Product2.Service_Item__c == 'Yes');
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

            Map<Id, Id> pbeByProduct = resolvePricebookEntries(orderId, lineItems);

            List<OrderItem> items = new List<OrderItem>();
            for (LineInput li : lineItems) {
                OrderItem oi = new OrderItem();
                oi.OrderId = orderId;
                oi.Product2Id = li.productId;
                oi.PricebookEntryId = pbeByProduct.containsKey(li.productId)
                    ? pbeByProduct.get(li.productId)
                    : li.pricebookEntryId;
                oi.Quantity = li.quantity;
                oi.UnitPrice = li.unitPrice;
                oi.Discount__c = li.discount != null ? li.discount : 0;
                if (li.taxPercent != null) {
                    oi.Tax__c = li.taxPercent;
                    Decimal qty = li.quantity != null ? li.quantity : 0;
                    Decimal up = li.unitPrice != null ? li.unitPrice : 0;
                    Decimal disc = li.discount != null ? li.discount : 0;
                    Decimal afterDiscount = (qty * up) * (1 - (disc / 100));
                    oi.Tax_Amount__c = afterDiscount * (li.taxPercent / 100);
                }
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

            Map<Id, Id> pbeByProduct = resolvePricebookEntries(orderId, lineItems);

            List<OrderItem> items = new List<OrderItem>();
            for (LineInput li : lineItems) {
                OrderItem oi = new OrderItem();
                oi.OrderId = orderId;
                oi.Product2Id = li.productId;
                oi.PricebookEntryId = pbeByProduct.containsKey(li.productId)
                    ? pbeByProduct.get(li.productId)
                    : li.pricebookEntryId;
                oi.Quantity = li.quantity;
                oi.UnitPrice = li.unitPrice;
                oi.Discount__c = li.discount != null ? li.discount : 0;
                if (li.taxPercent != null) {
                    oi.Tax__c = li.taxPercent;
                    Decimal qty = li.quantity != null ? li.quantity : 0;
                    Decimal up = li.unitPrice != null ? li.unitPrice : 0;
                    Decimal disc = li.discount != null ? li.discount : 0;
                    Decimal afterDiscount = (qty * up) * (1 - (disc / 100));
                    oi.Tax_Amount__c = afterDiscount * (li.taxPercent / 100);
                }
                items.add(oi);
            }
            insert items;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Order item update failed: ' + e.getMessage());
        }
    }

    /**
     * For each incoming line, make sure the PricebookEntryId we insert
     * against OrderItem lives on the Order's Pricebook2Id. If the caller
     * passed a QuoteLineItem.PricebookEntryId that happens to be on a
     * different pricebook (e.g. the Quote used a tier pricebook while the
     * Order was set to another), re-resolve to the PBE for the same
     * Product on the Order's pricebook. Falls back to the incoming id so
     * downstream DML raises the original mismatch if nothing fits.
     */
    private static Map<Id, Id> resolvePricebookEntries(Id orderId, List<LineInput> lineItems) {
        Map<Id, Id> out = new Map<Id, Id>();
        if (lineItems == null || lineItems.isEmpty()) return out;

        List<Order> orders = [SELECT Id, Pricebook2Id FROM Order WHERE Id = :orderId LIMIT 1];
        if (orders.isEmpty() || orders[0].Pricebook2Id == null) return out;
        Id orderPbId = orders[0].Pricebook2Id;

        Set<Id> productIds = new Set<Id>();
        for (LineInput li : lineItems) {
            if (li.productId != null) productIds.add(li.productId);
        }
        if (productIds.isEmpty()) return out;

        for (PricebookEntry pbe : [
            SELECT Id, Product2Id
            FROM PricebookEntry
            WHERE Pricebook2Id = :orderPbId
              AND Product2Id IN :productIds
              AND IsActive = true
        ]) {
            out.put(pbe.Product2Id, pbe.Id);
        }
        return out;
    }

    // ===== Inner Classes =====
    public class LineInput {
        public Id productId;
        public Id pricebookEntryId;
        public Decimal quantity;
        public Decimal unitPrice;
        public Decimal discount;
        public Decimal taxPercent;
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
        @AuraEnabled public String subVertical;
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
        @AuraEnabled public Decimal discount;
        @AuraEnabled public Decimal taxPercent;
        @AuraEnabled public Boolean isServiceItem;
    }
}
