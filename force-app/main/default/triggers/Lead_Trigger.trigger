trigger Lead_Trigger on Lead (before insert,after insert,before update,after update) {
    /**************************************************************** 
* Class Name  : Lead_Trigger  @Company  : Fingertip    @Created Date  : 29-9-2025  
@description : lead object trigger   @author  :Nanma T V   @User By  : -leadtriggerHandler
* Change Log: 
* ----------------------------------------------------------------------------- 
* Ver |   Author      |   Date        |   Description 
* ----------------------------------------------------------------------------- 
* 1.0 |   Nanma  |  29-9-2025 |   Initial version      
* -------------------------------------------------------------------
**************************************************************** */  
     if(trigger.operationType == TriggerOperation.BEFORE_INSERT ){
        if(UserInfo.getProfileId() ==label.Sales_Engineer_profile_id)
            for(lead l : trigger.New){
                l.ownerId =UserInfo.getuserId();
            }
    }
     if(trigger.operationType == TriggerOperation.BEFORE_INSERT || trigger.operationType == TriggerOperation.BEFORE_UPDATE){
        LeadTriggerHandler.checkAndSeprateMobileNumber(trigger.New);
        
    }
    
        if(trigger.operationType == TriggerOperation.AFTER_INSERT || trigger.operationType == TriggerOperation.AFTER_UPDATE){
        
        list<lead> campaignMemberList= new list<lead>();
        list<lead> leadOwnerList= new list<lead>();
        
        for(lead ld : trigger.New){
            if(ld.Campaign__c !=null && trigger.isInsert){
                campaignMemberList.add(ld);  
            }
            if(trigger.isInsert){
                leadOwnerList.add(ld);  
            }
            if(trigger.isUpdate){
                lead oldLead= trigger.oldMap.get(ld.Id);
                if(ld.Campaign__c !=null && oldLead.Campaign__c != ld.Campaign__c){
                    campaignMemberList.add(ld);  
                }
                if( oldLead.ownerId != ld.ownerId){
                    leadOwnerList.add(ld);  
                }
            }
            
        } 
        if(!campaignMemberList.isEmpty()){
            LeadTriggerHandler.campaignMapping(campaignMemberList);   
        }
        if(!leadOwnerList.isEmpty()){
            LeadTriggerHandler.leadAssignedNotification(leadOwnerList); 
        }
        
        
    } 
    
    if (trigger.operationType == TriggerOperation.AFTER_UPDATE) {
        
        Set<string> accountIds = new Set<string>();
        list<lead> closedConvertedIds = new list<lead>();
        list<lead> followupTask = new list<lead>();
        
        for (Lead lead : trigger.New) {
            lead oldlead = trigger.oldMap.get(lead.Id);
            if (lead.IsConverted  && lead.ConvertedAccountId != null) {
                accountIds.add(lead.ConvertedAccountId);
            }
            if((lead.Status == 'Closed Lost' && lead.Status != 'Closed Lost')|| lead.isConverted) {
                closedConvertedIds.add(lead);
            }
            if(lead.Next_Follow_up_Date__c != null && Trigger.oldMap.get(lead.Id).Next_Follow_up_Date__c !=lead.Next_Follow_up_Date__c){
                followupTask.add(lead);
            }
        }
        
        if(!followupTask.isEmpty()){
            LeadTriggerHandler.createfollowupTasks(followupTask);
        }
        if(accountIds.size() >0){
            LeadTriggerHandler.setAccountEmail(trigger.New,accountIds);
        }
        if(closedConvertedIds.size() >0){
            LeadTriggerHandler.sendLostConvertedManagerNotification(closedConvertedIds);
        }
        
    }
  


    
    
    
    
}