global class CampaignScheduler  implements Database.Batchable<sObject>,Database.Stateful,Schedulable{
    /**************************************************************** 
* Class Name  : CampaignScheduler  @Company  : Fingertip    @Created Date  : 21-10-2025  
@description :campaign scheduler   @author  :Nanma T V   @User By  : - 
* Change Log: 
* ----------------------------------------------------------------------------- 
* Ver |   Author      |   Date        |   Description 
* ----------------------------------------------------------------------------- 
* 1.0 |   Nanma  |  21-10-2025 |   Initial version      
* -------------------------------------------------------------------


*Functionalities :-
f1.Based on the Start date system should automatically activate the campaign
f2.If it is not started based on the end date system will cancel the campaign with reason system cancelled
f3.if it is started based on the end date system will mark as only completed 
**************************************************************** */
    
    public Database.QueryLocator start(Database.BatchableContext BC){
        String query = 'SELECT Id, Name, StartDate, EndDate,Reason_for_Cancellation__c, Status, Approval_Status__c ' +
            'FROM Campaign ' +
            'WHERE (Approval_Status__c = \'Approved\' OR Approval_Status__c = \'Draft\') ' +
            'AND (StartDate = TODAY OR EndDate < TODAY)';
        
        return Database.getQueryLocator(query);
    }
    public void execute(Database.BatchableContext BC, List<Campaign> campaigns){
        
        list<Campaign> activateCampaign= new list<Campaign>();//f1
        list<Campaign> cancelCampaign= new list<Campaign>();//f2
        list<Campaign> completedCampaign= new list<Campaign>();//f3
        list<Error_Log__c> errorList = new  list<Error_Log__c>();
        if(!campaigns.isEmpty()){
            date today = system.today();
            for(Campaign camp : campaigns){
                
                if(camp.Approval_Status__c=='Approved' && camp.StartDate==today){ //f1
                    activateCampaign.add(camp);  
                }
                if(camp.Approval_Status__c=='Approved'  && camp.Status =='Approved' && camp.EndDate <today){ //f2
                    cancelCampaign.add(camp);  
                }
                if(camp.Approval_Status__c=='Approved' && camp.Status=='Started' && camp.EndDate <today){ //f3
                    completedCampaign.add(camp);  
                }
            }
            
            if(!activateCampaign.isEmpty()){
                for(Campaign camp : activateCampaign){
                    camp.Status ='Started';
                    camp.IsActive =true;
                }  
                list<Database.SaveResult> updateResults =Database.update(activateCampaign ,false);
                
                // Check for failed upserts in receiptList
                for (Integer i = 0; i < updateResults.size(); i++) {
                    if (!updateResults[i].isSuccess()) {
                        // Log the reason for failure
                        for (Database.Error error : updateResults[i].getErrors()) {
                            Error_Log__c l = new Error_Log__c();
                            l.RecordData__c = string.valueof(activateCampaign);
                            l.Message__c =error.getMessage()+'-line-'+error.getStatusCode()+'-'+error.getFields()+'-campaignactivate';
                            errorList.add(l);
                        }
                    }
                } 
            }
            
            if(!cancelCampaign.isEmpty()){
                for(Campaign camp : cancelCampaign){
                    camp.Status ='Cancelled';
                    camp.IsActive =false;
                    camp.Reason_for_Cancellation__c ='System Cancelled';
                    camp.Cancelled_Date_Time__c =system.now();
                }  
                list<Database.SaveResult> updateResults =Database.update(cancelCampaign ,false);
                
                // Check for failed upserts in receiptList
                for (Integer i = 0; i < updateResults.size(); i++) {
                    if (!updateResults[i].isSuccess()) {
                        // Log the reason for failure
                        for (Database.Error error : updateResults[i].getErrors()) {
                            Error_Log__c l = new Error_Log__c();
                            l.RecordData__c = string.valueof(cancelCampaign);
                            l.Message__c =error.getMessage()+'-line-'+error.getStatusCode()+'-'+error.getFields()+'-campaigncancelled';
                            errorList.add(l);
                        }
                    }
                } 
            }
            if(!completedCampaign.isEmpty()){
                for(Campaign camp : completedCampaign){
                    camp.Status ='Completed';
                    camp.IsActive =false;
                }  
                list<Database.SaveResult > updateResults =Database.update(completedCampaign ,false);
                
                // Check for failed upserts in receiptList
                for (Integer i = 0; i < updateResults.size(); i++) {
                    if (!updateResults[i].isSuccess()) {
                        // Log the reason for failure
                        for (Database.Error error : updateResults[i].getErrors()) {
                            Error_Log__c l = new Error_Log__c();
                            l.RecordData__c = string.valueof(cancelCampaign);
                            l.Message__c =error.getMessage()+'-line-'+error.getStatusCode()+'-'+error.getFields()+'-campaigncompleted';
                            errorList.add(l);
                        }
                    }
                } 
            }
            
        } 
    }
    public void finish(Database.BatchableContext BC){
    }
    
    global void execute(SchedulableContext SC){
        database.executeBatch(new CampaignScheduler(),200);
        
    } 
}