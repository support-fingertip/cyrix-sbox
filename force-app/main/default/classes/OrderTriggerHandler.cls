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
    private static final String APPROVAL_NOTIF_DEV_NAME = 'Order_Approval_Notification';
    private static final String CANCELLED_STATUS = 'Cancelled';
    private static final String APPROVAL_REQUIRED = 'Approval Required';
    private static final String PRICE_APPROVED = 'Approved';
    private static final String APPROVAL_STATUS_APPROVED = 'Approved';

    /**
     * Auto-populates L1/L2/L3 Approver fields on the Order based on the
     * Owner's Manager hierarchy.
     *   L1 = Owner.Manager                 (e.g. ASM)
     *   L2 = Owner.Manager.Manager         (e.g. TSM)
     *   L3 = Owner.Manager.Manager.Manager (e.g. Order Acceptance / Finance)
     *
     * Only fills fields that are currently null, so manual overrides and
     * values copied from the source Quote are preserved.
     */
    public static void populateApproversFromHierarchy(List<Order> orders) {
        if (orders == null || orders.isEmpty()) return;
  list< General_Settings__c> settingsList =[select Id, Order_Acceptance_Approver__c from General_Settings__c limit 1]; 
        Set<Id> ownerIds = new Set<Id>();
        for (Order o : orders) {
            if (o.OwnerId != null) ownerIds.add(o.OwnerId);
        }
        if (ownerIds.isEmpty()) return;

        Map<Id, User> userMap = new Map<Id, User>([
            SELECT Id, ManagerId,
                   Manager.ManagerId,
                   Manager.Manager.ManagerId
            FROM User
            WHERE Id IN :ownerIds
        ]);

        for (Order o : orders) {
            User owner = userMap.get(o.OwnerId);
            if (owner == null) continue;

            if (o.L1_Approver__c == null && owner.ManagerId != null) {
                o.L1_Approver__c = owner.ManagerId;
            }
            if (o.L2_Approver__c == null && owner.Manager != null
                && owner.Manager.ManagerId != null) {
                o.L2_Approver__c = owner.Manager.ManagerId;
            }
            if (o.L3_Approver__c == null &&  !settingsList.isEmpty()) {
                o.L3_Approver__c = settingsList[0].Order_Acceptance_Approver__c;
            }
        }
    }

    /**
     * Blocks an Order from being cancelled when at least one Invoice
     * already references it via the Invoice.Order__c lookup.
     *
     * Business rule: "Order Cancellation / Allowed only before Invoice
     * Creation." Once an Invoice exists for the Order, the Status may
     * not transition to 'Cancelled'.
     */
    public static void handleBeforeUpdate(List<Order> newList, Map<Id, Order> oldMap) {
        if (newList == null || oldMap == null) return;

        // Collect Orders attempting to transition into 'Cancelled'.
        Set<Id> attemptingCancelIds = new Set<Id>();
        Map<Id, Order> orderById = new Map<Id, Order>();
        for (Order o : newList) {
            Order prev = oldMap.get(o.Id);
            if (prev == null) continue;
            if (o.Status == CANCELLED_STATUS && prev.Status != CANCELLED_STATUS) {
                attemptingCancelIds.add(o.Id);
                orderById.put(o.Id, o);
            }
        }
        if (attemptingCancelIds.isEmpty()) return;

        // Query Invoices linked to these Orders via the custom lookup.
        Set<Id> blockedOrderIds = new Set<Id>();
        for (Invoice inv : [
            SELECT Id, Order__c
            FROM Invoice
            WHERE Order__c IN :attemptingCancelIds
        ]) {
            if (inv.Order__c != null) blockedOrderIds.add(inv.Order__c);
        }

        for (Id blockedId : blockedOrderIds) {
            Order o = orderById.get(blockedId);
            if (o != null) {
                o.addError(
                    'This Order cannot be cancelled because one or more ' +
                    'Invoices have already been created against it. ' +
                    'Cancel or void the Invoice(s) first.'
                );
            }
        }
    }

    public static void handleAfterUpdate(List<Order> newList, Map<Id, Order> oldMap) {
        if (newList == null || oldMap == null) return;

        Set<Id> cancelledIds = new Set<Id>();
        Set<Id> approvedIds = new Set<Id>();

        for (Order o : newList) {
            Order prev = oldMap.get(o.Id);
            if (prev == null) continue;

            if (o.Status == CANCELLED_STATUS && prev.Status != CANCELLED_STATUS) {
                cancelledIds.add(o.Id);
            }

            // Mirror Quote: notify on EITHER Approval_Status__c or
            // Price_Status__c flipping to 'Approved'. Approval_Status__c is
            // the reliable signal from the standard Order_Approval process,
            // and Price_Status__c is updated by the line-item rollup path.
            Boolean approvalFlipped = (o.Approval_Status__c == APPROVAL_STATUS_APPROVED
                                       && prev.Approval_Status__c != APPROVAL_STATUS_APPROVED);
            Boolean priceFlipped    = (o.Price_Status__c == PRICE_APPROVED
                                       && prev.Price_Status__c != PRICE_APPROVED);
            if (approvalFlipped || priceFlipped) {
                approvedIds.add(o.Id);
            }
        }

        if (!cancelledIds.isEmpty()) {
            sendCancellationNotifications(cancelledIds);
        }

        if (!approvedIds.isEmpty()) {
            sendApprovalNotifications(approvedIds);
        }
    }

    private static void sendApprovalNotifications(Set<Id> orderIds) {
        List<Order> orders = [
            SELECT Id, OrderNumber, OwnerId, Account.Name
            FROM Order
            WHERE Id IN :orderIds
        ];
        if (orders.isEmpty()) return;

        Set<Id> ownerIds = new Set<Id>();
        for (Order o : orders) if (o.OwnerId != null) ownerIds.add(o.OwnerId);
        Map<Id, String> emailByOwnerId = new Map<Id, String>();
        for (User u : [SELECT Id, Email FROM User WHERE Id IN :ownerIds]) {
            if (String.isNotBlank(u.Email)) emailByOwnerId.put(u.Id, u.Email);
        }

        sendApprovalBellNotifications(orders);
        sendApprovalEmails(orders, emailByOwnerId);
    }

    private static void sendApprovalBellNotifications(List<Order> orders) {
        // Order approvals use a dedicated Order_Approval_Notification type so
        // they stay separate from cancellation notifications (which keep
        // using Order_Cancellation_Notification).
        List<CustomNotificationType> types = [
            SELECT Id FROM CustomNotificationType
            WHERE DeveloperName = :APPROVAL_NOTIF_DEV_NAME LIMIT 1
        ];
        if (types.isEmpty()) return;
        Id notifTypeId = types[0].Id;

        // Whoever clicked Approve in the standard process is the running
        // user when the workflow field updates re-fire this trigger, so
        // UserInfo.getName() identifies the actual final approver.
        String approverName = UserInfo.getName();

        for (Order o : orders) {
            try {
                String acctName = (o.Account != null && String.isNotBlank(o.Account.Name))
                    ? ' for ' + o.Account.Name : '';
                Messaging.CustomNotification n = new Messaging.CustomNotification();
                n.setTitle('Order Approved');
                n.setBody('Order ' + o.OrderNumber + acctName +
                          ' has been approved by ' + approverName + '.');
                n.setNotificationTypeId(notifTypeId);
                n.setTargetId(o.Id);
                n.send(new Set<String>{ String.valueOf(o.OwnerId) });
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'OrderTriggerHandler: approval bell failed for ' + o.Id + ': ' + e.getMessage());
            }
        }
    }

    private static void sendApprovalEmails(List<Order> orders, Map<Id, String> emailByOwnerId) {
        if (emailByOwnerId == null || emailByOwnerId.isEmpty()) return;

        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        List<Task> activityTasks = new List<Task>();

        for (Order o : orders) {
            String toEmail = emailByOwnerId.get(o.OwnerId);
            if (String.isBlank(toEmail)) continue;

            String acctName = (o.Account != null && String.isNotBlank(o.Account.Name))
                ? o.Account.Name : 'the customer';

            String subject = 'Order ' + o.OrderNumber + ' has been approved';
            String body =
                'Hello,\n\n' +
                'This is to inform you that Order ' + o.OrderNumber +
                ' for ' + acctName + ' has been approved on ' +
                Date.today().format() + '.\n\n' +
                'You can review the record here: ' +
                URL.getOrgDomainUrl().toExternalForm() + '/' + o.Id + '\n\n' +
                'Regards,\nCyrix Order Management';

            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(new List<String>{ toEmail });
            msg.setSubject(subject);
            msg.setPlainTextBody(body);
            msg.setSaveAsActivity(false);
            messages.add(msg);

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
                    'OrderTriggerHandler: approval email failed: ' + e.getMessage());
            }
        }

        if (!activityTasks.isEmpty()) {
            try {
                insert activityTasks;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'OrderTriggerHandler: approval activity task failed: ' + e.getMessage());
            }
        }
    }

    private static void sendCancellationNotifications(Set<Id> orderIds) {
        // Re-query to pull Account.Name + cancellation reason + Opportunity
        // email (source of truth for external cancellation emails, including
        // ERP-pushed status updates). trigger.new fields may not include
        // related parent fields reliably after DML.
        List<Order> orders = [
            SELECT Id, OrderNumber, OwnerId, Cancellation_Reason__c,
                   Account.Name,
                   OpportunityId, Opportunity.Email__c, Opportunity.Secondary_Email__c
            FROM Order
            WHERE Id IN :orderIds
        ];
        if (orders.isEmpty()) return;

        sendInAppNotifications(orders);
        sendCancellationEmails(orders);
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
     * Sends a cancellation email to the Opportunity's email address (with
     * the secondary email CC'd when present) AND logs a Task record on the
     * Order so the email shows up in the Activity panel. The Opportunity
     * email is the source of truth: whether the cancellation came from a
     * user marking the order cancelled in the UI or from the ERP pushing
     * the status via the integration endpoint, the notification goes to
     * the same address. Wrapped in try/catch so an email failure never
     * blocks the save or the bell notification that ran before it.
     */
    private static void sendCancellationEmails(List<Order> orders) {
        if (orders == null || orders.isEmpty()) return;

        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        List<Task> activityTasks = new List<Task>();

        for (Order o : orders) {
            String toEmail = (o.Opportunity != null)
                ? o.Opportunity.Email__c : null;
            String ccEmail = (o.Opportunity != null)
                ? o.Opportunity.Secondary_Email__c : null;
            if (String.isBlank(toEmail)) {
                System.debug(LoggingLevel.WARN,
                    'OrderTriggerHandler: Opportunity email missing for Order '
                    + o.Id + '. Skipping cancellation email.');
                continue;
            }

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
            if (String.isNotBlank(ccEmail) && ccEmail != toEmail) {
                msg.setCcAddresses(new List<String>{ ccEmail });
            }
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
            String recipients = 'To: ' + toEmail;
            if (String.isNotBlank(ccEmail) && ccEmail != toEmail) {
                recipients += '\nCc: ' + ccEmail;
            }
            t.Description  = recipients + '\n\n' + body;
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