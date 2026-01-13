public without sharing class SendEmailCustomNotification {
    
    public static void sendNotification(string body,string title,string senderId,string notificationId,Id recId, Set<String> recUserIds ){
        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        notification.setBody(body);
        notification.setTitle(title);
        notification.setSenderId(senderId);
        notification.setNotificationTypeId(notificationId);
        notification.setTargetId(recId); // target object id
     //   notification.send(new Set<String> {reciverId}); 
      notification.send(recUserIds); 
    }
    public static void sendEmail(string subject,string htmlBody,string disName,string[] emailArray){
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setSubject(subject);
        message.setHtmlBody(htmlBody);
        message.toAddresses = emailArray;
        Id orgWideEmailAddressId = [SELECT Id FROM OrgWideEmailAddress WHERE address  = '' ].Id;
        message.setOrgWideEmailAddressId(orgWideEmailAddressId);  
        
        Messaging.SingleEmailMessage[] messages = new List<Messaging.SingleEmailMessage> {message};
            Messaging.SendEmailResult[] results = null;
        if(!Test.isRunningTest())
            results = Messaging.sendEmail(messages);  
        system.debug(results);  
        
        
    }
    public static Messaging.SingleEmailMessage sendBulkEmail(string subject,string htmlBody,string disName,string[] emailArray){
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setSubject(subject);
        message.setHtmlBody(htmlBody);
        message.toAddresses = emailArray;
        Id orgWideEmailAddressId = [SELECT Id FROM OrgWideEmailAddress WHERE address  = '' ].Id;
        message.setOrgWideEmailAddressId(orgWideEmailAddressId); 
        return message;

                                    
    }
}