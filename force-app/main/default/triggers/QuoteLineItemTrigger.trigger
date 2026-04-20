trigger QuoteLineItemTrigger on QuoteLineItem (
    before insert, before update,
    after insert, after update, after delete, after undelete
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            QuoteLineItemTriggerHandler.beforeInsertOrUpdate(Trigger.new, null);
        } else if (Trigger.isUpdate) {
            QuoteLineItemTriggerHandler.beforeInsertOrUpdate(Trigger.new, Trigger.oldMap);
        }
    } else {
        Set<Id> quoteIds = new Set<Id>();
        if (Trigger.isDelete) {
            for (QuoteLineItem q : Trigger.old) {
                if (q.QuoteId != null) quoteIds.add(q.QuoteId);
            }
        } else {
            for (QuoteLineItem q : Trigger.new) {
                if (q.QuoteId != null) quoteIds.add(q.QuoteId);
            }
        }
        QuoteLineItemTriggerHandler.afterChange(quoteIds);
    }
}
