// OrderTrigger dispatches update events to OrderTriggerHandler.
//   before update : blocks cancellation when an Invoice already exists
//                   (Invoice.Order__c lookup).
//   after  update : sends in-app Custom Notification + email + Activity Task
//                   on transition to 'Cancelled'.
trigger OrderTrigger on Order (before update, after update) {
    if (Trigger.isBefore && Trigger.isUpdate) {
        OrderTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        OrderTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}