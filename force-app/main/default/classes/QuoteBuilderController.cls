/* Class Name   : QuoteBuilderController
* Company      : Fingertipplus
* Created Date : 07-04-2026
* @description : Apex controller for the quoteBuilder LWC component.
*                Provides methods for Opportunity context, product search,
*                price book entry retrieval, account addresses, and
*                atomic Quote + QuoteLineItem save.
*
* Change Log:
* -----------------------------------------------------------------------------
* Ver | Author           | Date       | Description
* -----------------------------------------------------------------------------
* 1.0 | Claude AI        | 07-04-2026 | Initial version
* -----------------------------------------------------------------------------
**************************************************************/
public with sharing class QuoteBuilderController {

    /**
     * Fetches Opportunity context for quote creation.
     */
    @AuraEnabled(cacheable=true)
    public static OpportunityContext getOpportunityContext(Id opportunityId) {
        Opportunity opp = [
            SELECT Id, Name, AccountId, Account.Name,
                   Account.BillingStreet, Account.BillingCity,
                   Account.BillingState, Account.BillingPostalCode,
                   Account.BillingCountry, Account.GST_Number__c,
                   Account.ShippingStreet, Account.ShippingCity,
                   Account.ShippingState, Account.ShippingPostalCode,
                   Account.ShippingCountry,
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

        // Build billing address string
        if (opp.Account != null) {
            List<String> parts = new List<String>();
            if (String.isNotBlank(opp.Account.BillingStreet)) parts.add(opp.Account.BillingStreet);
            if (String.isNotBlank(opp.Account.BillingCity)) parts.add(opp.Account.BillingCity);
            if (String.isNotBlank(opp.Account.BillingState)) parts.add(opp.Account.BillingState);
            if (String.isNotBlank(opp.Account.BillingPostalCode)) parts.add(opp.Account.BillingPostalCode);
            if (String.isNotBlank(opp.Account.BillingCountry)) parts.add(opp.Account.BillingCountry);
            ctx.billingAddress = String.join(parts, ', ');

            List<String> shipParts = new List<String>();
            if (String.isNotBlank(opp.Account.ShippingStreet)) shipParts.add(opp.Account.ShippingStreet);
            if (String.isNotBlank(opp.Account.ShippingCity)) shipParts.add(opp.Account.ShippingCity);
            if (String.isNotBlank(opp.Account.ShippingState)) shipParts.add(opp.Account.ShippingState);
            if (String.isNotBlank(opp.Account.ShippingPostalCode)) shipParts.add(opp.Account.ShippingPostalCode);
            if (String.isNotBlank(opp.Account.ShippingCountry)) shipParts.add(opp.Account.ShippingCountry);
            ctx.shippingAddress = String.join(shipParts, ', ');

            ctx.gstNumber = opp.Account.GST_Number__c;
        }

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

        // Resolve pricebook
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
     * Saves Quote header and all line items in a single transaction.
     */
    @AuraEnabled
    public static Id saveQuoteWithLineItems(String quoteJSON, String lineItemsJSON, String chargesJSON) {
        SavePoint sp = Database.setSavepoint();
        try {
            QuoteHeaderInput header = (QuoteHeaderInput) JSON.deserialize(quoteJSON, QuoteHeaderInput.class);
            List<LineItemInput> lineItems = (List<LineItemInput>) JSON.deserialize(lineItemsJSON, List<LineItemInput>.class);
            ChargesInput charges = (ChargesInput) JSON.deserialize(chargesJSON, ChargesInput.class);

            if (lineItems == null || lineItems.isEmpty()) {
                throw new AuraHandledException('At least one line item is required.');
            }

            // Create Quote
            Quote newQuote = new Quote();
            newQuote.Name = header.name;
            newQuote.OpportunityId = header.opportunityId;
            newQuote.Pricebook2Id = header.pricebookId;
            newQuote.Quote_Date__c = header.quoteDate;
            newQuote.Valid_Till__c = header.validTill;
            newQuote.Billing_Address__c = header.billingAddress;
            newQuote.Shipping_Address__c = header.shippingAddress;
            newQuote.Shipping_Mode__c = header.shippingMode;
            newQuote.Vertical__c = header.vertical;
            newQuote.is_Active__c = header.isActive;
            newQuote.Price_Status__c = 'Draft';
            newQuote.Status = 'Draft';

            // Extra charges stored on Quote standard fields
            if (charges != null) {
                newQuote.ShippingHandling = charges.shippingCharges != null ? charges.shippingCharges : 0;
                newQuote.Tax = charges.taxAmount != null ? charges.taxAmount : 0;
                newQuote.Description = buildChargesDescription(charges);
            }

            insert newQuote;

            // Create Line Items
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

            return newQuote.Id;
        } catch (AuraHandledException e) {
            Database.rollback(sp);
            throw e;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Error saving quote: ' + e.getMessage());
        }
    }

    /**
     * Builds a description string with all extra charges for audit trail.
     */
    private static String buildChargesDescription(ChargesInput charges) {
        List<String> parts = new List<String>();
        if (charges.shippingCharges != null && charges.shippingCharges > 0)
            parts.add('Shipping: ' + charges.shippingCharges);
        if (charges.transportCharges != null && charges.transportCharges > 0)
            parts.add('Transport: ' + charges.transportCharges);
        if (charges.warrantyCost != null && charges.warrantyCost > 0)
            parts.add('Warranty: ' + charges.warrantyCost);
        if (charges.installationCost != null && charges.installationCost > 0)
            parts.add('Installation: ' + charges.installationCost);
        if (charges.packingCharges != null && charges.packingCharges > 0)
            parts.add('Packing: ' + charges.packingCharges);
        if (charges.trainingCost != null && charges.trainingCost > 0)
            parts.add('Training: ' + charges.trainingCost);
        return parts.isEmpty() ? '' : 'Additional Charges: ' + String.join(parts, ' | ');
    }

    // ===== Input Classes =====

    public class QuoteHeaderInput {
        public String name;
        public Id opportunityId;
        public Id pricebookId;
        public Date quoteDate;
        public Date validTill;
        public String billingAddress;
        public String shippingAddress;
        public String shippingMode;
        public String vertical;
        public Boolean isActive;
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

    public class ChargesInput {
        public Decimal shippingCharges;
        public Decimal transportCharges;
        public Decimal warrantyCost;
        public Decimal installationCost;
        public Decimal packingCharges;
        public Decimal trainingCost;
        public Decimal taxAmount;
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
        @AuraEnabled public String billingAddress;
        @AuraEnabled public String shippingAddress;
        @AuraEnabled public String gstNumber;
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
}
