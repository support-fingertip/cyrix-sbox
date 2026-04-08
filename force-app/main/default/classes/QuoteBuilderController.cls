public with sharing class QuoteBuilderController {

    @AuraEnabled(cacheable=true)
    public static OpportunityContext getOpportunityContext(Id opportunityId) {
        Opportunity opp = [
            SELECT Id, Name, AccountId, Account.Name,
                   Account.BillingStreet, Account.BillingCity,
                   Account.BillingState, Account.BillingPostalCode,
                   Account.BillingCountryCode,
                   Pricebook2Id, CurrencyIsoCode, Buisness_Vertical__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        OpportunityContext ctx = new OpportunityContext();
        ctx.opportunityId = opp.Id;
        ctx.opportunityName = opp.Name;
        ctx.accountId = opp.AccountId;
        ctx.accountName = opp.Account != null ? opp.Account.Name : '';
        ctx.pricebookId = opp.Pricebook2Id;
        ctx.currencyCode = opp.CurrencyIsoCode;
        ctx.vertical = opp.Buisness_Vertical__c;

        if (opp.Account != null) {
            ctx.billingName = opp.Account.Name;
            ctx.billingStreet = opp.Account.BillingStreet;
            ctx.billingCity = opp.Account.BillingCity;
            ctx.billingState = opp.Account.BillingState;
            ctx.billingPostalCode = opp.Account.BillingPostalCode;
            ctx.billingCountry = opp.Account.BillingCountryCode;
        }

        return ctx;
    }

    @AuraEnabled(cacheable=true)
    public static List<Pricebook2> getPricebooks() {
        return [SELECT Id, Name, IsActive, IsStandard 
                FROM Pricebook2 
                WHERE IsActive = true 
                ORDER BY IsStandard DESC, Name ASC];
    }

    @AuraEnabled(cacheable=true)
    public static List<ShippingAddressResult> getShippingAddresses(Id accountId) {
        List<ShippingAddressResult> results = new List<ShippingAddressResult>();
        if (accountId == null) return results;

        for (Shipping_Address__c sa : [
            SELECT Id, Name, Address__Street__s, Address__City__s,
                   Address__StateCode__s, Address__PostalCode__s,
                   Address__CountryCode__s, Same_as_BillingAddress__c
            FROM Shipping_Address__c
            WHERE Account__c = :accountId
            ORDER BY CreatedDate DESC
        ]) {
            ShippingAddressResult sar = new ShippingAddressResult();
            sar.addressId = sa.Id;
            sar.name = sa.Name;
            sar.street = sa.Address__Street__s;
            sar.city = sa.Address__City__s;
            sar.state = sa.Address__StateCode__s;
            sar.postalCode = sa.Address__PostalCode__s;
            sar.country = sa.Address__CountryCode__s;
            sar.sameAsBilling = sa.Same_as_BillingAddress__c;

            List<String> parts = new List<String>();
            parts.add(sa.Name);
            if (String.isNotBlank(sa.Address__City__s)) parts.add(sa.Address__City__s);
            if (String.isNotBlank(sa.Address__StateCode__s)) parts.add(sa.Address__StateCode__s);
            sar.displayLabel = String.join(parts, ', ');

            results.add(sar);
        }

        return results;
    }

    @AuraEnabled
    public static List<ProductSearchResult> searchProducts(String searchTerm, Id pricebookId, String category) {
        List<ProductSearchResult> results = new List<ProductSearchResult>();
        if (String.isBlank(searchTerm)) return results;

        String searchKey = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';

        Id pbId = pricebookId;
        if (pbId == null) {
            List<Pricebook2> stdPb = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
            if (!stdPb.isEmpty()) pbId = stdPb[0].Id;
        }
        if (pbId == null) return results;

        String query = 'SELECT Id, Product2Id, Product2.Name, Product2.ProductCode, ' +
            'Product2.Product_Category__c, Product2.Make__c, Product2.Model__c, ' +
            'Product2.Description, Product2.HSN_Code__c, Product2.Tax__c, ' +
            'Product2.Standard_Price__c, Product2.QuantityUnitOfMeasure, ' +
            'Product2.Line_Description__c, Product2.Detailed_Description__c, ' +
            'UnitPrice, CurrencyIsoCode ' +
            'FROM PricebookEntry ' +
            'WHERE Pricebook2Id = :pbId ' +
            'AND Product2.IsActive = true ' +
            'AND (Product2.Name LIKE :searchKey OR Product2.ProductCode LIKE :searchKey)';

        if (String.isNotBlank(category)) {
            query += ' AND Product2.Product_Category__c = :category';
        }

        query += ' ORDER BY Product2.Name ASC LIMIT 20';

        try {
            for (PricebookEntry pbe : Database.query(query)) {
                ProductSearchResult psr = new ProductSearchResult();
                psr.pricebookEntryId = pbe.Id;
                psr.productId = pbe.Product2Id;
                psr.productName = pbe.Product2.Name;
                psr.productCode = pbe.Product2.ProductCode;
                psr.category = pbe.Product2.Product_Category__c;
                psr.make = pbe.Product2.Make__c;
                psr.model = pbe.Product2.Model__c;
                psr.description = pbe.Product2.Description;
                psr.hsnCode = pbe.Product2.HSN_Code__c;
                psr.taxPercent = pbe.Product2.Tax__c;
                psr.unitPrice = pbe.UnitPrice;
                psr.standardPrice = pbe.Product2.Standard_Price__c;
                psr.uom = pbe.Product2.QuantityUnitOfMeasure;
                psr.lineDescription = pbe.Product2.Line_Description__c;
                psr.detailedDescription = pbe.Product2.Detailed_Description__c;
                results.add(psr);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Search failed: ' + e.getMessage());
        }

        return results;
    }

    @AuraEnabled
    public static QuoteEditContext getQuoteForEdit(Id quoteId) {
        Quote q = [
            SELECT Id, Pricebook2Id, OpportunityId, Opportunity.AccountId
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        QuoteEditContext ctx = new QuoteEditContext();
        ctx.quoteId = q.Id;
        ctx.pricebookId = q.Pricebook2Id;
        ctx.opportunityId = q.OpportunityId;
        ctx.accountId = q.Opportunity != null ? q.Opportunity.AccountId : null;

        ctx.lineItems = new List<QuoteLineItemResult>();
        for (QuoteLineItem qli : [
            SELECT Id, Product2Id, Product2.Name, Product2.ProductCode,
                   Product2.QuantityUnitOfMeasure, Product2.Tax__c,
                   PricebookEntryId, Quantity, UnitPrice, Discount,
                   Tax_Type__c, Product_Line_Description__c,
                   Product_Detailed_Description__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            ORDER BY SortOrder ASC, Id ASC
        ]) {
            QuoteLineItemResult item = new QuoteLineItemResult();
            item.lineItemId = qli.Id;
            item.productId = qli.Product2Id;
            item.pricebookEntryId = qli.PricebookEntryId;
            item.productName = qli.Product2.Name;
            item.productCode = qli.Product2.ProductCode;
            item.uom = qli.Product2.QuantityUnitOfMeasure != null ? qli.Product2.QuantityUnitOfMeasure : 'Nos';
            item.quantity = qli.Quantity;
            item.unitPrice = qli.UnitPrice;
            item.discount = qli.Discount != null ? qli.Discount : 0;
            item.taxPercent = qli.Product2.Tax__c != null ? qli.Product2.Tax__c : 0;
            item.taxType = qli.Tax_Type__c != null ? qli.Tax_Type__c : 'GST';
            item.lineDescription = qli.Product_Line_Description__c;
            item.detailedDescription = qli.Product_Detailed_Description__c;
            ctx.lineItems.add(item);
        }

        return ctx;
    }

    @AuraEnabled
    public static void saveQuoteLineItems(Id quoteId, String lineItemsJSON) {
        List<LineItemInput> lineItems = (List<LineItemInput>) JSON.deserialize(lineItemsJSON, List<LineItemInput>.class);
        if (lineItems == null || lineItems.isEmpty()) {
            throw new AuraHandledException('At least one line item is required.');
        }

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

    @AuraEnabled
    public static void updateQuoteLineItems(Id quoteId, String lineItemsJSON) {
        List<LineItemInput> lineItems = (List<LineItemInput>) JSON.deserialize(lineItemsJSON, List<LineItemInput>.class);
        if (lineItems == null || lineItems.isEmpty()) {
            throw new AuraHandledException('At least one line item is required.');
        }

        List<QuoteLineItem> oldItems = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :quoteId];
        if (!oldItems.isEmpty()) delete oldItems;

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

    // ===== Inner Classes =====
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

    public class OpportunityContext {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Id pricebookId;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public String vertical;
        @AuraEnabled public String billingName;
        @AuraEnabled public String billingStreet;
        @AuraEnabled public String billingCity;
        @AuraEnabled public String billingState;
        @AuraEnabled public String billingPostalCode;
        @AuraEnabled public String billingCountry;
    }

    public class ShippingAddressResult {
        @AuraEnabled public Id addressId;
        @AuraEnabled public String name;
        @AuraEnabled public String street;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String postalCode;
        @AuraEnabled public String country;
        @AuraEnabled public Boolean sameAsBilling;
        @AuraEnabled public String displayLabel;
    }

    public class ProductSearchResult {
        @AuraEnabled public Id pricebookEntryId;
        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
        @AuraEnabled public String productCode;
        @AuraEnabled public String category;
        @AuraEnabled public String make;
        @AuraEnabled public String model;
        @AuraEnabled public String description;
        @AuraEnabled public String hsnCode;
        @AuraEnabled public Decimal taxPercent;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal standardPrice;
        @AuraEnabled public String uom;
        @AuraEnabled public String lineDescription;
        @AuraEnabled public String detailedDescription;
    }

    public class QuoteEditContext {
        @AuraEnabled public Id quoteId;
        @AuraEnabled public Id pricebookId;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public Id accountId;
        @AuraEnabled public List<QuoteLineItemResult> lineItems;
    }

    public class PricebookOption {
        @AuraEnabled public Id pricebookId;
        @AuraEnabled public String pricebookName;
    }

    public class QuoteLineItemResult {
        @AuraEnabled public Id lineItemId;
        @AuraEnabled public Id productId;
        @AuraEnabled public Id pricebookEntryId;
        @AuraEnabled public String productName;
        @AuraEnabled public String productCode;
        @AuraEnabled public String uom;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal discount;
        @AuraEnabled public Decimal taxPercent;
        @AuraEnabled public String taxType;
        @AuraEnabled public String lineDescription;
        @AuraEnabled public String detailedDescription;
    }
}