public class CampaignTrigger_Handler {
    /**************************************************************** 
* Class Name  : CampaignTrigger_Handler  @Company  : Fingertip    @Created Date  : 21-9-2025  
@description : campaign object trigger handler   @author  :Nanma T V   @User By  : - campagin trigger 
* Change Log: 
* ----------------------------------------------------------------------------- 
* Ver |   Author      |   Date        |   Description 
* ----------------------------------------------------------------------------- 
* 1.0 |   Nanma  |  21-9-2025 |   Initial version      
* -------------------------------------------------------------------
**************************************************************** */
    
    
    /*@method name :campaignSubmitterNotification   @description :trigger  notification after  campagin approved /rejected @lastModified: 21/9/2025 @param1: campaign list @param 2: status : approved /rejected*/
    public static void campaignSubmitterNotification( list<Campaign> apprRejectCampaignList,string status ){
        CustomNotificationType type = [SELECT Id FROM CustomNotificationType WHERE DeveloperName =: 'Campaign_Notification' LIMIT 1];
        String body, title, senderId, notificationId;
        notificationId = type.Id;
        senderId = UserInfo.getUserId();
        for (Campaign camp : apprRejectCampaignList) {
            body = 'Campaign-' + camp.Name + ' has been '+status;
            title = camp.Name+' - '+status;
            // Send notification to owner
            Set<String> recUserIds = new Set<String>{camp.OwnerId};
                SendEmailCustomNotification.sendNotification(body, title, senderId, notificationId, camp.Id, recUserIds);
        } 
    }  
      @TestVisible
      public static Boolean skipInTest = false;
    
    public static void mapApproverUser(list<Campaign> campaignList){
         if (Test.isRunningTest() && skipInTest) {
        return;
          }
        General_Settings__c settings =[select Id, Campaign_Marketing_Manager_Approver__c, Campaign_Final_Approver__c, 
                                       Campaign_Expense_Approver__c, Telephony_Campaign_Approver__c, Academy_Campaign_Approver__c, 
                                       Sales_Campaign_Approver__c, Service_Campaign_Approver__c, Marketing_Campaign_Approver__c, 
                                       HR_Campaign_Approver__c, Digital_Campaign_Approver__c from General_Settings__c limit 1];  
        for(Campaign camp : campaignList){ 

            if(settings.Campaign_Marketing_Manager_Approver__c !=null){
                camp.Marketing_Manager_Approver__c = settings.Campaign_Marketing_Manager_Approver__c;
            }
            if(camp.Budget_Source__c == 'Marketing' || camp.Budget_Source__c == 'Corporate'){
                camp.Budget_Holder_Approver__c = settings.Marketing_Campaign_Approver__c;
            }else if(camp.Budget_Source__c == 'Digital'){
                camp.Budget_Holder_Approver__c = settings.Digital_Campaign_Approver__c;
            }else if(camp.Budget_Source__c == 'HR' || camp.Budget_Source__c == 'Others'){
                camp.Budget_Holder_Approver__c = settings.HR_Campaign_Approver__c;
            }else if(camp.Budget_Source__c == 'Sales'){
                camp.Budget_Holder_Approver__c = settings.Sales_Campaign_Approver__c;
            }else if(camp.Budget_Source__c == 'Service Sales'){
                camp.Budget_Holder_Approver__c = settings.Service_Campaign_Approver__c;
            }else if(camp.Budget_Source__c == 'Academy'){
                camp.Budget_Holder_Approver__c = settings.Academy_Campaign_Approver__c;
            }else if(camp.Budget_Source__c == 'Telephony'){
                camp.Budget_Holder_Approver__c = settings.Telephony_Campaign_Approver__c;
            }
               if(settings.Campaign_Expense_Approver__c !=null){
                camp.Final_Expense_Approver__c = settings.Campaign_Expense_Approver__c;
            }
               if(settings.Campaign_Final_Approver__c !=null){
                camp.Campaign_Final_Approver__c = settings.Campaign_Final_Approver__c;
            }
        }
    } 
}