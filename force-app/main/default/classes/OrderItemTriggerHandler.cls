/**
 * Mirrors Quote approval logic on Order:
 *   - evaluateDiscountThresholds: compares each OrderItem.Discount__c
 *     against the Product's Manager / VP / CEO discount limits and sets
 *     Price_Status__c = 'Approval Required' or 'Not Required'.
 *   - rollUpPriceStatusToOrder: if ANY OrderItem on an Order is flagged
 *     'Approval Required', the parent Order.Price_Status__c flips to
 *     'Approval Required'. Else if ALL are 'Approved' -> 'Approved'.
 *     Else 'Not Required'.
 *
 * Mirrors QuoteApprovalController.evaluateDiscountThresholds (the same
 * Manager_Discount_Up_to__c / VP_Sales_Discount_Up_to__c /
 * CEO_Sales_Discount_Up_to__c fields on Product2 are used).
 */
public with sharing class OrderItemTriggerHandler {

    private static final String STATUS_APPROVAL_REQUIRED = 'Approval Required';
    private static final String STATUS_NOT_REQUIRED      = 'Not Required';
    private static final String STATUS_APPROVED          = 'Approved';
    private static final String ORDER_STATUS_DRAFT       = 'Draft';

    /** BEFORE insert/update. Mutates records in-place. */
    public static void evaluateDiscountThresholds(List<OrderItem> items) {
        if (items == null || items.isEmpty()) return;

        Set<Id> productIds = new Set<Id>();
        for (OrderItem oi : items) {
            if (oi.Product2Id != null && oi.Discount__c != null && oi.Discount__c > 0) {
                productIds.add(oi.Product2Id);
            }
        }
        if (productIds.isEmpty()) return;

        Map<Id, Product2> prodMap = new Map<Id, Product2>([
            SELECT Id,
                   Manager_Discount_Up_to__c,
                   VP_Sales_Discount_Up_to__c,
                   CEO_Sales_Discount_Up_to__c
            FROM Product2
            WHERE Id IN :productIds
        ]);

        for (OrderItem oi : items) {
            if (oi.Discount__c == null || oi.Discount__c == 0) continue;

            Product2 p = prodMap.get(oi.Product2Id);
            if (p == null) continue;

            Decimal discount    = oi.Discount__c / 100;
            Decimal managerLim  = p.Manager_Discount_Up_to__c   != null ? p.Manager_Discount_Up_to__c   / 100 : 0;
            Decimal vpLim       = p.VP_Sales_Discount_Up_to__c  != null ? p.VP_Sales_Discount_Up_to__c  / 100 : 0;
            Decimal ceoLim      = p.CEO_Sales_Discount_Up_to__c != null ? p.CEO_Sales_Discount_Up_to__c / 100 : 0;

            if (discount > ceoLim && ceoLim > 0) {
                oi.Price_Status__c = STATUS_APPROVAL_REQUIRED;
            } else if (discount > vpLim && vpLim > 0) {
                oi.Price_Status__c = STATUS_APPROVAL_REQUIRED;
            } else if (discount > managerLim && managerLim > 0) {
                oi.Price_Status__c = STATUS_APPROVAL_REQUIRED;
            } else {
                oi.Price_Status__c = STATUS_NOT_REQUIRED;
            }
        }
    }

    /** AFTER insert/update. Updates parent Order.Price_Status__c. */
    public static void rollUpPriceStatusToOrder(List<OrderItem> newList, Map<Id, OrderItem> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        // Only Orders whose child Price_Status__c or OrderId just changed.
        Set<Id> affectedOrderIds = new Set<Id>();
        for (OrderItem oi : newList) {
            OrderItem prev = (oldMap != null) ? oldMap.get(oi.Id) : null;
            Boolean changed = (prev == null)
                || prev.Price_Status__c != oi.Price_Status__c
                || prev.OrderId != oi.OrderId;
            if (changed && oi.OrderId != null) affectedOrderIds.add(oi.OrderId);
        }
        if (affectedOrderIds.isEmpty()) return;

        // Load every sibling OrderItem for each affected Order.
        Map<Id, List<OrderItem>> itemsByOrder = new Map<Id, List<OrderItem>>();
        for (OrderItem oi : [
            SELECT Id, OrderId, Price_Status__c
            FROM OrderItem
            WHERE OrderId IN :affectedOrderIds
        ]) {
            if (!itemsByOrder.containsKey(oi.OrderId)) {
                itemsByOrder.put(oi.OrderId, new List<OrderItem>());
            }
            itemsByOrder.get(oi.OrderId).add(oi);
        }

        // Compute rollup and compare against current Order.Price_Status__c
        // so we only update when something actually changes.
        Map<Id, Order> currentOrders = new Map<Id, Order>([
            SELECT Id, Price_Status__c FROM Order WHERE Id IN :affectedOrderIds
        ]);

        List<Order> toUpdate = new List<Order>();
        for (Id oid : affectedOrderIds) {
            String rolled = computeRollup(itemsByOrder.get(oid));
            Order curr = currentOrders.get(oid);
            if (curr == null) continue;
            if (curr.Price_Status__c != rolled) {
                toUpdate.add(new Order(Id = oid, Price_Status__c = rolled));
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
        if (items == null || items.isEmpty()) return ORDER_STATUS_DRAFT;
        Boolean anyApprovalRequired = false;
        Boolean allApproved = true;
        for (OrderItem oi : items) {
            if (oi.Price_Status__c == STATUS_APPROVAL_REQUIRED) anyApprovalRequired = true;
            if (oi.Price_Status__c != STATUS_APPROVED) allApproved = false;
        }
        if (anyApprovalRequired) return STATUS_APPROVAL_REQUIRED;
        if (allApproved) return STATUS_APPROVED;
        return ORDER_STATUS_DRAFT;
    }
}