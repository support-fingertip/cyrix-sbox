// QuoteLineItemTrigger wires QuoteLineItemTriggerHandler to DML events:
//   Before insert/update: stamp Tax__c, Source_Pricebook_Ref__c, and
//                          Price_Status__c from the tier model. Without
//                          this, Price_Status__c revert to picklist
//                          default after save — so the UI preview shows
//                          Approval Required but the saved row does not.
//   After insert/update/delete: roll Price_Status__c up to the parent Quote.
trigger QuoteLineItemTrigger on QuoteLineItem (before insert, before update, after insert, after update, after delete, after undelete) {
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        QuoteLineItemTriggerHandler.beforeInsertOrUpdate(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isAfter) {
        Set<Id> quoteIds = new Set<Id>();
        if (Trigger.new != null) {
            for (QuoteLineItem qli : Trigger.new) {
                if (qli.QuoteId != null) quoteIds.add(qli.QuoteId);
            }
        }
        if (Trigger.old != null) {
            for (QuoteLineItem qli : Trigger.old) {
                if (qli.QuoteId != null) quoteIds.add(qli.QuoteId);
            }
        }
        if (!quoteIds.isEmpty()) {
            QuoteLineItemTriggerHandler.afterChange(quoteIds);
        }
    }
}