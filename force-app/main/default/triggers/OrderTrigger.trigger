// OrderTrigger dispatches after-update events to OrderTriggerHandler.
// Currently handles the 'Cancelled' status transition to send an in-app
// Custom Notification to the Order Owner.
trigger OrderTrigger on Order (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        OrderTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}
