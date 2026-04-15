/**
 * Handles business logic fired by OrderTrigger.
 *
 * Currently responsible for sending an in-app Custom Notification to the
 * Order Owner whenever an Order's Status transitions to 'Cancelled'.
 */
public with sharing class OrderTriggerHandler {

    private static final String NOTIF_DEV_NAME = 'Order_Cancellation_Notification';
    private static final String CANCELLED_STATUS = 'Cancelled';

    public static void handleAfterUpdate(List<Order> newList, Map<Id, Order> oldMap) {
        if (newList == null || oldMap == null) return;

        // Collect only the Orders whose Status just transitioned to 'Cancelled'.
        Set<Id> cancelledIds = new Set<Id>();
        for (Order o : newList) {
            Order prev = oldMap.get(o.Id);
            if (prev == null) continue;
            if (o.Status == CANCELLED_STATUS && prev.Status != CANCELLED_STATUS) {
                cancelledIds.add(o.Id);
            }
        }
        if (cancelledIds.isEmpty()) return;

        sendCancellationNotifications(cancelledIds);
    }

    private static void sendCancellationNotifications(Set<Id> orderIds) {
        // Re-query to pull Account.Name + cancellation reason fresh (trigger.new
        // fields may not include related parent fields reliably).
        List<Order> orders = [
            SELECT Id, OrderNumber, OwnerId, Cancellation_Reason__c,
                   Account.Name
            FROM Order
            WHERE Id IN :orderIds
        ];
        if (orders.isEmpty()) return;

        List<CustomNotificationType> types = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = :NOTIF_DEV_NAME
            LIMIT 1
        ];
        if (types.isEmpty()) {
            System.debug(LoggingLevel.WARN,
                'OrderTriggerHandler: Custom Notification Type "'
                + NOTIF_DEV_NAME + '" not found. Skipping notification.');
            return;
        }
        Id notifTypeId = types[0].Id;

        for (Order o : orders) {
            try {
                Messaging.CustomNotification n = new Messaging.CustomNotification();
                n.setTitle('Order Cancelled');
                n.setBody(buildBody(o));
                n.setNotificationTypeId(notifTypeId);
                n.setTargetId(o.Id);
                n.send(new Set<String>{ String.valueOf(o.OwnerId) });
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'OrderTriggerHandler: notification failed for ' + o.Id
                    + ': ' + e.getMessage());
            }
        }
    }

    @TestVisible
    private static String buildBody(Order o) {
        String accountPart = (o.Account != null && String.isNotBlank(o.Account.Name))
            ? ' for ' + o.Account.Name
            : '';
        String reasonPart = String.isNotBlank(o.Cancellation_Reason__c)
            ? ' Reason: ' + o.Cancellation_Reason__c
            : '';
        return 'Order ' + o.OrderNumber + accountPart + ' has been cancelled.' + reasonPart;
    }
}
