public class LeadReminderScheduler_v1 implements Schedulable {

    /* ============================================================
       DTO CLASS (PUBLIC + STATIC → TEST CAN ACCESS IT)
       ============================================================ */
    @TestVisible
    public  class LeadInfo {
        public Id leadId;
        public Id ownerId;
        public String rating;
        public Date lastActivityDate;

        public LeadInfo(
            Id leadId,
            Id ownerId,
            String rating,
            Date lastActivityDate
        ) {
            this.leadId = leadId;
            this.ownerId = ownerId;
            this.rating = rating;
            this.lastActivityDate = lastActivityDate;
        }
    }

    /* ============================================================
       TEST INJECTION HOOK
       ============================================================ */
    @TestVisible
    public static List<LeadInfo> testLeadInfos;

    /* ============================================================
       SCHEDULER ENTRY POINT
       ============================================================ */
    public void execute(SchedulableContext context) {

        CustomNotificationType type = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Lead_Notification'
            LIMIT 1
        ];

        List<LeadInfo> leads = new List<LeadInfo>();

        // 🔑 Use injected data in tests
        if (Test.isRunningTest() && testLeadInfos != null) {
            leads = testLeadInfos;
        } else {
            // 🔒 Production path (real Leads → DTO)
            for (Lead l : [
                SELECT Id,
                       OwnerId,
                       Lead_Rating__c,
                       Last_Activity_Date__c
                FROM Lead
                WHERE Last_Activity_Date__c != NULL
                  AND OwnerId != NULL
            ]) {
                leads.add(
                    new LeadInfo(
                        l.Id,
                        l.OwnerId,
                        l.Lead_Rating__c,
                        l.Last_Activity_Date__c
                    )
                );
            }
        }

        if (leads.isEmpty()) return;

        // Collect owner ids
        Set<Id> ownerIds = new Set<Id>();
        for (LeadInfo li : leads) {
            ownerIds.add(li.ownerId);
        }

        Map<Id, User> ownerMap = new Map<Id, User>(
            [SELECT Id, ManagerId FROM User WHERE Id IN :ownerIds]
        );

        Date today = Date.today();

        for (LeadInfo li : leads) {

            if (!shouldNotify(li.rating, li.lastActivityDate, today)) {
                continue;
            }

            User owner = ownerMap.get(li.ownerId);
            if (owner == null || owner.ManagerId == null) continue;

            SendEmailCustomNotification.sendNotification(
                'Lead pending follow-up',
                'Reminder: Lead not addressed in time',
                UserInfo.getUserId(),
                type.Id,
                li.leadId,
                new Set<String>{ owner.ManagerId }
            );
        }
    }

    /* ============================================================
       BUSINESS LOGIC (FULLY TESTABLE)
       ============================================================ */
    @TestVisible
    public static Boolean shouldNotify(
        String rating,
        Date lastActivityDate,
        Date today
    ) {
        if (rating == null || lastActivityDate == null || today == null) {
            return false;
        }

        Integer days =
            lastActivityDate.daysBetween(today);

        return (rating == 'Hot'  && days > 2) ||
               (rating == 'Warm' && days > 7) ||
               (rating == 'Cold' && days > 10);
    }
}