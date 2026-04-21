/**
 * Authoritative server-side stamp for QuoteLineItem.
 *
 * For non-service lines:
 *   - Prefers Price list5 as the standard list price. If the product has
 *     no Price list5 entry, the Standard pricebook's PBE is used as the
 *     fallback standard so the save still succeeds (no more
 *     'active pricebook tier not found' hard error).
 *   - Sales Price is locked to the Standard list price. Any value other
 *     than the Standard (above OR below) is silently snapped back —
 *     Discount is the lever used to lower the effective price.
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

    // Entry point for QuoteLineItemTrigger.before(Insert|Update). Applies
    // the tier-applied-pricebook rule: final amount after discount + tax
    // is compared against PL4..PL1 to pick Source_Pricebook_Ref__c and
    // to flip Price_Status__c to Approval Required when the amount drops
    // at or below PL4.
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

        // One Id lookup for the org's Standard pricebook — used as the
        // default Source_Pricebook_Ref__c when the QLI's final amount is
        // above Price list4 (i.e. no discount tier applies).
        Id standardPbId = loadStandardPricebookId();

        for (QuoteLineItem qli : newList) {
            Product2 p = prodMap.get(qli.Product2Id);
            if (p == null) continue;

            if (p.Service_Item__c == 'Yes') {
                stampServiceLine(qli);
            } else {
                stampTieredLine(qli, p, tierMaps.get(p.Id),
                    stdPriceByProduct.get(p.Id), standardPbId);
            }
        }
    }

    private static Id loadStandardPricebookId() {
        List<Pricebook2> pbs = [
            SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1
        ];
        return pbs.isEmpty() ? null : pbs[0].Id;
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
        Decimal stdPriceFallback,
        Id standardPbId
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

        // Sales Price on non-service lines is locked to the Standard
        // list price. Any value other than the Standard — above OR
        // below — snaps back silently. Discount is the lever used to
        // lower the effective price and engage the approval path.
        if (unitPrice != standardPrice) {
            qli.UnitPrice = standardPrice;
            unitPrice = standardPrice;
        }

        Decimal qty      = qli.Quantity == null ? 0 : qli.Quantity;
        Decimal discount = qli.Discount == null ? 0 : qli.Discount;
        Decimal taxPct   = qli.Tax__c != null ? qli.Tax__c
                         : (p.Tax__c != null ? p.Tax__c : 0);

        // Final *per-unit* price after discount AND tax — compared
        // against the per-unit list prices stored on the tier PBEs.
        // PricebookEntry.UnitPrice is a per-unit value by definition,
        // so the comparison must happen at that granularity; line
        // total would be off by a factor of Qty and the tier flip
        // would only engage on 1-unit lines.
        Decimal discountedUnit = unitPrice * (1 - (discount / 100));
        Decimal finalUnit      = discountedUnit * (1 + (taxPct / 100));

        // Applied-pricebook selection: walk PL4 -> PL1 and pick the
        // highest tier whose list price is still <= finalUnit. If
        // finalUnit is above PL4, the line stays at Standard and no
        // approval is needed.
        PricebookTierService.TierResolution applied = null;
        if (tiers != null && !tiers.byTier.isEmpty()) {
            applied = PricebookTierService.resolveAppliedTier(tiers, finalUnit);
        }

        Boolean hitsDiscountTier = (applied != null && applied.entry != null);
        if (hitsDiscountTier) {
            qli.Source_Pricebook_Ref__c = applied.entry.Pricebook2Id;
            qli.Price_Status__c = 'Approval Required';
        } else {
            // Above PL4 (or no tier data) — tag the org's Standard
            // Pricebook (IsStandard = true) and mark the line as
            // Not Required.
            if (standardPbId != null) {
                qli.Source_Pricebook_Ref__c = standardPbId;
            }
            qli.Price_Status__c = 'Not Required';
        }

        // Source tax from Product2, not PricebookEntry.
        qli.Tax__c = p.Tax__c;

        // Tax Amount = (Qty x UnitPrice x (1 - Discount/100)) x (Tax%/100).
        // Precomputed here so the Quote page + reports don't need a
        // formula — matches the OrderItem.Tax_Amount__c behavior.
        Decimal taxRate = p.Tax__c != null ? p.Tax__c : 0;
        qli.Tax_Amount__c = (qty * discountedUnit) * (taxRate / 100);
    }

    /**
     * Roll up line-item price status to the parent Quote.
     * - If any line is Approval Required, Quote.Price_Status__c = Approval Required.
     * - Otherwise Not Required.
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
            // 'Draft' is not a valid Quote.Price_Status__c picklist value
            // in this org — the allowed set is Approval Required /
            // Approved / Not Required. Use 'Not Required' as the default
            // when no child line currently needs approval.
            String target = approvalQuoteIds.contains(q.Id) ? 'Approval Required' : 'Not Required';
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