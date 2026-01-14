trigger dailylogTrigger on Daily_Log__c (Before Update,After update) {
if(Trigger.isUpdate)
    { 
        if(trigger.isBefore)
        {
            dailylogTriggerHandler.beforeUpdate(Trigger.new,trigger.oldMap);
        }
        else if(trigger.isAfter)
        {
            dailylogTriggerHandler.afterUpdate(Trigger.new,trigger.oldMap);
        }
    }
}