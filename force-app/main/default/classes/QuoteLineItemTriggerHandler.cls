/**
 * Authoritative server-side stamp for QuoteLineItem using the
 * discount-vs-Discount__c algorithm in PricebookTierService.evaluate.
 *
 * For service items (Product2.Service_Item__c = 'Yes'):
 *   - Tier resolution is skipped.
 *   - Tax__c, UnitPrice, and the existing pricebook reference are left
 *     alone (trust the rep input).
 *   - Price_Status__c = 'Not Required'.
 *
 * For non-service items:
 *   - The evaluator is fed the entered Discount and the running user's
 *     profile name (which determines the ceiling tier).
 *   - When the result asks for a (re)map, Source_Pricebook_Ref__c is
 *     pointed at the resolved tier's Pricebook2, and UnitPrice is
 *     re-fetched from that tier's PricebookEntry so totals reflect the
 *     new tier.
 *   - Price_Status__c is stamped from the evaluation result.
 *   - Tax__c is sourced from Product2.Tax__c.
 *   - Tax_Amount__c is precomputed from the (new) UnitPrice * (1 - disc/100).
 *
 * After any change, Quote.Price_Status__c is rolled up: any line in
 * Approval Required promotes the Quote, otherwise Not Required. An
 * already-Approved Quote is never regressed by this handler.
 */
public with sharing class QuoteLineItemTriggerHandler {

    // Set by other handlers (e.g. quoteTriggerHandler.snapshotQuotesOnRevision)
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
        Map<Id, PricebookTierService.ProductTiers> tierMaps =
            PricebookTierService.loadTiers(nonServiceIds);

        String profileName = PricebookTierService.runningUserProfileName();

        for (QuoteLineItem qli : newList) {
            Product2 p = prodMap.get(qli.Product2Id);
            if (p == null) continue;
            Boolean isService = (p.Service_Item__c == 'Yes');

            PricebookTierService.Evaluation ev = PricebookTierService.evaluate(
                tierMaps.get(p.Id),
                qli.Discount,
                isService,
                profileName
            );

            qli.Price_Status__c = ev.status;

            if (isService) {
                // Don't touch the line's pricebook, UnitPrice, Tax, or
                // Tax_Amount on service rows - the rep enters them.
                continue;
            }

            // Tax always comes from Product2 on non-service rows.
            qli.Tax__c = p.Tax__c;

            // Map the resolved pricebook (PL5 by default, or the tier the
            // discount escalated into). UnitPrice is intentionally left
            // alone — the rep enters the Sales Price at the PL5 list and
            // discount is the lever for going below it; re-fetching from
            // the escalated tier would silently rewrite the price the rep
            // saw on screen.
            if (ev.mappedPricebookId != null) {
                qli.Source_Pricebook_Ref__c = ev.mappedPricebookId;
            }

            // Tax_Amount = (Qty * UnitPrice * (1 - Disc/100)) * (Tax%/100).
            // Precomputed so reports / PDF templates don't need a formula.
            Decimal qty      = qli.Quantity == null ? 0 : qli.Quantity;
            Decimal unit     = qli.UnitPrice == null ? 0 : qli.UnitPrice;
            Decimal disc     = qli.Discount  == null ? 0 : qli.Discount;
            Decimal taxRate  = p.Tax__c != null ? p.Tax__c : 0;
            Decimal afterDisc = (qty * unit) * (1 - (disc / 100));
            qli.Tax_Amount__c = afterDisc * (taxRate / 100);
        }
    }

    /**
     * Roll up line-item price status to the parent Quote.
     * - Any line Approval Required -> Quote = Approval Required.
     * - Otherwise Not Required.
     * - Never regresses an already-Approved Quote.
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