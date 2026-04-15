// OrderTrigger dispatches events to OrderTriggerHandler.
// Currently handles:
//   - before update: block Cancelled transition if an Invoice exists.
//   - after update:  send Custom Notification on Cancelled transition.
trigger OrderTrigger on Order (before update, after update) {
    if (Trigger.isBefore && Trigger.isUpdate) {
        OrderTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        OrderTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}
