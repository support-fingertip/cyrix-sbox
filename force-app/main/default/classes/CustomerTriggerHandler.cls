public class CustomerTriggerHandler {
    public static void handleBeforeUpdate(List<Account> newList, Map<Id, Account> oldMap){
        for(Account cust : newList){
            Account oldCust = oldMap.get(cust.Id);
            if(cust.Status__c != oldCust.Status__c &&
               oldCust.Status__c == 'Inactive'){
                cust.Approval_Status__c = null;
            }
        }
    }


   public static void handleAfterInsert(List<Account> accountList){

        // Get Custom Notification Type
        CustomNotificationType type = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Customer_Notification'
            LIMIT 1
        ];

        String senderId = UserInfo.getUserId();

        for(Account acc : accountList){

            if(acc.OwnerId == null) continue;

            Set<String> recipients = new Set<String>{
                String.valueOf(acc.OwnerId)
            };

            // Send notification using your org utility class
            SendEmailCustomNotification.sendNotification(

                'Customer "' + acc.Name + '" has been assigned to you',

                'Customer Assigned',

                senderId,

                type.Id,

                acc.Id,

                recipients
            );
        }
    }
}