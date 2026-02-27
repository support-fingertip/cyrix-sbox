trigger Customer_Trigger on Account (before update, after insert) {
    /* ---------------- BEFORE UPDATE ---------------- */
    if(trigger.isBefore && trigger.isUpdate){

        CustomerTriggerHandler.handleBeforeUpdate(
            trigger.new,
            trigger.oldMap
        );
    }

    /* ---------------- AFTER INSERT ---------------- */
    if(trigger.isAfter && trigger.isInsert){

        CustomerTriggerHandler.handleAfterInsert(
            trigger.new
        );
    }

}