/**
 * Authoritative server-side stamp for QuoteLineItem.
 *
 * For non-service lines:
 *   - Prefers Price list5 as the standard list price. If the product has
 *     no Price list5 entry, the Standard pricebook's PBE is used as the
 *     fallback standard so the save still succeeds (no more
 *     'active pricebook tier not found' hard error).
 *   - Enforces sales-price floor: UnitPrice cannot be below the standard.
 *   - Stamps Tax__c from Product2.Tax__c (ignores PricebookEntry.Tax__c).
 *   - Resolves the tightest-fitting tier for the discounted unit price and
 *     writes that tier's Pricebook2 id into Source_Pricebook_Ref__c.
 *     (QuoteLineItem.PricebookEntryId itself is NOT reassigned to the tier
 *     PBE because Salesforce requires QLI.PricebookEntry.Pricebook2 to match
 *     the parent Quote.Pricebook2 - the Quote is on Standard Pricebook.)
 *   - Sets Price_Status__c = Approval Required when the final unit price is
 *     below the standard price OR when the discount pushes it below every
 *     existing tier.
 *
 * For service lines (Product2.Service_Item__c = 'Yes'):
 *   - Tier logic and floor enforcement are skipped.
 *   - Tax__c and UnitPrice come from the user verbatim.
 *   - Price_Status__c is always Not Required.
 *
 * After any change, rolls up Quote.Price_Status__c. Any line in Approval
 * Required promotes the Quote to Approval Required. An already-Approved
 * Quote is never regressed by this handler.
 */
public with sharing class QuoteLineItemTriggerHandler {

    // Set to true by other handlers (e.g. quoteTriggerHandler.snapshotQuotesOnRevision)
    // when inserting cloned history rows that must retain their original values.
    public static Boolean bypass = false;

    // Guards the Quote rollup DML from re-entering this handler via the
    // Quote trigger's after-update path.
    private static Boolean isRolling = false;

    public static void beforeInsertOrUpdate(List<QuoteLineItem> newList, Map<Id, QuoteLineItem> oldMap) {
        if (bypass) return;
        if (newList == null || newList.isEmpty()) return;

        Set<Id> productIds = new Set<Id>();
        for (QuoteLineItem qli : newList) {
            if (qli.Product2Id != null) productIds.add(qli.Product2Id);
        }
        if (productIds.isEmpty()) return;

        Map<Id, Product2> prodMap = new Map<Id, Product2>([
            SELECT Id, Service_Item__c, Tax__c
            FROM Product2
            WHERE Id IN :productIds
        ]);

        Set<Id> nonServiceIds = new Set<Id>();
        for (Product2 p : prodMap.values()) {
            if (p.Service_Item__c != 'Yes') nonServiceIds.add(p.Id);
        }
        Map<Id, PricebookTierService.ProductTierMap> tierMaps =
            PricebookTierService.loadTiers(nonServiceIds);

        // Fallback list prices from the Standard pricebook for products
        // that don't have a Price list5 tier entry set up yet. Keyed by
        // Product2Id.
        Map<Id, Decimal> stdPriceByProduct = loadStandardPrices(nonServiceIds);

        for (QuoteLineItem qli : newList) {
            Product2 p = prodMap.get(qli.Product2Id);
            if (p == null) continue;

            if (p.Service_Item__c == 'Yes') {
                stampServiceLine(qli);
            } else {
                stampTieredLine(qli, p, tierMaps.get(p.Id), stdPriceByProduct.get(p.Id));
            }
        }
    }

    private static Map<Id, Decimal> loadStandardPrices(Set<Id> productIds) {
        Map<Id, Decimal> out = new Map<Id, Decimal>();
        if (productIds == null || productIds.isEmpty()) return out;
        for (PricebookEntry pbe : [
            SELECT Product2Id, UnitPrice
            FROM PricebookEntry
            WHERE Product2Id IN :productIds
              AND IsActive = true
              AND Pricebook2.IsStandard = true
        ]) {
            if (pbe.UnitPrice != null) out.put(pbe.Product2Id, pbe.UnitPrice);
        }
        return out;
    }

    private static void stampServiceLine(QuoteLineItem qli) {
        // Service items: Sales Price and Tax are user-entered, and there is
        // no list-price tier to compare against. Force Approval Required so
        // every service line goes through the approval path — the business
        // rule is "approval required except when the product's Service_Item
        // field is No" (i.e. regular products continue using tier logic in
        // stampTieredLine below).
        qli.Price_Status__c = 'Approval Required';
        // Do not touch Tax__c, UnitPrice, Discount, PricebookEntryId,
        // or Source_Pricebook_Ref__c - trust the user input.
    }

    private static void stampTieredLine(
        QuoteLineItem qli,
        Product2 p,
        PricebookTierService.ProductTierMap tiers,
        Decimal stdPriceFallback
    ) {
        // Figure out the "standard" list price to compare against. Prefer
        // the Price list5 tier; fall back to the Standard pricebook entry
        // so products that don't have a Price list5 entry yet can still be
        // saved without hitting 'active pricebook tier not found'.
        PricebookEntry tier5 = tiers == null ? null : tiers.tier(PricebookTierService.TIER5);
        Decimal standardPrice;
        if (tier5 != null && tier5.UnitPrice != null) {
            standardPrice = tier5.UnitPrice;
        } else if (stdPriceFallback != null) {
            standardPrice = stdPriceFallback;
        } else {
            // No tier and no Standard PBE — can't infer a standard price,
            // so leave Price_Status untouched and trust the caller.
            qli.Tax__c = p.Tax__c;
            return;
        }

        Decimal unitPrice = qli.UnitPrice == null ? 0 : qli.UnitPrice;

        // Sales-price floor: Sales Price may be raised above standard, but
        // never lowered below it. Users must use Discount for lower effective
        // prices so the approval path is engaged.
        if (unitPrice < standardPrice) {
            qli.addError(
                'Sales Price (' + unitPrice + ') cannot be below the standard list price (' +
                standardPrice + '). Use Discount instead of lowering Sales Price.'
            );
            return;
        }

        Decimal discount = qli.Discount == null ? 0 : qli.Discount;
        Decimal discountedUnit = unitPrice * (1 - (discount / 100));

        // Tier tagging: walk the existing tier entries (whatever is set up
        // for this product, whether that's 1, 2, 3, 4, or 5 tiers) and
        // tag the tightest-fitting one — i.e. the tier whose list price is
        // the smallest value still >= discountedUnit. That's equivalent to
        // "amount after discount is <= tier's list price".
        if (tiers != null && !tiers.byTier.isEmpty()) {
            PricebookTierService.TierResolution r =
                PricebookTierService.resolveTier(tiers, discountedUnit);
            if (r != null && r.entry != null) {
                qli.Source_Pricebook_Ref__c = r.entry.Pricebook2Id;
            }
        }

        // Source tax from Product2, not PricebookEntry.
        qli.Tax__c = p.Tax__c;

        // Price_Status: below the standard -> Approval Required, otherwise
        // Not Required. The underFloor flag is only meaningful when we
        // actually had tier data, so compute it locally.
        Boolean underFloor = false;
        if (tiers != null && !tiers.byTier.isEmpty()) {
            underFloor =
                PricebookTierService.resolveTier(tiers, discountedUnit).underFloor;
        }
        qli.Price_Status__c = PricebookTierService.computePriceStatus(
            unitPrice, discount, standardPrice, underFloor
        );
    }

    /**
     * Roll up line-item price status to the parent Quote.
     * - If any line is Approval Required, Quote.Price_Status__c = Approval Required.
     * - Otherwise Draft.
     * - Never regresses an already-Approved Quote (approvers' decision is sticky
     *   until Quote is resubmitted or marked for revision).
     */
    public static void afterChange(Set<Id> quoteIds) {
        if (bypass) return;
        if (isRolling) return;
        if (quoteIds == null || quoteIds.isEmpty()) return;

        List<Quote> quotes = [
            SELECT Id, Price_Status__c
            FROM Quote
            WHERE Id IN :quoteIds
        ];
        if (quotes.isEmpty()) return;

        Set<Id> approvalQuoteIds = new Set<Id>();
        for (AggregateResult ar : [
            SELECT QuoteId qid
            FROM QuoteLineItem
            WHERE QuoteId IN :quoteIds
              AND Price_Status__c = 'Approval Required'
            GROUP BY QuoteId
        ]) {
            approvalQuoteIds.add((Id) ar.get('qid'));
        }

        List<Quote> toUpdate = new List<Quote>();
        for (Quote q : quotes) {
            if (q.Price_Status__c == 'Approved') continue;
            String target = approvalQuoteIds.contains(q.Id) ? 'Approval Required' : 'Draft';
            if (q.Price_Status__c != target) {
                q.Price_Status__c = target;
                toUpdate.add(q);
            }
        }
        if (toUpdate.isEmpty()) return;

        isRolling = true;
        try {
            update toUpdate;
        } finally {
            isRolling = false;
        }
    }
}