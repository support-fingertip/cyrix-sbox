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

        ctx.defaultPaymentTerms = getDefaultPaymentTerms(opp.Buisness_Vertical__c);

        return ctx;
    }

    private static List<PaymentTermResult> getDefaultPaymentTerms(String vertical) {
        List<PaymentTermResult> results = new List<PaymentTermResult>();

        List<Payment_Terms_Master__c> matched = new List<Payment_Terms_Master__c>();
        if (String.isNotBlank(vertical)) {
            matched = [
                SELECT Id, Payment_Term__c, Percentage__c, Type__c
                FROM Payment_Terms_Master__c
                WHERE Type__c = :vertical
                ORDER BY CreatedDate ASC
            ];
        }

        // Fall back to records with blank Type when no vertical match
        if (matched.isEmpty()) {
            matched = [
                SELECT Id, Payment_Term__c, Percentage__c, Type__c
                FROM Payment_Terms_Master__c
                WHERE Type__c = null
                ORDER BY CreatedDate ASC
            ];
        }

        for (Payment_Terms_Master__c pt : matched) {
            PaymentTermResult ptr = new PaymentTermResult();
            ptr.paymentTerm = pt.Payment_Term__c;
            ptr.percentage = pt.Percentage__c;
            results.add(ptr);
        }
        return results;
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

    /**
     * Product search that defaults non-service products to their Price list5
     * (standard) PricebookEntry. The resolved tier and final Price_Status are
     * recomputed server-side by QuoteLineItemTriggerHandler on insert/update.
     *
     * Returned row meaning:
     *   - pricebookEntryId: the Standard PricebookEntry id (needed because
     *     QuoteLineItem.PricebookEntryId must live on the Quote's pricebook,
     *     which is Standard). Tier is tracked via Source_Pricebook_Ref__c.
     *   - unitPrice: Price list5 list price for non-service products; 0 for
     *     service products (user enters).
     *   - taxPercent: Product2.Tax__c (NOT PricebookEntry.Tax__c).
     *   - sourcePricebookId: Price list5 pricebook id for non-service
     *     products; null for service products.
     *   - sourcePricebookType: 'Price list5' or 'Service'.
     *   - isServiceItem: true when Product2.Service_Item__c = 'Yes'.
     *
     * accountId / regionId are accepted for API compatibility but are not
     * used by the new tier model - filtering by account or region is the
     * admin's responsibility via Pricebook2 activation.
     */
    // Product search now filters on Product2.Product_Type__c (Equipment /
    // Spare / Accessories / Consumables). Results use the tier model for
    // display price + resolveAppliedTier for the save-time approval flip.
    @AuraEnabled
    public static List<ProductSearchResult> searchProductsWithBestPrice(
        String searchTerm, String category, Id accountId, Id regionId
    ) {
        List<ProductSearchResult> results = new List<ProductSearchResult>();
        if (String.isBlank(searchTerm)) return results;

        String searchKey = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';

        // The LWC filter dropdown now exposes Product2.Product_Type__c
        // (Equipment / Spare / Accessories / Consumables). Older callers
        // sending the Product_Category label will fall through without
        // matching, but won't break the query.
        String prodQuery = 'SELECT Id, Name, ProductCode, Product_Category__c, Product_Type__c, Make__c, Model__c, ' +
            'Description, HSN_Code__c, Standard_Price__c, QuantityUnitOfMeasure, ' +
            'Line_Description__c, Detailed_Description__c, ' +
            'Service_Item__c, Tax__c ' +
            'FROM Product2 ' +
            'WHERE IsActive = true ' +
            'AND (Name LIKE :searchKey OR ProductCode LIKE :searchKey)';
        if (String.isNotBlank(category)) {
            prodQuery += ' AND Product_Type__c = :category';
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
        for (Product2 p : products) productIds.add(p.Id);

        // Standard pricebook entry - used as QLI.PricebookEntryId regardless of
        // tier, because the Quote lives on the Standard Pricebook.
        List<Pricebook2> stdPbs = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        if (stdPbs.isEmpty()) return results;
        Id stdPbId = stdPbs[0].Id;

        Map<Id, PricebookEntry> stdEntryMap = new Map<Id, PricebookEntry>();
        for (PricebookEntry pbe : [
            SELECT Id, Product2Id, Pricebook2Id, UnitPrice
            FROM PricebookEntry
            WHERE Pricebook2Id = :stdPbId
              AND Product2Id IN :productIds
              AND IsActive = true
        ]) {
            stdEntryMap.put(pbe.Product2Id, pbe);
        }

        // Tier 5 (default) - drives the shown Sales Price for non-service products.
        Set<Id> nonServiceIds = new Set<Id>();
        for (Product2 p : products) {
            if (p.Service_Item__c != 'Yes') nonServiceIds.add(p.Id);
        }
        Map<Id, PricebookTierService.ProductTierMap> tierMaps =
            PricebookTierService.loadTiers(nonServiceIds);

        for (Product2 prod : products) {
            ProductSearchResult psr = new ProductSearchResult();
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
            psr.isServiceItem = (prod.Service_Item__c == 'Yes');
            psr.taxPercent = prod.Tax__c;
            psr.availablePrices = new List<PriceOption>();

            if (psr.isServiceItem) {
                // Service items live on the Standard Pricebook. Map the
                // Standard PBE (if present) so downstream Quote/Order saves
                // can satisfy the required PricebookEntryId without hitting
                // a pricebook mismatch. Unit price is 0 — the user enters
                // the service price on the line.
                PricebookEntry svcEntry = stdEntryMap.get(prod.Id);
                if (svcEntry != null) {
                    psr.pricebookEntryId = svcEntry.Id;
                    psr.sourcePricebookId = svcEntry.Pricebook2Id;
                }
                psr.unitPrice = 0;
                psr.sourcePricebookType = 'Service';
                results.add(psr);
                continue;
            }

            PricebookEntry stdEntry = stdEntryMap.get(prod.Id);
            if (stdEntry == null) continue; // cannot be added to a Standard-pricebook quote

            PricebookTierService.ProductTierMap tiers = tierMaps.get(prod.Id);
            PricebookEntry tier5 = tiers == null ? null : tiers.tier(PricebookTierService.TIER5);

            psr.pricebookEntryId = stdEntry.Id;
            if (tier5 != null) {
                // Tier 5 exists — use it as the displayed Sales Price.
                psr.unitPrice = tier5.UnitPrice;
                psr.sourcePricebookId = tier5.Pricebook2Id;
                psr.sourcePricebook = PricebookTierService.TIER5;
                psr.sourcePricebookType = PricebookTierService.TIER5;
            } else {
                // No tier set up yet — fall back to the Standard PBE price so
                // the product still surfaces in search. The trigger will reject
                // the save if the org requires a tier entry, but at least the
                // rep can see the product instead of it vanishing silently.
                psr.unitPrice = stdEntry.UnitPrice;
                psr.sourcePricebookId = stdEntry.Pricebook2Id;
                psr.sourcePricebook = 'Standard';
                psr.sourcePricebookType = 'Standard';
            }

            // Export the discount-tier PBE prices (PL4 -> PL1, skipping
            // the Standard pricebook and Price list5) so the LWC can run
            // the live Price_Status decision client-side against the
            // actual tier ladder without round-tripping to Apex on every
            // keystroke.
            for (String t : new List<String>{
                PricebookTierService.TIER4,
                PricebookTierService.TIER3,
                PricebookTierService.TIER2,
                PricebookTierService.TIER1
            }) {
                PricebookEntry tierPbe = tiers == null ? null : tiers.tier(t);
                if (tierPbe == null || tierPbe.UnitPrice == null) continue;
                PriceOption po = new PriceOption();
                po.pricebookType = t;
                po.pricebookName = tierPbe.Pricebook2.Name;
                po.price = tierPbe.UnitPrice;
                po.isSelected = false;
                psr.availablePrices.add(po);
            }

            results.add(psr);
        }
        return results;
    }

    /**
     * Live tier + Price_Status preview for the LWC. Called whenever the user
     * edits UnitPrice, Discount, or Product on a line so the UI can echo
     * what the trigger will stamp on save.
     *
     * For a service item, returns status=Not Required and resolvedTier=null.
     * For a non-service item, returns the tightest-fitting tier for the
     * discounted unit price and the Price_Status that will be written.
     * Throws AuraHandledException when UnitPrice is below Price list5 - the
     * same floor the trigger enforces.
     */
    @AuraEnabled(cacheable=false)
    public static PricingPreview getProductPricingPreview(Id productId, Decimal unitPrice, Decimal discount, Decimal quantity) {
        PricingPreview out = new PricingPreview();
        if (productId == null) return out;

        List<Product2> prods = [
            SELECT Id, Service_Item__c, Tax__c
            FROM Product2
            WHERE Id = :productId
            LIMIT 1
        ];
        if (prods.isEmpty()) return out;
        Product2 p = prods[0];
        out.isServiceItem = (p.Service_Item__c == 'Yes');
        out.taxPercent = p.Tax__c;

        if (out.isServiceItem) {
            out.priceStatus = PricebookTierService.priceStatusForService();
            return out;
        }

        Map<Id, PricebookTierService.ProductTierMap> tierMaps =
            PricebookTierService.loadTiers(new Set<Id>{p.Id});
        PricebookTierService.ProductTierMap tiers = tierMaps.get(p.Id);
        PricebookEntry tier5 = tiers == null ? null : tiers.tier(PricebookTierService.TIER5);

        // Determine the standard price: prefer Price list5, fall back to
        // the Standard pricebook's PBE so products without a tier entry
        // can still be previewed / saved.
        Decimal standard;
        if (tier5 != null && tier5.UnitPrice != null) {
            standard = tier5.UnitPrice;
        } else {
            List<PricebookEntry> stdPbe = [
                SELECT UnitPrice
                FROM PricebookEntry
                WHERE Product2Id = :p.Id
                  AND IsActive = true
                  AND Pricebook2.IsStandard = true
                LIMIT 1
            ];
            standard = stdPbe.isEmpty() ? null : stdPbe[0].UnitPrice;
        }

        // Sales Price is locked to the Standard list price on
        // non-service lines. If the LWC passes anything else (above or
        // below), snap to Standard silently instead of erroring.
        Decimal up = unitPrice == null ? standard : unitPrice;
        if (standard != null && up != null && up != standard) {
            up = standard;
        }
        Decimal d = discount == null ? 0 : discount;
        Decimal taxPct = p.Tax__c != null ? p.Tax__c : 0;
        Decimal upVal = up == null ? 0 : up;
        Decimal discountedUnit = upVal * (1 - (d / 100));
        // Per-unit final price after discount AND tax — compared against
        // PL4..PL1 per-unit list prices. quantity is still accepted on
        // the signature so the LWC can keep passing it, but it isn't
        // folded into the tier-comparison amount.
        Decimal finalAmount = discountedUnit * (1 + (taxPct / 100));

        out.standardPrice = standard;

        if (tiers != null && !tiers.byTier.isEmpty()) {
            PricebookTierService.TierResolution applied =
                PricebookTierService.resolveAppliedTier(tiers, finalAmount);
            if (applied != null && applied.entry != null) {
                out.resolvedTier = applied.tierName;
                out.resolvedTierListPrice = applied.tierListPrice;
                out.resolvedPricebookId = applied.entry.Pricebook2Id;
                out.priceStatus = PricebookTierService.STATUS_APPROVAL_REQUIRED;
                return out;
            }
        }

        // Above the top discount tier (or no tier data) — tag the org's
        // Standard pricebook (IsStandard = true) and mark Not Required.
        List<Pricebook2> stdPbs = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        if (!stdPbs.isEmpty()) {
            out.resolvedTier = 'Standard';
            out.resolvedTierListPrice = standard;
            out.resolvedPricebookId = stdPbs[0].Id;
        }
        out.priceStatus = PricebookTierService.STATUS_NOT_REQUIRED;
        return out;
    }

    @AuraEnabled
    public static QuoteEditContext getQuoteForEdit(Id quoteId) {
        Quote q = [
            SELECT Id, Pricebook2Id, OpportunityId,
                   Opportunity.AccountId, Opportunity.Account.Name,
                   Opportunity.Region__c,
                   BillingName, BillingStreet, BillingCity,
                   BillingStateCode, BillingPostalCode, BillingCountryCode,
                   ShippingName, ShippingStreet, ShippingCity,
                   ShippingStateCode, ShippingPostalCode, ShippingCountryCode
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

        // Address fields
        ctx.billingName = q.BillingName;
        ctx.billingStreet = q.BillingStreet;
        ctx.billingCity = q.BillingCity;
        ctx.billingState = q.BillingStateCode;
        ctx.billingPostalCode = q.BillingPostalCode;
        ctx.billingCountry = q.BillingCountryCode;
        ctx.shippingName = q.ShippingName;
        ctx.shippingStreet = q.ShippingStreet;
        ctx.shippingCity = q.ShippingCity;
        ctx.shippingState = q.ShippingStateCode;
        ctx.shippingPostalCode = q.ShippingPostalCode;
        ctx.shippingCountry = q.ShippingCountryCode;

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
                   Price_Status__c,
                   Source_Pricebook_Ref__c, Source_Pricebook_Ref__r.Name
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
            item.priceStatus = qli.Price_Status__c;
            item.lineDescription = qli.Product_Line_Description__c;
            item.detailedDescription = qli.Product_Detailed_Description__c;
            item.sourcePricebookId = qli.Source_Pricebook_Ref__c;
            item.sourcePricebookName = qli.Source_Pricebook_Ref__r != null ? qli.Source_Pricebook_Ref__r.Name : '';
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

            Map<Id, Id> pbeByProduct = resolveQuotePricebookEntries(quoteId, lineItems);
            Map<Id, Id> optedPbByProduct = resolveOptedPricebooks(lineItems);

            List<QuoteLineItem> qliList = new List<QuoteLineItem>();
            for (LineItemInput item : lineItems) {
                QuoteLineItem qli = new QuoteLineItem();
                qli.QuoteId = quoteId;
                qli.Product2Id = item.productId;
                qli.PricebookEntryId = pbeByProduct.containsKey(item.productId)
                    ? pbeByProduct.get(item.productId)
                    : item.pricebookEntryId;
                qli.Quantity = item.quantity;
                qli.UnitPrice = item.unitPrice;
                qli.Discount = item.discount;
                qli.Product_Line_Description__c = item.lineDescription;
                qli.Product_Detailed_Description__c = item.detailedDescription;
                qli.Source_Pricebook_Ref__c = item.sourcePricebookId;
              //  qli.Opted_Price_Book__c = optedPbByProduct.get(item.productId);
                // Tax__c carries the Product's tax rate from the LWC. The
                // tiered-line trigger will re-stamp it from Product2.Tax__c
                // for non-service rows; service rows keep the value the
                // rep entered (trigger is a no-op on Tax for services).
                if (item.taxPercent != null) {
                    qli.Tax__c = item.taxPercent;
                }
                // Price_Status__c is stamped by the QuoteLineItem trigger.
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

            Map<Id, Id> pbeByProduct = resolveQuotePricebookEntries(quoteId, lineItems);
            Map<Id, Id> optedPbByProduct = resolveOptedPricebooks(lineItems);

            List<QuoteLineItem> qliList = new List<QuoteLineItem>();
            for (LineItemInput item : lineItems) {
                QuoteLineItem qli = new QuoteLineItem();
                qli.QuoteId = quoteId;
                qli.Product2Id = item.productId;
                qli.PricebookEntryId = pbeByProduct.containsKey(item.productId)
                    ? pbeByProduct.get(item.productId)
                    : item.pricebookEntryId;
                qli.Quantity = item.quantity;
                qli.UnitPrice = item.unitPrice;
                qli.Discount = item.discount;
                qli.Product_Line_Description__c = item.lineDescription;
                qli.Product_Detailed_Description__c = item.detailedDescription;
                qli.Source_Pricebook_Ref__c = item.sourcePricebookId;
                qli.Opted_Price_Book__c = optedPbByProduct.get(item.productId);
                // Tax__c carries the Product's tax rate from the LWC. The
                // tiered-line trigger will re-stamp it from Product2.Tax__c
                // for non-service rows; service rows keep the value the
                // rep entered (trigger is a no-op on Tax for services).
                if (item.taxPercent != null) {
                    qli.Tax__c = item.taxPercent;
                }
                // Price_Status__c is stamped by the QuoteLineItem trigger.
                qliList.add(qli);
            }
            insert qliList;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Line item update failed: ' + e.getMessage());
        }
    }

    /**
     * For each incoming line, resolve the product's opted discount
     * pricebook using the rule:
     *
     *   finalPrice = UnitPrice
     *              - (Discount% * UnitPrice)
     *              - (Tax% * UnitPrice)
     *
     *   Walk PL4 -> PL3 -> PL2 -> PL1 and return the HIGHEST tier
     *   whose list price is <= finalPrice. If finalPrice is below
     *   every configured tier, return PL1 (floor). If finalPrice is
     *   above the top existing tier (no discount tier applies),
     *   return null so the caller leaves Opted_Price_Book__c blank.
     *
     * Returns a productId -> Pricebook2 id map (only populated for
     * lines whose product has tier pricebooks and whose final amount
     * actually hits one).
     */
    private static Map<Id, Id> resolveOptedPricebooks(List<LineItemInput> lineItems) {
        Map<Id, Id> out = new Map<Id, Id>();
        if (lineItems == null || lineItems.isEmpty()) return out;

        Set<Id> productIds = new Set<Id>();
        for (LineItemInput li : lineItems) {
            if (li.productId != null) productIds.add(li.productId);
        }
        if (productIds.isEmpty()) return out;

        Map<Id, PricebookTierService.ProductTierMap> tierMaps =
            PricebookTierService.loadTiers(productIds);

        for (LineItemInput li : lineItems) {
            if (li.productId == null) continue;
            PricebookTierService.ProductTierMap tiers = tierMaps.get(li.productId);
            if (tiers == null || tiers.byTier.isEmpty()) continue;

            Decimal up  = li.unitPrice  == null ? 0 : li.unitPrice;
            Decimal d   = li.discount   == null ? 0 : li.discount;
            Decimal tax = li.taxPercent == null ? 0 : li.taxPercent;
            Decimal taxprice = (up * tax) / 100;
            Decimal finalPrice = up - ((d * up) / 100) - taxprice;

            PricebookTierService.TierResolution applied =
                PricebookTierService.resolveAppliedTier(tiers, finalPrice);
            if (applied != null && applied.entry != null) {
                out.put(li.productId, applied.entry.Pricebook2Id);
            }
        }
        return out;
    }

    // Price_Status__c and Tax__c on QuoteLineItem and the Quote rollup are
    // now owned by QuoteLineItemTriggerHandler. The controller passes
    // user-provided UnitPrice / Discount / Product2Id / PricebookEntryId
    // straight through and lets the trigger stamp everything derived.

    /**
     * Make sure every incoming line's PricebookEntryId lives on the
     * Quote's Pricebook2Id. Service items in particular sometimes arrive
     * with a null PBE (older saves, external callers) — in that case
     * find the Standard PBE for the product and use it. Falls back to
     * the incoming id if nothing fits so downstream DML surfaces the
     * original error.
     */
    private static Map<Id, Id> resolveQuotePricebookEntries(Id quoteId, List<LineItemInput> lineItems) {
        Map<Id, Id> out = new Map<Id, Id>();
        if (lineItems == null || lineItems.isEmpty()) return out;

        List<Quote> quotes = [SELECT Id, Pricebook2Id FROM Quote WHERE Id = :quoteId LIMIT 1];
        Id quotePbId = (!quotes.isEmpty() && quotes[0].Pricebook2Id != null)
            ? quotes[0].Pricebook2Id : null;

        if (quotePbId == null) {
            List<Pricebook2> stdPbs = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
            if (!stdPbs.isEmpty()) quotePbId = stdPbs[0].Id;
        }
        if (quotePbId == null) return out;

        Set<Id> productIds = new Set<Id>();
        for (LineItemInput li : lineItems) {
            if (li.productId != null) productIds.add(li.productId);
        }
        if (productIds.isEmpty()) return out;

        for (PricebookEntry pbe : [
            SELECT Id, Product2Id
            FROM PricebookEntry
            WHERE Pricebook2Id = :quotePbId
              AND Product2Id IN :productIds
              AND IsActive = true
        ]) {
            out.put(pbe.Product2Id, pbe.Id);
        }
        return out;
    }

    // ===== Inner Classes =====
    public class LineItemInput {
        public Id productId;
        public Id pricebookEntryId;
        public Decimal quantity;
        public Decimal unitPrice;
        public Decimal discount;
        public Decimal maxDiscount;
        public Decimal taxPercent;
        public String lineDescription;
        public String detailedDescription;
        public Id sourcePricebookId;
        public String priceStatus;
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
        @AuraEnabled public List<PaymentTermResult> defaultPaymentTerms;
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
        @AuraEnabled public Id sourcePricebookId;
        @AuraEnabled public String sourcePricebook;
        @AuraEnabled public String sourcePricebookType;
        @AuraEnabled public List<PriceOption> availablePrices;
        @AuraEnabled public Boolean isServiceItem;
    }

    public class PricingPreview {
        @AuraEnabled public Boolean isServiceItem;
        @AuraEnabled public Decimal taxPercent;
        @AuraEnabled public Decimal standardPrice;
        @AuraEnabled public String resolvedTier;
        @AuraEnabled public Decimal resolvedTierListPrice;
        @AuraEnabled public Id resolvedPricebookId;
        @AuraEnabled public String priceStatus;
    }

    public class PriceOption {
        @AuraEnabled public String pricebookName;
        @AuraEnabled public String pricebookType;
        @AuraEnabled public Decimal price;
        @AuraEnabled public Boolean isSelected;
    }

    public class QuoteEditContext {
        @AuraEnabled public Id quoteId;
        @AuraEnabled public Id pricebookId;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Id regionId;
        @AuraEnabled public Id standardPricebookId;
        @AuraEnabled public String billingName;
        @AuraEnabled public String billingStreet;
        @AuraEnabled public String billingCity;
        @AuraEnabled public String billingState;
        @AuraEnabled public String billingPostalCode;
        @AuraEnabled public String billingCountry;
        @AuraEnabled public String shippingName;
        @AuraEnabled public String shippingStreet;
        @AuraEnabled public String shippingCity;
        @AuraEnabled public String shippingState;
        @AuraEnabled public String shippingPostalCode;
        @AuraEnabled public String shippingCountry;
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
        @AuraEnabled public String priceStatus;
        @AuraEnabled public String lineDescription;
        @AuraEnabled public String detailedDescription;
        @AuraEnabled public Id sourcePricebookId;
        @AuraEnabled public String sourcePricebookName;
    }

    // ===== Quote Session (per-Visit) =====

    @AuraEnabled(cacheable=false)
    public static VisitQuoteSession getQuotesForVisit(Id visitId) {
        VisitQuoteSession session = new VisitQuoteSession();

        if (visitId == null) {
            session.quotes = new List<QuoteSummary>();
            session.opportunities = new List<OpportunityOption>();
            return session;
        }

        Visit__c v = [
            SELECT Id, Name, Account__c, Account__r.Name, Lead__c, Visit_for__c
            FROM Visit__c
            WHERE Id = :visitId
            LIMIT 1
        ];

        session.visitId = v.Id;
        session.visitName = v.Name;
        session.accountId = v.Account__c;
        session.accountName = v.Account__r != null ? v.Account__r.Name : '';

        List<QuoteSummary> quotes = new List<QuoteSummary>();
        List<OpportunityOption> oppOptions = new List<OpportunityOption>();

        if (v.Account__c != null) {
            for (Opportunity opp : [
                SELECT Id, Name, StageName
                FROM Opportunity
                WHERE AccountId = :v.Account__c
                ORDER BY CreatedDate DESC
            ]) {
                OpportunityOption opt = new OpportunityOption();
                opt.opportunityId = opp.Id;
                opt.opportunityName = opp.Name;
                opt.stage = opp.StageName;
                oppOptions.add(opt);
            }

            for (Quote q : [
                SELECT Id, Name, QuoteNumber, Status, ExpirationDate,
                       GrandTotal, TotalPrice, CreatedDate,
                       OpportunityId, Opportunity.Name,
                       Opportunity.AccountId, Opportunity.Account.Name
                FROM Quote
                WHERE Opportunity.AccountId = :v.Account__c
                ORDER BY CreatedDate DESC
            ]) {
                QuoteSummary qs = new QuoteSummary();
                qs.quoteId = q.Id;
                qs.name = q.Name;
                qs.quoteNumber = q.QuoteNumber;
                qs.status = q.Status;
                qs.expirationDate = q.ExpirationDate;
                qs.grandTotal = q.GrandTotal != null ? q.GrandTotal : q.TotalPrice;
                qs.createdDate = q.CreatedDate;
                qs.opportunityId = q.OpportunityId;
                qs.opportunityName = q.Opportunity != null ? q.Opportunity.Name : '';
                quotes.add(qs);
            }
        }

        session.quotes = quotes;
        session.opportunities = oppOptions;
        return session;
    }

    public class VisitQuoteSession {
        @AuraEnabled public Id visitId;
        @AuraEnabled public String visitName;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public List<QuoteSummary> quotes;
        @AuraEnabled public List<OpportunityOption> opportunities;
    }

    public class QuoteSummary {
        @AuraEnabled public Id quoteId;
        @AuraEnabled public String name;
        @AuraEnabled public String quoteNumber;
        @AuraEnabled public String status;
        @AuraEnabled public Date expirationDate;
        @AuraEnabled public Decimal grandTotal;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
    }

    public class OpportunityOption {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public String stage;
    }
}