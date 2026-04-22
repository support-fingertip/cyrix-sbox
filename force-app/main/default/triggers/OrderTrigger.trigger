// OrderTrigger dispatches events to OrderTriggerHandler.
//   before insert : auto-populate L1/L2/L3 Approvers from Owner's Manager chain.
//   before update : blocks cancellation when an Invoice already exists
//                   (Invoice.Order__c lookup) + L1/L2/L3 auto-populate.
//   after  update : sends in-app Custom Notification + email + Activity Task
//                   on transition to 'Cancelled' or on approval.
trigger OrderTrigger on Order (before insert, before update, after update) {
    if (Trigger.isBefore && Trigger.isInsert) {
        OrderTriggerHandler.populateApproversFromHierarchy(Trigger.new);
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        OrderTriggerHandler.populateApproversFromHierarchy(Trigger.new);
        OrderTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        OrderTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}