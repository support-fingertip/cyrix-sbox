// OrderItemTrigger mirrors the Quote approval pattern onto Order:
//   Before insert/update: compare Discount__c vs Product2's manager/VP/CEO
//                          discount limits; set Price_Status__c accordingly.
//   After insert/update:  roll the child Price_Status__c up to the parent
//                          Order.Price_Status__c ('Approval Required' if any
//                          child needs approval).
trigger OrderItemTrigger on OrderItem (before insert, before update, after insert, after update) {
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        OrderItemTriggerHandler.evaluateDiscountThresholds(Trigger.new);
    }
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        OrderItemTriggerHandler.rollUpPriceStatusToOrder(Trigger.new, Trigger.oldMap);
    }
}