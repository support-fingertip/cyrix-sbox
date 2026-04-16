// OrderTrigger dispatches after-update events to OrderTriggerHandler.
// Currently handles the Cancelled status transition to send an in-app
// Custom Notification (Order_Cancellation_Notification) to the Owner.
trigger OrderTrigger on Order (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        OrderTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}