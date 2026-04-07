/* Class Name   : QuoteBuilderController
* Company      : Fingertipplus
* Created Date : 07-04-2026
* @description : Apex controller for the newQuoteCmp LWC component.
*                Provides methods for Opportunity context, product search,
*                price book entry retrieval, and QuoteLineItem management.
*                Quote header is saved via lightning-record-edit-form (LDS).
*
* Change Log:
* -----------------------------------------------------------------------------
* Ver | Author           | Date       | Description
* -----------------------------------------------------------------------------
* 1.0 | Claude AI        | 07-04-2026 | Initial version
* 2.0 | Claude AI        | 07-04-2026 | Refactored for record-edit-form pattern
* -----------------------------------------------------------------------------
**************************************************************/
public with sharing class QuoteBuilderController {

    /**
     * Fetches Opportunity context for quote creation (pricebook, account info).
     */
    @AuraEnabled(cacheable=true)
    public static OpportunityContext getOpportunityContext(Id opportunityId) {
        Opportunity opp = [
            SELECT Id, Name, AccountId, Account.Name,
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
        return ctx;
    }

    /**
     * Searches active products by name, code, or category.
     * Returns products with their PricebookEntry for the given pricebook.
     */
    @AuraEnabled
    public static List<ProductSearchResult> searchProducts(String searchTerm, Id pricebookId, String category) {
        List<ProductSearchResult> results = new List<ProductSearchResult>();
        String searchKey = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';

        Id pbId = pricebookId;
        if (pbId == null) {
            List<Pricebook2> stdPb = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
            if (!stdPb.isEmpty()) {
                pbId = stdPb[0].Id;
            }
        }
        if (pbId == null) return results;

        String query = 'SELECT Id, Product2Id, Product2.Name, Product2.ProductCode, ' +
            'Product2.Product_Category__c, Product2.Make__c, Product2.Model__c, ' +
            'Product2.Description, Product2.HSN_Code__c, Product2.Tax__c, ' +
            'Product2.Standard_Price__c, Product2.QuantityUnitOfMeasure, ' +
            'Product2.Line_Description__c, Product2.Detailed_Description__c, ' +
            'Product2.Shipping_Charges_Percent__c, Product2.Warranty_Cost_Percent__c, ' +
            'Product2.Training_Cost_Percent__c, Product2.Installation_Cost_Percent__c, ' +
            'Product2.Internal_Transport_Cost_Percent__c, Product2.Packing_Charges_Percent__c, ' +
            'Product2.Default_Warranty_Months__c, Product2.Installation_Terms__c, ' +
            'Product2.Warranty_Terms_Description__c, ' +
            'UnitPrice, CurrencyIsoCode ' +
            'FROM PricebookEntry ' +
            'WHERE Pricebook2Id = :pbId ' +
            'AND Product2.IsActive = true ' +
            'AND (Product2.Name LIKE :searchKey ' +
            'OR Product2.ProductCode LIKE :searchKey ' +
            'OR Product2.Item_Code__c LIKE :searchKey)';

        if (String.isNotBlank(category)) {
            query += ' AND Product2.Product_Category__c = :category';
        }

        query += ' ORDER BY Product2.Name ASC LIMIT 20';

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
            psr.shippingChargesPercent = pbe.Product2.Shipping_Charges_Percent__c;
            psr.warrantyCostPercent = pbe.Product2.Warranty_Cost_Percent__c;
            psr.trainingCostPercent = pbe.Product2.Training_Cost_Percent__c;
            psr.installationCostPercent = pbe.Product2.Installation_Cost_Percent__c;
            psr.transportCostPercent = pbe.Product2.Internal_Transport_Cost_Percent__c;
            psr.packingChargesPercent = pbe.Product2.Packing_Charges_Percent__c;
            psr.defaultWarrantyMonths = pbe.Product2.Default_Warranty_Months__c;
            psr.installationTerms = pbe.Product2.Installation_Terms__c;
            psr.warrantyTerms = pbe.Product2.Warranty_Terms_Description__c;
            results.add(psr);
        }

        return results;
    }

    /**
     * Loads pricebook context and line items for an existing Quote (edit mode).
     * Quote header fields are loaded automatically by lightning-record-edit-form.
     */
    @AuraEnabled
    public static QuoteEditContext getQuoteForEdit(Id quoteId) {
        Quote q = [
            SELECT Id, Pricebook2Id, OpportunityId
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        QuoteEditContext ctx = new QuoteEditContext();
        ctx.quoteId = q.Id;
        ctx.pricebookId = q.Pricebook2Id;
        ctx.opportunityId = q.OpportunityId;

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

    /**
     * Saves QuoteLineItems after the Quote header is created by record-edit-form.
     */
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

    /**
     * Updates QuoteLineItems for an existing Quote.
     * Deletes all existing items and re-creates from the provided list.
     */
    @AuraEnabled
    public static void updateQuoteLineItems(Id quoteId, String lineItemsJSON) {
        List<LineItemInput> lineItems = (List<LineItemInput>) JSON.deserialize(lineItemsJSON, List<LineItemInput>.class);

        if (lineItems == null || lineItems.isEmpty()) {
            throw new AuraHandledException('At least one line item is required.');
        }

        List<QuoteLineItem> oldItems = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :quoteId];
        if (!oldItems.isEmpty()) {
            delete oldItems;
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

    // ===== Input Classes =====

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

    // ===== Output Classes =====

    public class OpportunityContext {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Id pricebookId;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public String vertical;
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
        @AuraEnabled public Decimal shippingChargesPercent;
        @AuraEnabled public Decimal warrantyCostPercent;
        @AuraEnabled public Decimal trainingCostPercent;
        @AuraEnabled public Decimal installationCostPercent;
        @AuraEnabled public Decimal transportCostPercent;
        @AuraEnabled public Decimal packingChargesPercent;
        @AuraEnabled public Decimal defaultWarrantyMonths;
        @AuraEnabled public String installationTerms;
        @AuraEnabled public String warrantyTerms;
    }

    public class QuoteEditContext {
        @AuraEnabled public Id quoteId;
        @AuraEnabled public Id pricebookId;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public List<QuoteLineItemResult> lineItems;
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
