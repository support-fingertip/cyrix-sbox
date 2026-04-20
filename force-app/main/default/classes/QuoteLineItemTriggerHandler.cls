/**
 * Authoritative server-side stamp for QuoteLineItem.
 *
 * For non-service lines:
 *   - Validates product has a Price list5 PricebookEntry (blocks insert if not).
 *   - Enforces sales-price floor: UnitPrice cannot be below Price list5.
 *   - Stamps Tax__c from Product2.Tax__c (ignores PricebookEntry.Tax__c).
 *   - Resolves the tightest-fitting tier for the discounted unit price and
 *     writes that tier's Pricebook2 id into Source_Pricebook_Ref__c.
 *     (QuoteLineItem.PricebookEntryId itself is NOT reassigned to the tier
 *     PBE because Salesforce requires QLI.PricebookEntry.Pricebook2 to match
 *     the parent Quote.Pricebook2 - the Quote is on Standard Pricebook.)
 *   - Sets Price_Status__c = Approval Required when the final unit price is
 *     below the Price list5 list price OR when the discount pushes it below
 *     every existing tier.
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

        for (QuoteLineItem qli : newList) {
            Product2 p = prodMap.get(qli.Product2Id);
            if (p == null) continue;

            if (p.Service_Item__c == 'Yes') {
                stampServiceLine(qli);
            } else {
                stampTieredLine(qli, p, tierMaps.get(p.Id));
            }
        }
    }

    private static void stampServiceLine(QuoteLineItem qli) {
        // Service items: Sales Price and Tax are user-entered.
        // Price_Status__c is always Not Required - no approval path for services.
        qli.Price_Status__c = PricebookTierService.priceStatusForService();
        // Do not touch Tax__c, UnitPrice, Discount, PricebookEntryId,
        // or Source_Pricebook_Ref__c - trust the user input.
    }

    private static void stampTieredLine(
        QuoteLineItem qli,
        Product2 p,
        PricebookTierService.ProductTierMap tiers
    ) {
        if (tiers == null || tiers.byTier.isEmpty()) {
            qli.addError(
                'No active tier PricebookEntry found for product "' + p.Id +
                '". A Price list5 entry is required before adding this product to a quote.'
            );
            return;
        }

        PricebookEntry tier5 = tiers.tier(PricebookTierService.TIER5);
        if (tier5 == null) {
            qli.addError(
                'Price list5 entry is required for this product. ' +
                'Create a Price list5 PricebookEntry before adding to a quote.'
            );
            return;
        }

        Decimal unitPrice = qli.UnitPrice == null ? 0 : qli.UnitPrice;
        Decimal standardPrice = tier5.UnitPrice == null ? 0 : tier5.UnitPrice;

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

        PricebookTierService.TierResolution r =
            PricebookTierService.resolveTier(tiers, discountedUnit);

        // Track the resolved tier on the line. Salesforce forbids pointing
        // QLI.PricebookEntryId at a pricebook other than the Quote's
        // Pricebook2 (the Standard pricebook) - use Source_Pricebook_Ref__c
        // as the resolved-tier audit field instead.
        if (r.entry != null) {
            qli.Source_Pricebook_Ref__c = r.entry.Pricebook2Id;
        }

        // Source tax from Product2, not PricebookEntry.
        qli.Tax__c = p.Tax__c;

        qli.Price_Status__c = PricebookTierService.computePriceStatus(
            unitPrice, discount, standardPrice, r.underFloor
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