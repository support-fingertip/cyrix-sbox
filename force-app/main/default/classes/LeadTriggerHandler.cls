public class LeadTriggerHandler {

    /* ---------------- Campaign Mapping ---------------- */
    public static void campaignMapping(List<Lead> leads) {

        List<CampaignMember> cms = new List<CampaignMember>();

        for (Lead l : leads) {
            if (l.Id != null && l.Campaign__c != null) {
                cms.add(new CampaignMember(
                    LeadId = l.Id,
                    CampaignId = l.Campaign__c,
                    Status = 'Sent'
                ));
            }
        }

        if (!cms.isEmpty()) {
            try {
                insert cms;
            } catch (Exception ex) {
                ExceptionHandler.addLog(
                    ex,
                    String.valueOf(cms),
                    'LeadTriggerHandler',
                    'campaignMapping'
                );
            }
        }
    }

    /* ---------------- Lead Assigned Notification ---------------- */
    public static void leadAssignedNotification(List<Lead> leads) {

        CustomNotificationType type = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Lead_Notification'
            LIMIT 1
        ];

        String senderId = UserInfo.getUserId();

        for (Lead l : leads) {

            if (l.OwnerId == null) continue;

            String name =
                (l.Salutation != null ? l.Salutation + ' ' : '') +
                (l.FirstName != null ? l.FirstName + ' ' : '') +
                l.LastName;

            SendEmailCustomNotification.sendNotification(
                'Lead - ' + name + ' is assigned to you',
                'Lead Assigned',
                senderId,
                type.Id,
                l.Id,
                new Set<String>{ l.OwnerId }
            );
        }
    }

    /* ---------------- Phone & Mobile Split ---------------- */
    public static void checkAndSeprateMobileNumber(List<Lead> leads) {

        Map<String, String> countryCodeMap =
            Utility.getAllCountryCodeMappings(true);

        for (Lead l : leads) {

            if (l.Phone != null && l.Phone.startsWith('+91')) {
                l.Country_Code_Phone__c = '+91';
                l.Country__c = countryCodeMap.get('91');
                l.Phone = l.Phone.replace('+91', '');
            }

            if (l.MobilePhone != null && l.MobilePhone.startsWith('+91')) {
                l.Country_Code_Mobile__c = '+91';
                l.MobilePhone_Country__c = countryCodeMap.get('91');
                l.MobilePhone = l.MobilePhone.replace('+91', '');
            }
        }
    }

    /* ---------------- Utility ---------------- */
    public static String getformated(String value) {
        return value == null ? '' : value;
    }

    /* ---------------- Last Activity Date ---------------- */
    public static void updateLastActivityDate(
        List<Lead> newLeads,
        Map<Id, Lead> oldMap
    ) {
        for (Lead l : newLeads) {
            Lead oldL = oldMap.get(l.Id);
            if (oldL != null &&
                (l.Status != oldL.Status ||
                 l.Rating != oldL.Rating ||
                 l.LeadSource != oldL.LeadSource ||
                 l.Lead_Category__c != oldL.Lead_Category__c ||
                 l.GST_Number__c != oldL.GST_Number__c ||
                 l.Company != oldL.Company)) {

                l.Last_Activity_Date__c = Date.today();
            }
        }
    }

    /* ---------------- Lost / Converted Notification ---------------- */
    public static void sendLostConvertedManagerNotification(List<Lead> leads) {

        CustomNotificationType type = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Lead_Notification'
            LIMIT 1
        ];

        Set<Id> ownerIds = new Set<Id>();
        for (Lead l : leads) {
            if (l.OwnerId != null) ownerIds.add(l.OwnerId);
        }

        Map<Id, User> ownerMap = new Map<Id, User>(
            [SELECT Id, ManagerId FROM User WHERE Id IN :ownerIds]
        );

        for (Lead l : leads) {

            User u = ownerMap.get(l.OwnerId);
            if (u == null || u.ManagerId == null) continue;

            String body;
            String title;

            if (l.Status == 'Closed Lost') {
                body = 'Lead lost';
                title = 'Lead Closed Lost';
            } else if (l.IsConverted) {
                body = 'Lead converted';
                title = 'Lead Converted';
            } else {
                continue;
            }

            SendEmailCustomNotification.sendNotification(
                body,
                title,
                UserInfo.getUserId(),
                type.Id,
                l.Id,
                new Set<String>{ u.ManagerId }
            );
        }
    }

    /* ---------------- Duplicate Check ---------------- */
    public static void findDuplicate(List<Lead> leads) {

        if (leads.isEmpty()) return;

        Set<String> emails = new Set<String>();
        for (Lead l : leads) {
            if (l.Email != null) emails.add(l.Email);
        }

        if (emails.isEmpty()) return;

        Map<String, Lead> existing = new Map<String, Lead>();
        for (Lead l : [
            SELECT Id, Email
            FROM Lead
            WHERE Email IN :emails
        ]) {
            existing.put(l.Email, l);
        }

        for (Lead l : leads) {
            if (l.Email != null && existing.containsKey(l.Email)) {
                l.Duplicate_Parent_Lead__c = existing.get(l.Email).Id;
                l.Duplicate_Flag__c = true;
            }
        }
    }

    /* ============================================================
       Account Email Sync
       ============================================================ */

    // REQUIRED wrapper to keep trigger compatibility
    public static void setAccountEmail(List<Lead> leadList, Set<String> accountIds) {
        // accountIds intentionally ignored
        setAccountEmail(leadList);
    }

    // Actual implementation
    public static void setAccountEmail(List<Lead> leads) {

        Set<Id> accIds = new Set<Id>();
        for (Lead l : leads) {
            if (l.IsConverted && l.ConvertedAccountId != null) {
                accIds.add(l.ConvertedAccountId);
            }
        }

        if (accIds.isEmpty()) return;

        Map<Id, Account> accMap = new Map<Id, Account>(
            [SELECT Id, Email__c FROM Account WHERE Id IN :accIds]
        );

        List<Account> updates = new List<Account>();
        for (Lead l : leads) {
            if (accMap.containsKey(l.ConvertedAccountId) && l.Email != null) {
                Account a = accMap.get(l.ConvertedAccountId);
                a.Email__c = l.Email;
                updates.add(a);
            }
        }

        if (!updates.isEmpty()) {
            try {
                update updates;
            } catch (Exception ex) {
                ExceptionHandler.addLog(
                    ex,
                    String.valueOf(updates),
                    'LeadTriggerHandler',
                    'setAccountEmail'
                );
            }
        }
    }

    /* ---------------- Follow-up Tasks ---------------- */
    public static void createfollowupTasks(List<Lead> leads) {

        List<Task> tasks = new List<Task>();

        for (Lead l : leads) {
            if (l.Next_Follow_up_Date__c == null || l.OwnerId == null) continue;

            tasks.add(new Task(
                Subject = 'Lead Follow-up',
                ActivityDate = l.Next_Follow_up_Date__c,
                WhoId = l.Id,
                OwnerId = l.OwnerId,
                Status = 'Not Started',
                Priority = 'Normal'
            ));
        }

        if (!tasks.isEmpty()) {
            insert tasks;
        }
    }
}