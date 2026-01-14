trigger ExpenseTrigger on Expense__c (before insert,after Update) {
  if(trigger.operationType == TriggerOperation.BEFORE_INSERT ){
            ExpenseTriggerHandler.afterInsert(trigger.new);
        }
    else if(trigger.isUpdate)
    {
        if(Trigger.isAfter)
        {
            //ExpenseTriggerHandler.afterUpdate(trigger.new,trigger.oldMap);
        }
    }
}