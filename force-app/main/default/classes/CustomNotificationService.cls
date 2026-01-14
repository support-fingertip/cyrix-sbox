public class CustomNotificationService {
  //Roopesh 22/10/2025  
    public static void notificationSend(String notifyTitle,id notifyId,string notificationBody,set<string> targetUserIds,string notificationId){
         system.debug('Entered 33============');
        if (targetUserIds == null || targetUserIds.isEmpty()) return;
        system.debug('Entered 22============');
        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        notification.setTitle(notifyTitle);
        notification.setNotificationTypeId(notificationId);
        notification.setTargetId(notifyId);
        notification.setBody(notificationBody);
        notification.send(targetUserIds);
        
    }
    
}