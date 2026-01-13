global class DailyLogNotificationBatch implements Database.Batchable<SObject>, Database.Stateful {
    global Database.QueryLocator start(Database.BatchableContext BC) {
        // Query Daily_Log__c records created today with Day_ended_time__c null
        return Database.getQueryLocator([
            SELECT Id, OwnerId
            FROM Daily_Log__c
            WHERE CreatedDate = TODAY AND Day_ended_time__c = null
        ]);
    }

    global void execute(Database.BatchableContext BC, List<Daily_Log__c> scope) {
        Set<String> recipientIds = new Set<String>();
        
        // Collect owner Ids for notification
        for (Daily_Log__c log : scope) {
            recipientIds.add(log.OwnerId);
        }

        if (!recipientIds.isEmpty()) {
            // Notify users with a custom notification
            CustomNotificationType notificationType = [SELECT Id, DeveloperName FROM CustomNotificationType WHERE DeveloperName='EndDayRemainderNotification'];
            
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            
            notification.setTitle('Please End the Day !!');
            notification.setBody('You have not yet ended the day, you are still working? If not, please end your day.');
            
            // Set the target Lightning page reference
            String targetPageRef = 
                '' +
                '{' +
                '   "type": "standard__navItemPage",' +
                '   "attributes": {' +
                '       "apiName": "Today_s_Visit"' +
                '   }' +
                '}';
            
            notification.setNotificationTypeId(notificationType.Id);
            notification.setTargetPageRef(targetPageRef);
            
            // Actually send the notification
            try {
                notification.send(recipientIds);
            }
            catch (Exception e) {
                System.debug('Problem sending notification: ' + e.getMessage());
            }
        }
    }

    global void finish(Database.BatchableContext BC) {
        // Implement any post-processing logic if needed
    }
}