trigger PaymentTermsTrigger on Payment_Term__c (before insert, before update, before delete) {
    if (Trigger.isInsert || Trigger.isUpdate) {
        PaymentTermTriggerHandler.validatePercentages(Trigger.new, Trigger.oldMap);
    } else if (Trigger.isDelete) {
        PaymentTermTriggerHandler.validatePercentagesOnDelete(Trigger.old);
    }
}