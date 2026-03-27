public with sharing class QuoteCreatorController {

    /**
     * Fetches the Opportunity details needed for quote creation.
     */
    @AuraEnabled
    public static OpportunityWrapper getOpportunityDetails(Id opportunityId) {
        Opportunity opp = [
            SELECT Id, Name, AccountId, Account.Name, Pricebook2Id,
                   CurrencyIsoCode, Buisness_Vertical__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        OpportunityWrapper wrapper = new OpportunityWrapper();
        wrapper.opportunityId = opp.Id;
        wrapper.opportunityName = opp.Name;
        wrapper.accountId = opp.AccountId;
        wrapper.accountName = opp.Account != null ? opp.Account.Name : '';
        wrapper.pricebookId = opp.Pricebook2Id;
        wrapper.currencyCode = opp.CurrencyIsoCode;
        wrapper.vertical = opp.Buisness_Vertical__c;
        return wrapper;
    }

    /**
     * Fetches existing quotes for an Opportunity.
     */
    @AuraEnabled
    public static List<QuoteListWrapper> getQuotesForOpportunity(Id opportunityId) {
        List<QuoteListWrapper> quotes = new List<QuoteListWrapper>();
        for (Quote q : [
            SELECT Id, Name, QuoteNumber, Quote_Id__c, Quote_Date__c, Valid_Till__c,
                   Status, Subtotal, TotalPrice, GrandTotal,
                   Price_Status__c, is_Active__c, Vertical__c,
                   (SELECT Id FROM QuoteLineItems)
            FROM Quote
            WHERE OpportunityId = :opportunityId
            ORDER BY CreatedDate DESC
        ]) {
            QuoteListWrapper qlw = new QuoteListWrapper();
            qlw.quoteId = q.Id;
            qlw.quoteName = q.Name;
            qlw.quoteNumber = q.QuoteNumber;
            qlw.quoteAutoId = q.Quote_Id__c;
            qlw.quoteDate = q.Quote_Date__c;
            qlw.validTill = q.Valid_Till__c;
            qlw.status = q.Status;
            qlw.priceStatus = q.Price_Status__c;
            qlw.subtotal = q.Subtotal;
            qlw.totalPrice = q.TotalPrice;
            qlw.grandTotal = q.GrandTotal;
            qlw.isActive = q.is_Active__c;
            qlw.vertical = q.Vertical__c;
            qlw.lineItemCount = q.QuoteLineItems != null ? q.QuoteLineItems.size() : 0;
            quotes.add(qlw);
        }
        return quotes;
    }

    /**
     * Searches products for adding as line items.
     */
    @AuraEnabled
    public static List<ProductWrapper> searchProducts(String searchTerm, Id pricebookId) {
        List<ProductWrapper> products = new List<ProductWrapper>();
        String searchKey = '%' + String.escapeSingleQuotes(searchTerm) + '%';

        String pbId = pricebookId;
        if (pbId == null) {
            List<Pricebook2> stdPb = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
            if (!stdPb.isEmpty()) {
                pbId = stdPb[0].Id;
            }
        }

        if (pbId == null) {
            return products;
        }

        for (PricebookEntry pbe : [
            SELECT Id, Product2Id, Product2.Name, Product2.ProductCode,
                   Product2.Description, Product2.Make__c, Product2.Model__c,
                   Product2.Standard_Price__c,
                   UnitPrice, CurrencyIsoCode
            FROM PricebookEntry
            WHERE Pricebook2Id = :pbId
            AND Product2.IsActive = true
            AND (Product2.Name LIKE :searchKey
                 OR Product2.ProductCode LIKE :searchKey
                 OR Product2.Make__c LIKE :searchKey
                 OR Product2.Model__c LIKE :searchKey)
            ORDER BY Product2.Name ASC
            LIMIT 50
        ]) {
            ProductWrapper pw = new ProductWrapper();
            pw.pricebookEntryId = pbe.Id;
            pw.productId = pbe.Product2Id;
            pw.productName = pbe.Product2.Name;
            pw.productCode = pbe.Product2.ProductCode;
            pw.make = pbe.Product2.Make__c;
            pw.model = pbe.Product2.Model__c;
            pw.unitPrice = pbe.UnitPrice;
            pw.standardPrice = pbe.Product2.Standard_Price__c;
            pw.description = pbe.Product2.Description;
            products.add(pw);
        }
        return products;
    }

    /**
     * Creates a new Quote with line items.
     */
    @AuraEnabled
    public static Id createQuoteWithLineItems(String quoteJSON, String lineItemsJSON) {
        QuoteInput quoteInput = (QuoteInput) JSON.deserialize(quoteJSON, QuoteInput.class);
        List<LineItemInput> lineItems = (List<LineItemInput>) JSON.deserialize(lineItemsJSON, List<LineItemInput>.class);

        Quote newQuote = new Quote();
        newQuote.Name = quoteInput.name;
        newQuote.OpportunityId = quoteInput.opportunityId;
        newQuote.Pricebook2Id = quoteInput.pricebookId;
        newQuote.Quote_Date__c = quoteInput.quoteDate;
        newQuote.Valid_Till__c = quoteInput.validTill;
        newQuote.Billing_Address__c = quoteInput.billingAddress;
        newQuote.Shipping_Address__c = quoteInput.shippingAddress;
        newQuote.Shipping_Mode__c = quoteInput.shippingMode;
        newQuote.Vertical__c = quoteInput.vertical;
        newQuote.is_Active__c = true;
        newQuote.Price_Status__c = 'Draft';
        newQuote.Status = 'Draft';
        insert newQuote;

        if (lineItems != null && !lineItems.isEmpty()) {
            List<QuoteLineItem> qliList = new List<QuoteLineItem>();
            for (LineItemInput item : lineItems) {
                QuoteLineItem qli = new QuoteLineItem();
                qli.QuoteId = newQuote.Id;
                qli.Product2Id = item.productId;
                qli.PricebookEntryId = item.pricebookEntryId;
                qli.Quantity = item.quantity;
                qli.UnitPrice = item.unitPrice;
                qli.Discount = item.discount;
                qli.Tax_Type__c = item.taxType;
                qli.Product_Line_Description__c = item.lineDescription;
                qli.Product_Detailed_Description__c = item.detailedDescription;
                qli.Price_Status__c = 'Standard';
                qliList.add(qli);
            }
            insert qliList;
        }

        return newQuote.Id;
    }

    /**
     * Fetches quote details with line items for viewing/editing.
     */
    @AuraEnabled
    public static QuoteDetailWrapper getQuoteDetails(Id quoteId) {
        Quote q = [
            SELECT Id, Name, QuoteNumber, Quote_Id__c, Quote_Date__c, Valid_Till__c,
                   Status, OpportunityId, Opportunity.Name, AccountId, Account.Name,
                   Pricebook2Id, Billing_Address__c, Shipping_Address__c,
                   Shipping_Mode__c, is_Active__c, Vertical__c, Price_Status__c,
                   Subtotal, TotalPrice, GrandTotal, CurrencyIsoCode
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        List<LineItemWrapper> items = new List<LineItemWrapper>();
        for (QuoteLineItem qli : [
            SELECT Id, Product2Id, Product2.Name, Product2.ProductCode,
                   Product2.Make__c, Product2.Model__c,
                   PricebookEntryId, Quantity, UnitPrice, TotalPrice, Discount, ListPrice,
                   Price_Status__c, Tax_Type__c,
                   Product_Line_Description__c, Product_Detailed_Description__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            ORDER BY CreatedDate ASC
        ]) {
            LineItemWrapper liw = new LineItemWrapper();
            liw.lineItemId = qli.Id;
            liw.productId = qli.Product2Id;
            liw.productName = qli.Product2 != null ? qli.Product2.Name : '';
            liw.productCode = qli.Product2 != null ? qli.Product2.ProductCode : '';
            liw.make = qli.Product2 != null ? qli.Product2.Make__c : '';
            liw.model = qli.Product2 != null ? qli.Product2.Model__c : '';
            liw.pricebookEntryId = qli.PricebookEntryId;
            liw.quantity = qli.Quantity;
            liw.unitPrice = qli.UnitPrice;
            liw.totalPrice = qli.TotalPrice;
            liw.discount = qli.Discount;
            liw.listPrice = qli.ListPrice;
            liw.priceStatus = qli.Price_Status__c;
            liw.taxType = qli.Tax_Type__c;
            liw.lineDescription = qli.Product_Line_Description__c;
            liw.detailedDescription = qli.Product_Detailed_Description__c;
            items.add(liw);
        }

        QuoteDetailWrapper wrapper = new QuoteDetailWrapper();
        wrapper.quote = q;
        wrapper.lineItems = items;
        return wrapper;
    }

    /**
     * Deletes a line item from a quote.
     */
    @AuraEnabled
    public static void deleteLineItem(Id lineItemId) {
        QuoteLineItem qli = [SELECT Id FROM QuoteLineItem WHERE Id = :lineItemId LIMIT 1];
        delete qli;
    }

    /**
     * Adds line items to an existing quote.
     */
    @AuraEnabled
    public static void addLineItemsToQuote(Id quoteId, String lineItemsJSON) {
        List<LineItemInput> lineItems = (List<LineItemInput>) JSON.deserialize(lineItemsJSON, List<LineItemInput>.class);

        if (lineItems != null && !lineItems.isEmpty()) {
            List<QuoteLineItem> qliList = new List<QuoteLineItem>();
            for (LineItemInput item : lineItems) {
                QuoteLineItem qli = new QuoteLineItem();
                qli.QuoteId = quoteId;
                qli.Product2Id = item.productId;
                qli.PricebookEntryId = item.pricebookEntryId;
                qli.Quantity = item.quantity;
                qli.UnitPrice = item.unitPrice;
                qli.Discount = item.discount;
                qli.Tax_Type__c = item.taxType;
                qli.Product_Line_Description__c = item.lineDescription;
                qli.Product_Detailed_Description__c = item.detailedDescription;
                qli.Price_Status__c = 'Standard';
                qliList.add(qli);
            }
            insert qliList;
        }
    }

    // ---- Input Classes ----

    public class QuoteInput {
        public String name;
        public Id opportunityId;
        public Id pricebookId;
        public Date quoteDate;
        public Date validTill;
        public String billingAddress;
        public String shippingAddress;
        public String shippingMode;
        public String vertical;
    }

    public class LineItemInput {
        public Id productId;
        public Id pricebookEntryId;
        public Decimal quantity;
        public Decimal unitPrice;
        public Decimal discount;
        public String taxType;
        public String lineDescription;
        public String detailedDescription;
    }

    // ---- Wrapper Classes ----

    public class OpportunityWrapper {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Id pricebookId;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public String vertical;
    }

    public class QuoteListWrapper {
        @AuraEnabled public Id quoteId;
        @AuraEnabled public String quoteName;
        @AuraEnabled public String quoteNumber;
        @AuraEnabled public String quoteAutoId;
        @AuraEnabled public Date quoteDate;
        @AuraEnabled public Date validTill;
        @AuraEnabled public String status;
        @AuraEnabled public String priceStatus;
        @AuraEnabled public Decimal subtotal;
        @AuraEnabled public Decimal totalPrice;
        @AuraEnabled public Decimal grandTotal;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public String vertical;
        @AuraEnabled public Integer lineItemCount;
    }

    public class ProductWrapper {
        @AuraEnabled public Id pricebookEntryId;
        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
        @AuraEnabled public String productCode;
        @AuraEnabled public String make;
        @AuraEnabled public String model;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal standardPrice;
        @AuraEnabled public String description;
    }

    public class QuoteDetailWrapper {
        @AuraEnabled public Quote quote;
        @AuraEnabled public List<LineItemWrapper> lineItems;
    }

    public class LineItemWrapper {
        @AuraEnabled public Id lineItemId;
        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
        @AuraEnabled public String productCode;
        @AuraEnabled public String make;
        @AuraEnabled public String model;
        @AuraEnabled public Id pricebookEntryId;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal totalPrice;
        @AuraEnabled public Decimal discount;
        @AuraEnabled public Decimal listPrice;
        @AuraEnabled public String priceStatus;
        @AuraEnabled public String taxType;
        @AuraEnabled public String lineDescription;
        @AuraEnabled public String detailedDescription;
    }
}
