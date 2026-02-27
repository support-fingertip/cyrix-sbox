public class LeadReminderScheduler_v1 implements Schedulable {

    public void execute(SchedulableContext context) {

        CustomNotificationType type = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Lead_Notification'
            LIMIT 1
        ];

        DateTime nowDT = System.now();
        List<Lead> leadsToUpdate = new List<Lead>();

        List<Lead> leads = [
            SELECT Id, OwnerId, Lead_Rating__c, PurchaseDate_Last_Updated__c, Last_Activity_Date__c,
                   Hot_Notification_Sent__c, Warm_Notification_Sent__c, Cold_Notification_Sent__c
            FROM Lead
            WHERE Lead_Rating__c IN ('🔴 Hot', '🟠 Warm', '🔵 Cold')
              AND PurchaseDate_Last_Updated__c != NULL
              AND (Hot_Notification_Sent__c = false OR Warm_Notification_Sent__c = false OR Cold_Notification_Sent__c = false)
        ];

        System.debug(leads);

        Set<Id> ownerIds = new Set<Id>();
        for (Lead li : leads) {
            ownerIds.add(li.OwnerId);
        }

        Map<Id, User> ownerMap = new Map<Id, User>(
            [SELECT Id, ManagerId FROM User WHERE Id IN :ownerIds]
        );

        for (Lead l : leads) {

            if (l.Last_Activity_Date__c == null) continue;

            Integer days = l.PurchaseDate_Last_Updated__c.daysBetween(Date.today());

            Boolean shouldNotify =
                (l.Lead_Rating__c == '🔴 Hot'  && days == 3  && l.Last_Activity_Date__c < Date.today().addDays(-2)) ||
                (l.Lead_Rating__c == '🟠 Warm' && days == 7  && l.Last_Activity_Date__c < Date.today().addDays(-6)) ||
                (l.Lead_Rating__c == '🔵 Cold' && days == 10 && l.Last_Activity_Date__c < Date.today().addDays(-9));

            if (shouldNotify) {

                if (l.Lead_Rating__c == '🔴 Hot')
                    l.Hot_Notification_Sent__c = true;
                else if (l.Lead_Rating__c == '🟠 Warm')
                    l.Warm_Notification_Sent__c = true;
                else if (l.Lead_Rating__c == '🔵 Cold')
                    l.Cold_Notification_Sent__c = true;

                leadsToUpdate.add(l);

                User owner = ownerMap.get(l.OwnerId);
                if (owner == null || owner.ManagerId == null) continue;

                SendEmailCustomNotification.sendNotification(
                    'Lead pending follow-up',
                    'Reminder: Lead not addressed in time',
                    UserInfo.getUserId(),
                    type.Id,
                    l.Id,
                    new Set<String>{ owner.ManagerId }
                );
            }
        }

        if (!leadsToUpdate.isEmpty()) {
            update leadsToUpdate;
        }
    }
}