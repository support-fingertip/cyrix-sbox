/**
 * Mirrors QuoteLineItemTriggerHandler on the Order schema. Stamps
 * OrderItem.Price_Status__c, Source_Pricebook_Ref__c, and re-fetches
 * UnitPrice when the discount-vs-Discount__c algorithm in
 * PricebookTierService.evaluate maps the line to a different tier.
 *
 * Service items short-circuit to Price_Status = 'Not Required' and
 * leave the line's pricebook / UnitPrice untouched. Non-service items
 * use the running user's profile to resolve the ceiling tier and walk
 * the escalation ladder when the entered discount overshoots.
 *
 * Order.Price_Status__c rolls up from the children: any child Approval
 * Required -> parent Approval Required; all children Approved -> parent
 * Approved; otherwise Not Required.
 */
public with sharing class OrderItemTriggerHandler {

    private static final String STATUS_APPROVAL_REQUIRED = 'Approval Required';
    private static final String STATUS_NOT_REQUIRED      = 'Not Required';
    private static final String STATUS_APPROVED          = 'Approved';
    // Order lifecycle (Order.Status) values referenced by the auto-
    // transition when Price_Status__c flips to Approval Required.
    private static final String STATUS_NEEDS_REVIEW      = 'Needs Review';
    private static final Set<String> ORDER_TERMINAL_STATUSES = new Set<String>{
        'Activated', 'Cancelled', 'Closed'
    };

    /**
     * BEFORE insert/update. Mutates records in place.
     */
    public static void evaluateDiscountThresholds(List<OrderItem> items) {
        if (items == null || items.isEmpty()) return;

        Set<Id> productIds = new Set<Id>();
        Set<Id> orderIds = new Set<Id>();
        for (OrderItem oi : items) {
            if (oi.Product2Id != null) productIds.add(oi.Product2Id);
            if (oi.OrderId != null) orderIds.add(oi.OrderId);
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

        // Source-quote QLI discounts keyed by parent QuoteId + Product2Id.
        // If the OrderItem's discount matches the QLI it was sourced from,
        // we don't escalate — the discount has already been approved on
        // the quote and re-approving on the order is noise. Only items
        // whose discount has been changed (or that have no matching QLI,
        // i.e. brand-new lines added directly on the order) go through
        // the cap evaluator.
        Map<Id, Id> orderToQuote = new Map<Id, Id>();
        if (!orderIds.isEmpty()) {
            for (Order o : [SELECT Id, QuoteId FROM Order WHERE Id IN :orderIds]) {
                if (o.QuoteId != null) orderToQuote.put(o.Id, o.QuoteId);
            }
        }
        Map<String, Decimal> quoteLineDiscountByKey = new Map<String, Decimal>();
        if (!orderToQuote.isEmpty()) {
            Set<Id> quoteIds = new Set<Id>(orderToQuote.values());
            for (QuoteLineItem qli : [
                SELECT QuoteId, Product2Id, Discount
                FROM QuoteLineItem
                WHERE QuoteId IN :quoteIds AND Product2Id IN :productIds
            ]) {
                quoteLineDiscountByKey.put(qli.QuoteId + '|' + qli.Product2Id, qli.Discount);
            }
        }

        for (OrderItem oi : items) {
            Product2 p = prodMap.get(oi.Product2Id);
            if (p == null) continue;
            Boolean isService = (p.Service_Item__c == 'Yes');

            PricebookTierService.Evaluation ev = PricebookTierService.evaluate(
                tierMaps.get(p.Id),
                oi.Discount__c,
                isService,
                profileName
            );

            // Default to whatever the evaluator decided.
            oi.Price_Status__c = ev.status;

            // If we can match this line back to its source QuoteLineItem
            // and the discount hasn't changed from the quote, force the
            // status to Not Required regardless of the cap. New lines
            // (no matching QLI) and edited lines (discount drifted) still
            // honour the evaluator's verdict.
            Id parentQuoteId = orderToQuote.get(oi.OrderId);
            if (parentQuoteId != null && oi.Product2Id != null) {
                Decimal qliDisc = quoteLineDiscountByKey.get(parentQuoteId + '|' + oi.Product2Id);
                Decimal orderDisc = oi.Discount__c == null ? 0 : oi.Discount__c;
                Decimal sourceDisc = qliDisc == null ? 0 : qliDisc;
                if (qliDisc != null && orderDisc == sourceDisc) {
                    oi.Price_Status__c = STATUS_NOT_REQUIRED;
                }
            }

            if (isService) {
                // Service items: don't touch the line's pricebook,
                // UnitPrice, or Tax. Trust the rep input.
                continue;
            }

            oi.Tax__c = p.Tax__c;

            // Source_Pricebook_Ref__c reflects the mapped tier; UnitPrice
            // is intentionally left at the PL5 list price the rep saw on
            // screen — escalation only affects the approval path, not the
            // displayed Sales Price.
            if (ev.mappedPricebookId != null) {
                oi.Source_Pricebook_Ref__c = ev.mappedPricebookId;
            }

            // Tax_Amount = (Qty * UnitPrice * (1 - Disc/100)) * (Tax%/100).
            Decimal qty      = oi.Quantity   == null ? 0 : oi.Quantity;
            Decimal unit     = oi.UnitPrice  == null ? 0 : oi.UnitPrice;
            Decimal disc     = oi.Discount__c == null ? 0 : oi.Discount__c;
            Decimal taxRate  = p.Tax__c != null ? p.Tax__c : 0;
            Decimal afterDisc = (qty * unit) * (1 - (disc / 100));
            oi.Tax_Amount__c = afterDisc * (taxRate / 100);
        }
    }

    /** AFTER insert/update. Updates parent Order.Price_Status__c. */
    public static void rollUpPriceStatusToOrder(List<OrderItem> newList, Map<Id, OrderItem> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        Set<Id> affectedOrderIds = new Set<Id>();
        for (OrderItem oi : newList) {
            OrderItem prev = (oldMap != null) ? oldMap.get(oi.Id) : null;
            Boolean changed = (prev == null)
                || prev.Price_Status__c != oi.Price_Status__c
                || prev.OrderId != oi.OrderId;
            if (changed && oi.OrderId != null) affectedOrderIds.add(oi.OrderId);
        }
        rollupOrders(affectedOrderIds);
    }

    /**
     * Public entry point so Apex callers (e.g. OrderBuilderController's
     * saveOrderItems / updateOrderItems) can force a rollup without
     * depending on the trigger fire order.
     */
    public static void rollupOrders(Set<Id> orderIds) {
        if (orderIds == null || orderIds.isEmpty()) return;

        Map<Id, List<OrderItem>> itemsByOrder = new Map<Id, List<OrderItem>>();
        for (OrderItem oi : [
            SELECT Id, OrderId, Price_Status__c
            FROM OrderItem
            WHERE OrderId IN :orderIds
        ]) {
            if (!itemsByOrder.containsKey(oi.OrderId)) {
                itemsByOrder.put(oi.OrderId, new List<OrderItem>());
            }
            itemsByOrder.get(oi.OrderId).add(oi);
        }

        Map<Id, Order> currentOrders = new Map<Id, Order>([
            SELECT Id, Price_Status__c, Status FROM Order WHERE Id IN :orderIds
        ]);

        List<Order> toUpdate = new List<Order>();
        for (Id oid : orderIds) {
            String rolled = computeRollup(itemsByOrder.get(oid));
            Order curr = currentOrders.get(oid);
            if (curr == null) continue;
            if (curr.Price_Status__c != rolled) {
                Order moved = new Order(Id = oid, Price_Status__c = rolled);
                // When price escalates to Approval Required, also push
                // the order's lifecycle status to Needs Review so the
                // approver sees a single, unambiguous "this is awaiting
                // me" state. Skip orders already at a terminal lifecycle
                // (Activated / Cancelled) so we don't drag completed
                // work backwards.
                if (rolled == STATUS_APPROVAL_REQUIRED
                        && curr.Status != STATUS_NEEDS_REVIEW
                        && !ORDER_TERMINAL_STATUSES.contains(curr.Status)) {
                    moved.Status = STATUS_NEEDS_REVIEW;
                }
                toUpdate.add(moved);
            }
        }

        if (!toUpdate.isEmpty()) {
            try {
                update toUpdate;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'OrderItemTriggerHandler rollup update failed: ' + e.getMessage());
            }
        }
    }

    @TestVisible
    private static String computeRollup(List<OrderItem> items) {
        if (items == null || items.isEmpty()) return STATUS_NOT_REQUIRED;
        Boolean anyApprovalRequired = false;
        Boolean allApproved = true;
        for (OrderItem oi : items) {
            if (oi.Price_Status__c == STATUS_APPROVAL_REQUIRED) anyApprovalRequired = true;
            if (oi.Price_Status__c != STATUS_APPROVED) allApproved = false;
        }
        if (anyApprovalRequired) return STATUS_APPROVAL_REQUIRED;
        if (allApproved) return STATUS_APPROVED;
        return STATUS_NOT_REQUIRED;
    }
}