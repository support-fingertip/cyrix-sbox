trigger Customer_Trigger on Account (before update) {
    

    if(trigger.isUpdate && trigger.isBefore){
        for(account cust : trigger.New){
            if(cust.Status__c != trigger.oldMap.get(cust.Id).Status__c && trigger.oldMap.get(cust.Id).Status__c =='Inactive'){
                cust.Approval_Status__c =null;
            }
        }
    }
}