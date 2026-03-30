// Product Master Trigger - Module 7
/****************************************************************
* Trigger Name : ProductTrigger
* Company      : Fingertipplus
* Created Date : 30-03-2026
* @description : Trigger on Product2 for duplicate prevention and
*                active status sync per BRD Module 7.
**************************************************************/
trigger ProductTrigger on Product2 (before insert, before update) {

    if (Trigger.isBefore && Trigger.isInsert) {
        ProductTriggerHandler.handleBeforeInsert(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        ProductTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
}
