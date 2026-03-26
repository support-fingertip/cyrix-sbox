public class OpportunityTriggerHandler {

    /* ────────────────────────────────────────────
       Auto-Number Generation
       BRD: Opportunity ID = unique auto-generated number
       Format: OPP-00001, OPP-00002, etc.
    ──────────────────────────────────────────── */
    public static void generateAutoNumber(List<Opportunity> opps) {
        // Get the current max number
        Integer maxNum = 0;
        List<Opportunity> existing = [
            SELECT Opportunity_Auto_Number__c
            FROM Opportunity
            WHERE Opportunity_Auto_Number__c != null
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!existing.isEmpty() && existing[0].Opportunity_Auto_Number__c != null) {
            String numPart = existing[0].Opportunity_Auto_Number__c.replace('OPP-', '');
            try {
                maxNum = Integer.valueOf(numPart);
            } catch (Exception e) {
                maxNum = 0;
            }
        }

        for (Opportunity opp : opps) {
            if (opp.Opportunity_Auto_Number__c == null) {
                maxNum++;
                opp.Opportunity_Auto_Number__c = 'OPP-' + String.valueOf(maxNum).leftPad(5, '0');
            }
        }
    }

    /* ────────────────────────────────────────────
       Default Stage
       BRD: Default stage = Qualified
    ──────────────────────────────────────────── */
    public static void setDefaultStage(List<Opportunity> opps) {
        for (Opportunity opp : opps) {
            if (opp.StageName == null) {
                opp.StageName = 'Qualified';
            }
        }
    }

    /* ────────────────────────────────────────────
       Auto-set Opportunity Name
       BRD: Opportunity Name = Company Name + Requirement
       Defaults to Account Name if no manual name provided
    ──────────────────────────────────────────── */
    public static void setOpportunityName(List<Opportunity> opps) {
        Set<Id> accountIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        for (Opportunity opp : opps) {
            if (opp.AccountId != null) {
                accountIds.add(opp.AccountId);
            }
            if (opp.Product__c != null) {
                productIds.add(opp.Product__c);
            }
        }

        if (accountIds.isEmpty()) return;

        Map<Id, Account> accountMap = new Map<Id, Account>(
            [SELECT Id, Name FROM Account WHERE Id IN :accountIds]
        );

        Map<Id, Product2> productMap = new Map<Id, Product2>();
        if (!productIds.isEmpty()) {
            productMap = new Map<Id, Product2>(
                [SELECT Id, Name FROM Product2 WHERE Id IN :productIds]
            );
        }

        for (Opportunity opp : opps) {
            if (opp.AccountId != null && accountMap.containsKey(opp.AccountId)) {
                String accName = accountMap.get(opp.AccountId).Name;
                String prodName = '';
                if (opp.Product__c != null && productMap.containsKey(opp.Product__c)) {
                    prodName = productMap.get(opp.Product__c).Name;
                }
                opp.Name = accName + (String.isNotBlank(prodName) ? ' ' + prodName : '');
            }
        }
    }

    /* ────────────────────────────────────────────
       Campaign Mapping
       BRD: When Campaign__c is filled, add the
       Primary Contact Person as a CampaignMember
    ──────────────────────────────────────────── 
    public static void campaignMapping(List<Opportunity> opps) {
        List<CampaignMember> cms = new List<CampaignMember>();

        for (Opportunity opp : opps) {
            if (opp.Campaign__c != null) {
                cms.add(new CampaignMember(
                    CampaignId = opp.Campaign__c,
                    Status = 'Sent'
                ));
            }
        }

        if (!cms.isEmpty()) {
            try {
                insert cms;
            } catch (Exception ex) {
                ExceptionHandler.addLog(ex, String.valueOf(cms), 'OpportunityTriggerHandler', 'campaignMapping');
            }
        }
    }*/

    /* ────────────────────────────────────────────
       Assignment Notification
       BRD: Notification on assignment to Owner & Manager
    ──────────────────────────────────────────── */
    public static void sendAssignmentNotification(List<Opportunity> opps) {
        try {
            List<CustomNotificationType> notifTypes = [
                SELECT Id FROM CustomNotificationType
                WHERE DeveloperName = 'Opportunity_Notification'
                LIMIT 1
            ];
            if (notifTypes.isEmpty()) return;

            String notifTypeId = notifTypes[0].Id;
            String senderId = UserInfo.getUserId();

            Set<Id> ownerIds = new Set<Id>();
            for (Opportunity opp : opps) {
                if (opp.OwnerId != null) ownerIds.add(opp.OwnerId);
            }

            Map<Id, User> ownerMap = new Map<Id, User>(
                [SELECT Id, ManagerId FROM User WHERE Id IN :ownerIds]
            );

            for (Opportunity opp : opps) {
                Set<String> recipients = new Set<String>();
                recipients.add(opp.OwnerId);

                User owner = ownerMap.get(opp.OwnerId);
                if (owner != null && owner.ManagerId != null) {
                    recipients.add(owner.ManagerId);
                }

                SendEmailCustomNotification.sendNotification(
                    'Opportunity "' + opp.Name + '" has been assigned to you.',
                    'Opportunity Assigned',
                    senderId,
                    notifTypeId,
                    opp.Id,
                    recipients
                );
            }
        } catch (Exception ex) {
            ExceptionHandler.addLog(ex, String.valueOf(opps), 'OpportunityTriggerHandler', 'sendAssignmentNotification');
        }
    }

    /* ────────────────────────────────────────────
       Stage Change Notification
       BRD: Notification on stage change to Owner & Manager
    ──────────────────────────────────────────── */
    public static void sendStageChangeNotification(List<Opportunity> opps) {
        try {
            List<CustomNotificationType> notifTypes = [
                SELECT Id FROM CustomNotificationType
                WHERE DeveloperName = 'Opportunity_Notification'
                LIMIT 1
            ];
            if (notifTypes.isEmpty()) return;

            String notifTypeId = notifTypes[0].Id;
            String senderId = UserInfo.getUserId();

            Set<Id> ownerIds = new Set<Id>();
            for (Opportunity opp : opps) {
                if (opp.OwnerId != null) ownerIds.add(opp.OwnerId);
            }

            Map<Id, User> ownerMap = new Map<Id, User>(
                [SELECT Id, ManagerId FROM User WHERE Id IN :ownerIds]
            );

            for (Opportunity opp : opps) {
                Set<String> recipients = new Set<String>();
                recipients.add(opp.OwnerId);

                User owner = ownerMap.get(opp.OwnerId);
                if (owner != null && owner.ManagerId != null) {
                    recipients.add(owner.ManagerId);
                }

                SendEmailCustomNotification.sendNotification(
                    'Opportunity "' + opp.Name + '" stage changed to ' + opp.StageName,
                    'Opportunity Stage Changed',
                    senderId,
                    notifTypeId,
                    opp.Id,
                    recipients
                );
            }
        } catch (Exception ex) {
            ExceptionHandler.addLog(ex, String.valueOf(opps), 'OpportunityTriggerHandler', 'sendStageChangeNotification');
        }
    }

    /* ────────────────────────────────────────────
       Closed Won Notification
       BRD: Notify Owner, Manager, and Coordinator on Won
    ──────────────────────────────────────────── */
    public static void sendClosedWonNotification(List<Opportunity> opps) {
        try {
            List<CustomNotificationType> notifTypes = [
                SELECT Id FROM CustomNotificationType
                WHERE DeveloperName = 'Opportunity_Notification'
                LIMIT 1
            ];
            if (notifTypes.isEmpty()) return;

            String notifTypeId = notifTypes[0].Id;
            String senderId = UserInfo.getUserId();

            Set<Id> ownerIds = new Set<Id>();
            for (Opportunity opp : opps) {
                if (opp.OwnerId != null) ownerIds.add(opp.OwnerId);
            }

            Map<Id, User> ownerMap = new Map<Id, User>(
                [SELECT Id, ManagerId FROM User WHERE Id IN :ownerIds]
            );

            // Get Coordinator users
            Set<String> coordinatorIds = new Set<String>();
            List<UserRole> roleList = [
                SELECT Id FROM UserRole WHERE Name = 'Coordinator' LIMIT 1
            ];
            if (!roleList.isEmpty()) {
                for (User u : [SELECT Id FROM User WHERE UserRoleId = :roleList[0].Id AND IsActive = true]) {
                    coordinatorIds.add(u.Id);
                }
            }

            for (Opportunity opp : opps) {
                Set<String> recipients = new Set<String>();
                recipients.add(opp.OwnerId);

                User owner = ownerMap.get(opp.OwnerId);
                if (owner != null && owner.ManagerId != null) {
                    recipients.add(owner.ManagerId);
                }
                recipients.addAll(coordinatorIds);

                SendEmailCustomNotification.sendNotification(
                    'Opportunity "' + opp.Name + '" has been marked as Closed Won.',
                    'Opportunity Closed Won',
                    senderId,
                    notifTypeId,
                    opp.Id,
                    recipients
                );
            }
        } catch (Exception ex) {
            ExceptionHandler.addLog(ex, String.valueOf(opps), 'OpportunityTriggerHandler', 'sendClosedWonNotification');
        }
    }

    /* ────────────────────────────────────────────
       Closed Lost Notification
       BRD: Notify Owner and Manager on Lost
    ──────────────────────────────────────────── */
    public static void sendClosedLostNotification(List<Opportunity> opps) {
        try {
            List<CustomNotificationType> notifTypes = [
                SELECT Id FROM CustomNotificationType
                WHERE DeveloperName = 'Opportunity_Notification'
                LIMIT 1
            ];
            if (notifTypes.isEmpty()) return;

            String notifTypeId = notifTypes[0].Id;
            String senderId = UserInfo.getUserId();

            Set<Id> ownerIds = new Set<Id>();
            for (Opportunity opp : opps) {
                if (opp.OwnerId != null) ownerIds.add(opp.OwnerId);
            }

            Map<Id, User> ownerMap = new Map<Id, User>(
                [SELECT Id, ManagerId FROM User WHERE Id IN :ownerIds]
            );

            for (Opportunity opp : opps) {
                Set<String> recipients = new Set<String>();
                recipients.add(opp.OwnerId);

                User owner = ownerMap.get(opp.OwnerId);
                if (owner != null && owner.ManagerId != null) {
                    recipients.add(owner.ManagerId);
                }

                SendEmailCustomNotification.sendNotification(
                    'Opportunity "' + opp.Name + '" has been marked as Closed Lost. Reason: ' +
                        (opp.Closed_Lost_Reason__c != null ? opp.Closed_Lost_Reason__c : 'N/A'),
                    'Opportunity Closed Lost',
                    senderId,
                    notifTypeId,
                    opp.Id,
                    recipients
                );
            }
        } catch (Exception ex) {
            ExceptionHandler.addLog(ex, String.valueOf(opps), 'OpportunityTriggerHandler', 'sendClosedLostNotification');
        }
    }
}