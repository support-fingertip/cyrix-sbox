/**
 * Handles business logic fired by OrderTrigger.
 *
 * Currently responsible for sending an in-app Custom Notification to
 * the Order Owner whenever an Order's Status transitions to 'Cancelled'.
 *
 * The Custom Notification Type with DeveloperName
 * Order_Cancellation_Notification must exist in the org (managed via
 * Setup > Notification Builder > Custom Notifications).
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
        // Re-query to pull Account.Name + cancellation reason + owner email
        // (trigger.new fields may not include related parent fields reliably).
        List<Order> orders = [
            SELECT Id, OrderNumber, OwnerId, Cancellation_Reason__c,
                   Account.Name
            FROM Order
            WHERE Id IN :orderIds
        ];
        if (orders.isEmpty()) return;

        // Build Id -> Email map for each Owner that is a User (Queues don't
        // have User records and are skipped for email).
        Set<Id> ownerIds = new Set<Id>();
        for (Order o : orders) if (o.OwnerId != null) ownerIds.add(o.OwnerId);
        Map<Id, String> emailByOwnerId = new Map<Id, String>();
        for (User u : [SELECT Id, Email FROM User WHERE Id IN :ownerIds]) {
            if (String.isNotBlank(u.Email)) emailByOwnerId.put(u.Id, u.Email);
        }

        sendInAppNotifications(orders);
        sendCancellationEmails(orders, emailByOwnerId);
    }

    private static void sendInAppNotifications(List<Order> orders) {
        List<CustomNotificationType> types = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = :NOTIF_DEV_NAME
            LIMIT 1
        ];
        if (types.isEmpty()) {
            System.debug(LoggingLevel.WARN,
                'OrderTriggerHandler: Custom Notification Type "'
                + NOTIF_DEV_NAME + '" not found. Skipping bell notification.');
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
                    'OrderTriggerHandler: bell notification failed for ' + o.Id
                    + ': ' + e.getMessage());
            }
        }
    }

    /**
     * Sends a cancellation email to the Order Owner's email address AND
     * logs a Task record on the Order so the email appears in the
     * Activity panel. Wrapped in try/catch so an email failure never
     * blocks the save or the bell notification that ran before it.
     */
    private static void sendCancellationEmails(List<Order> orders, Map<Id, String> emailByOwnerId) {
        if (emailByOwnerId == null || emailByOwnerId.isEmpty()) return;

        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        List<Task> activityTasks = new List<Task>();

        for (Order o : orders) {
            String toEmail = emailByOwnerId.get(o.OwnerId);
            if (String.isBlank(toEmail)) continue;

            String acctName = (o.Account != null && String.isNotBlank(o.Account.Name))
                ? o.Account.Name : 'the customer';
            String reasonPart = String.isNotBlank(o.Cancellation_Reason__c)
                ? 'Reason: ' + o.Cancellation_Reason__c + '\n\n'
                : '';

            String subject = 'Order ' + o.OrderNumber + ' has been cancelled';
            String body =
                'Hello,\n\n' +
                'This is to inform you that Order ' + o.OrderNumber +
                ' for ' + acctName + ' has been cancelled on ' +
                Date.today().format() + '.\n\n' +
                reasonPart +
                'You can review the record here: ' +
                URL.getOrgDomainUrl().toExternalForm() + '/' + o.Id + '\n\n' +
                'Regards,\nCyrix Order Management';

            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(new List<String>{ toEmail });
            msg.setSubject(subject);
            msg.setPlainTextBody(body);
            msg.setSaveAsActivity(false);
            messages.add(msg);

            // Mirror the email as a Task so it appears under the Order's
            // Activity panel (saveAsActivity on the email itself doesn't
            // always attach to the Order when we're not using a template).
            Task t = new Task();
            t.WhatId       = o.Id;
            t.Subject      = 'Email: ' + subject;
            t.Description  = 'To: ' + toEmail + '\n\n' + body;
            t.Status       = 'Completed';
            t.Priority     = 'Normal';
            t.ActivityDate = Date.today();
            t.Type         = 'Email';
            activityTasks.add(t);
        }

        if (!messages.isEmpty()) {
            try {
                Messaging.sendEmail(messages, false);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'OrderTriggerHandler: cancellation email batch failed: ' + e.getMessage());
            }
        }

        if (!activityTasks.isEmpty()) {
            try {
                insert activityTasks;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'OrderTriggerHandler: activity task insert failed: ' + e.getMessage());
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