public with sharing class QuoteBuilderController {

    @AuraEnabled(cacheable=true)
    public static OpportunityContext getOpportunityContext(Id opportunityId) {
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

        OpportunityContext ctx = new OpportunityContext();
        ctx.opportunityId = opp.Id;
        ctx.opportunityName = opp.Name;
        ctx.accountId = opp.AccountId;
        ctx.accountName = opp.Account != null ? opp.Account.Name : '';
        ctx.pricebookId = opp.Pricebook2Id;
        ctx.currencyCode = opp.CurrencyIsoCode;
        ctx.vertical = opp.Buisness_Vertical__c;
        ctx.regionId = opp.Region__c;

        // Always provide the Standard Pricebook ID for auto-pricing
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
    public static List<PricebookOption> getPricebooks() {
        List<PricebookOption> options = new List<PricebookOption>();
        for (Pricebook2 pb : [
            SELECT Id, Name
            FROM Pricebook2
            WHERE IsActive = true
            ORDER BY Name ASC
        ]) {
            PricebookOption opt = new PricebookOption();
            opt.pricebookId = pb.Id;
            opt.pricebookName = pb.Name;
            options.add(opt);
        }
        return options;
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
            'Product2.Description, Product2.HSN_Code__c, ' +
            'Product2.Standard_Price__c, Product2.QuantityUnitOfMeasure, ' +
            'Product2.Line_Description__c, Product2.Detailed_Description__c, ' +
            'UnitPrice, Tax__c, CurrencyIsoCode ' +
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
                psr.taxPercent = pbe.Tax__c;
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
    public static List<ProductSearchResult> searchProductsWithBestPrice(
        String searchTerm, String category, Id accountId, Id regionId
    ) {
        List<ProductSearchResult> results = new List<ProductSearchResult>();
        if (String.isBlank(searchTerm)) return results;

        String searchKey = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';

        // Search products directly - not restricted by pricebook
        String prodQuery = 'SELECT Id, Name, ProductCode, Product_Category__c, Make__c, Model__c, ' +
            'Description, HSN_Code__c, Standard_Price__c, QuantityUnitOfMeasure, ' +
            'Line_Description__c, Detailed_Description__c ' +
            'FROM Product2 ' +
            'WHERE IsActive = true ' +
            'AND (Name LIKE :searchKey OR ProductCode LIKE :searchKey)';

        if (String.isNotBlank(category)) {
            prodQuery += ' AND Product_Category__c = :category';
        }
        prodQuery += ' ORDER BY Name ASC LIMIT 20';

        List<Product2> products;
        try {
            products = Database.query(prodQuery);
        } catch (Exception e) {
            throw new AuraHandledException('Search failed: ' + e.getMessage());
        }
        if (products.isEmpty()) return results;

        Set<Id> productIds = new Set<Id>();
        for (Product2 p : products) {
            productIds.add(p.Id);
        }

        // Get Standard Pricebook entries (needed for QuoteLineItem.PricebookEntryId)
        List<Pricebook2> stdPbs = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        if (stdPbs.isEmpty()) return results;
        Id stdPbId = stdPbs[0].Id;

        Map<Id, PricebookEntry> stdEntryMap = new Map<Id, PricebookEntry>();
        for (PricebookEntry pbe : [
            SELECT Id, Product2Id, UnitPrice, Tax__c
            FROM PricebookEntry
            WHERE Pricebook2Id = :stdPbId
            AND Product2Id IN :productIds
            AND IsActive = true
        ]) {
            stdEntryMap.put(pbe.Product2Id, pbe);
        }

        // Query prices from ALL active pricebooks for these products
        Date today = Date.today();
        List<PricebookEntry> allEntries = [
            SELECT Id, Product2Id, UnitPrice, Tax__c,
                   Max_Discount_Percentage__c,
                   Pricebook2Id, Pricebook2.Name, Pricebook2.Price_Book_Type__c,
                   Pricebook2.Customer__c, Pricebook2.Region__c,
                   Pricebook2.Valid_From__c, Pricebook2.Valid_Till__c,
                   Pricebook2.IsStandard
            FROM PricebookEntry
            WHERE Product2Id IN :productIds
            AND Pricebook2.IsActive = true
            AND Product2.IsActive = true
        ];

        // Build product -> pricing options map with priority
        Map<Id, List<PricingOption>> productPricingMap = new Map<Id, List<PricingOption>>();
        for (PricebookEntry pbe : allEntries) {
            Integer priority = getPricebookPriority(pbe, accountId, regionId, today);
            if (priority == 0) continue;

            PricingOption opt = new PricingOption();
            opt.pricebookName = pbe.Pricebook2.Name;
            opt.pricebookType = getPricebookTypeLabel(pbe);
            opt.price = pbe.UnitPrice;
            opt.taxPercent = pbe.Tax__c;
            opt.maxDiscount = pbe.Max_Discount_Percentage__c;
            opt.priority = priority;

            if (!productPricingMap.containsKey(pbe.Product2Id)) {
                productPricingMap.put(pbe.Product2Id, new List<PricingOption>());
            }
            productPricingMap.get(pbe.Product2Id).add(opt);
        }

        // Build results with auto-selected best pricing
        for (Product2 prod : products) {
            // Must have a Standard Pricebook entry to be added to a quote
            PricebookEntry stdEntry = stdEntryMap.get(prod.Id);
            if (stdEntry == null) continue;

            ProductSearchResult psr = new ProductSearchResult();
            psr.pricebookEntryId = stdEntry.Id;
            psr.productId = prod.Id;
            psr.productName = prod.Name;
            psr.productCode = prod.ProductCode;
            psr.category = prod.Product_Category__c;
            psr.make = prod.Make__c;
            psr.model = prod.Model__c;
            psr.description = prod.Description;
            psr.hsnCode = prod.HSN_Code__c;
            psr.standardPrice = prod.Standard_Price__c;
            psr.uom = prod.QuantityUnitOfMeasure;
            psr.lineDescription = prod.Line_Description__c;
            psr.detailedDescription = prod.Detailed_Description__c;

            // Default to standard pricebook pricing
            psr.unitPrice = stdEntry.UnitPrice;
            psr.taxPercent = stdEntry.Tax__c;
            psr.sourcePricebook = '';
            psr.sourcePricebookType = '';
            psr.availablePrices = new List<PriceOption>();

            // Auto-select best price based on priority
            List<PricingOption> options = productPricingMap.get(prod.Id);
            if (options != null && !options.isEmpty()) {
                PricingOption best = null;
                for (PricingOption opt : options) {
                    if (best == null || opt.priority < best.priority) {
                        best = opt;
                    }
                }
                if (best != null) {
                    psr.unitPrice = best.price;
                    psr.taxPercent = best.taxPercent != null ? best.taxPercent : stdEntry.Tax__c;
                    psr.maxDiscount = best.maxDiscount;
                    psr.sourcePricebook = best.pricebookName;
                    psr.sourcePricebookType = best.pricebookType;
                }

                for (PricingOption opt : options) {
                    PriceOption po = new PriceOption();
                    po.pricebookName = opt.pricebookName;
                    po.pricebookType = opt.pricebookType;
                    po.price = opt.price;
                    po.isSelected = (best != null && opt.pricebookName == best.pricebookName
                                     && opt.price == best.price);
                    psr.availablePrices.add(po);
                }
            }

            results.add(psr);
        }

        return results;
    }

    // Pricing priority: Promotional(1) > Customer Specific(2) > Region Specific(3) > Dealer(4) > Standard(5)
    private static Integer getPricebookPriority(PricebookEntry pbe, Id accountId, Id regionId, Date today) {
        String pbType = pbe.Pricebook2.Price_Book_Type__c;

        // Check date validity
        Date validFrom = pbe.Pricebook2.Valid_From__c;
        Date validTill = pbe.Pricebook2.Valid_Till__c;
        Boolean dateValid = true;
        if (validFrom != null && today < validFrom) dateValid = false;
        if (validTill != null && today > validTill) dateValid = false;

        if (pbType == 'Promotional Price') {
            return dateValid ? 1 : 0;
        }
        if (pbType == 'Customer Specific' && accountId != null) {
            return (pbe.Pricebook2.Customer__c == accountId && dateValid) ? 2 : 0;
        }
        if (pbType == 'Region Specific' && regionId != null) {
            return (pbe.Pricebook2.Region__c == regionId && dateValid) ? 3 : 0;
        }
        if (pbType == 'Dealer Price') {
            return 4;
        }
        if (pbe.Pricebook2.IsStandard) {
            return 5;
        }
        return 0;
    }

    private static String getPricebookTypeLabel(PricebookEntry pbe) {
        if (pbe.Pricebook2.IsStandard) return 'Standard';
        String pbType = pbe.Pricebook2.Price_Book_Type__c;
        return String.isNotBlank(pbType) ? pbType : 'Standard';
    }

    @AuraEnabled
    public static QuoteEditContext getQuoteForEdit(Id quoteId) {
        Quote q = [
            SELECT Id, Pricebook2Id, OpportunityId,
                   Opportunity.AccountId, Opportunity.Account.Name,
                   Opportunity.Region__c
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        QuoteEditContext ctx = new QuoteEditContext();
        ctx.quoteId = q.Id;
        ctx.pricebookId = q.Pricebook2Id;
        ctx.opportunityId = q.OpportunityId;
        ctx.accountId = q.Opportunity != null ? q.Opportunity.AccountId : null;
        ctx.accountName = (q.Opportunity != null && q.Opportunity.Account != null)
            ? q.Opportunity.Account.Name : '';
        ctx.regionId = q.Opportunity != null ? q.Opportunity.Region__c : null;

        // Provide Standard Pricebook ID for auto-pricing
        List<Pricebook2> stdPbs = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        if (!stdPbs.isEmpty()) {
            ctx.standardPricebookId = stdPbs[0].Id;
        }

        ctx.lineItems = new List<QuoteLineItemResult>();
        for (QuoteLineItem qli : [
            SELECT Id, Product2Id, Product2.Name, Product2.ProductCode,
                   Product2.QuantityUnitOfMeasure,
                   PricebookEntryId, PricebookEntry.Tax__c,
                   PricebookEntry.Max_Discount_Percentage__c,
                   Quantity, ListPrice, UnitPrice, Discount,
                   Product_Line_Description__c,
                   Product_Detailed_Description__c,
                   Source_Pricebook__c
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
            item.listPrice = qli.ListPrice;
            item.unitPrice = qli.UnitPrice;
            item.discount = qli.Discount != null ? qli.Discount : 0;
            item.taxPercent = qli.PricebookEntry.Tax__c != null ? qli.PricebookEntry.Tax__c : 0;
            item.maxDiscount = qli.PricebookEntry.Max_Discount_Percentage__c;
            item.lineDescription = qli.Product_Line_Description__c;
            item.detailedDescription = qli.Product_Detailed_Description__c;
            item.sourcePricebook = qli.Source_Pricebook__c;
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
            ptr.termId = pt.Id;
            ptr.paymentTerm = pt.Payment_Term__c;
            ptr.percentage = pt.Percentage__c;
            ctx.paymentTerms.add(ptr);
        }

        return ctx;
    }

    @AuraEnabled
    public static void savePaymentTerms(Id quoteId, String paymentTermsJSON, Boolean deleteExisting) {
        try {
            List<PaymentTermInput> terms = (List<PaymentTermInput>) JSON.deserialize(paymentTermsJSON, List<PaymentTermInput>.class);

            if (deleteExisting) {
                List<Payment_Term__c> oldTerms = [SELECT Id FROM Payment_Term__c WHERE Quote__c = :quoteId];
                if (!oldTerms.isEmpty()) delete oldTerms;
            }

            if (terms == null || terms.isEmpty()) return;

            List<Payment_Term__c> ptList = new List<Payment_Term__c>();
            for (PaymentTermInput t : terms) {
                Payment_Term__c pt = new Payment_Term__c();
                pt.Quote__c = quoteId;
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
    public static void saveQuoteLineItems(Id quoteId, String lineItemsJSON) {
        try {
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
                qli.Product_Line_Description__c = item.lineDescription;
                qli.Product_Detailed_Description__c = item.detailedDescription;
                qli.Source_Pricebook__c = item.sourcePricebook;
                qli.Price_Status__c = 'Not Required';
                qliList.add(qli);
            }
            insert qliList;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Line item save failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateQuoteLineItems(Id quoteId, String lineItemsJSON) {
        try {
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
                qli.Product_Line_Description__c = item.lineDescription;
                qli.Product_Detailed_Description__c = item.detailedDescription;
                qli.Source_Pricebook__c = item.sourcePricebook;
                qli.Price_Status__c = 'Not Required';
                qliList.add(qli);
            }
            insert qliList;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Line item update failed: ' + e.getMessage());
        }
    }

    // ===== Inner Classes =====
    public class LineItemInput {
        public Id productId;
        public Id pricebookEntryId;
        public Decimal quantity;
        public Decimal unitPrice;
        public Decimal discount;
        public String lineDescription;
        public String detailedDescription;
        public String sourcePricebook;
    }

    public class OpportunityContext {
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
        @AuraEnabled public Decimal maxDiscount;
        @AuraEnabled public String sourcePricebook;
        @AuraEnabled public String sourcePricebookType;
        @AuraEnabled public List<PriceOption> availablePrices;
    }

    public class PriceOption {
        @AuraEnabled public String pricebookName;
        @AuraEnabled public String pricebookType;
        @AuraEnabled public Decimal price;
        @AuraEnabled public Boolean isSelected;
    }

    private class PricingOption {
        public String pricebookName;
        public String pricebookType;
        public Decimal price;
        public Decimal taxPercent;
        public Decimal maxDiscount;
        public Integer priority;
    }

    public class QuoteEditContext {
        @AuraEnabled public Id quoteId;
        @AuraEnabled public Id pricebookId;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Id regionId;
        @AuraEnabled public Id standardPricebookId;
        @AuraEnabled public List<QuoteLineItemResult> lineItems;
        @AuraEnabled public List<PaymentTermResult> paymentTerms;
    }

    public class PaymentTermInput {
        public String paymentTerm;
        public Decimal percentage;
    }

    public class PaymentTermResult {
        @AuraEnabled public Id termId;
        @AuraEnabled public String paymentTerm;
        @AuraEnabled public Decimal percentage;
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
        @AuraEnabled public Decimal listPrice;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal discount;
        @AuraEnabled public Decimal taxPercent;
        @AuraEnabled public Decimal maxDiscount;
        @AuraEnabled public String lineDescription;
        @AuraEnabled public String detailedDescription;
        @AuraEnabled public String sourcePricebook;
    }
}