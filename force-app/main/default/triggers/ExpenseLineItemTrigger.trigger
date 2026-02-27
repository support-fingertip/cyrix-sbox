trigger ExpenseLineItemTrigger on Expenses_Line_Item__c (after insert,before insert , before update) {
    if(Trigger.isInsert)
    {
        if(Trigger.isAfter)
        {
            ExpenseLineItemTriggerHandler.afterInsert(trigger.new);
        }
    }
    if(trigger.isBefore && (trigger.isInsert || trigger.isUpdate)){
        if(trigger.isInsert){
            for(Expenses_Line_Item__c e : trigger.New){
                e.Submitted_Amount__c = e.Amount__c!=null ?e.Amount__c:0; 
            }
        }
         if(trigger.isUpdate){
             string currentuserId =userinfo.getuserId();
            for(Expenses_Line_Item__c e : trigger.New){
                
                if(trigger.oldMap.get(e.Id).Amount__c != e.Amount__c &&currentuserId.contains(e.ownerId__c)){
   
                e.Submitted_Amount__c = e.Amount__c!=null ?e.Amount__c:0; 
                }
            }
        }
    }
    
}