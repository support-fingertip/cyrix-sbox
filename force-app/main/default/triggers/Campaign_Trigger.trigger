trigger Campaign_Trigger on Campaign (before insert,before update,after update) {
    
 /**************************************************************** 
* Class Name  : Campaign_Trigger  @Company  : Fingertip    @Created Date  : 19-9-2025  
@description : campaign object trigger   @author  :Nanma T V   @User By  : - campagin trigger handler
* Change Log: 
* ----------------------------------------------------------------------------- 
* Ver |   Author      |   Date        |   Description 
* ----------------------------------------------------------------------------- 
* 1.0 |   Nanma  |  19-9-2025 |   Initial version      
* -------------------------------------------------------------------
**************************************************************** */  
    // approval request noti to submitter approver , rejected notification
    // duplicate land number for 2 active campaign
    // lead auto tagging
    
    if(trigger.isBefore && trigger.isInsert){
    CampaignTrigger_Handler.mapApproverUser(trigger.New);
    }
    
    if(trigger.isBefore && trigger.isUpdate){
        for(Campaign camp : trigger.New){ 
              Campaign campaignOld = trigger.oldMap.get(camp.Id);
            if(camp.Status =='Started' && camp.IsActive == false){
               camp.IsActive = true; 
            }
                if((camp.Status =='Cancelled' || camp.Status =='Completed') && camp.IsActive ){
               camp.IsActive = false; 
            }
             if(trigger.oldMap.get(camp.Id).Status =='Cancelled' && camp.Status != trigger.oldMap.get(camp.Id).Status){
              camp.Status.addError('Cannot change status of cancelled campaign'); 
            }
             if((camp.IsActive == true ||(camp.Status !=campaignOld.Status  && camp.Status =='Approved')) && camp.Approval_Status__c !='Approved'){
               camp.IsActive.addError('This campaign is still pending approval and cannot be activated'); 
            }
                     if(camp.Status =='Rejected' && camp.Approval_Status__c !='Rejected' && camp.Status !=campaignOld.Status){
               camp.Status.addError('Cannot change status to rejected  manually'); 
            } 
                   if((camp.Status =='Rejected' || camp.Status =='Submitted for Approval' || camp.Status =='Hold' || camp.Status =='Approved' )&& camp.Approval_Status__c =='Draft'){
               camp.Status.addError('Cannot change status to '+camp.Status+'  manually'); 
            }    
                    if(camp.Status =='Cancelled'  && campaignOld.Status !=camp.Status){
               camp.Cancelled_Date_Time__c = system.now(); 
            }
        }
    } 
       
  
    
    if(trigger.isUpdate && trigger.isAfter){
        list<Campaign> approvedCampaignList = new list<Campaign>();
        list<Campaign> rejectedCampaignList = new list<Campaign>();
        list<Campaign> resubmitCampaignList = new list<Campaign>();
        
        for(Campaign cam : trigger.New){ 
            Campaign campaignOld = trigger.oldMap.get(cam.Id);
            /* trgger notification when campaign approved or rejected*/
            if((cam.Approval_Status__c =='Approved' || cam.Approval_Status__c =='Rejected') && campaignOld.Approval_Status__c != cam.Approval_Status__c){
                if(cam.Approval_Status__c =='Approved' ){
                    approvedCampaignList.add(cam);   
                }
                if(cam.Approval_Status__c =='Rejected' ){
                    rejectedCampaignList.add(cam);   
                }
            }
            
            /* trgger notification to submitter when campaign resubmitted*/
            if(cam.Approval_Status__c =='Submitted for Approval'  && campaignOld.Approval_Status__c =='Rejected'){
                resubmitCampaignList.add(cam);
            }       
            
        }
        if(!approvedCampaignList.isEmpty()){
            CampaignTrigger_Handler.campaignSubmitterNotification(approvedCampaignList,'Approved');
        } 
        if(!rejectedCampaignList.isEmpty()){
         CampaignTrigger_Handler.campaignSubmitterNotification(rejectedCampaignList,'Rejected'); 
        } 
            if(!resubmitCampaignList.isEmpty()){
            CampaignTrigger_Handler.campaignSubmitterNotification(resubmitCampaignList,'Re-submitted');
        }  
        
    }
    
    
    
    
    
}