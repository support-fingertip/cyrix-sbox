trigger QuoteTrigger on Quote (before insert, before update, after insert, after update) {
    if(trigger.isBefore && trigger.isInsert ){

        // Skip default stamping for clone-inserts coming from the snapshot logic.
        if (!quoteTriggerHandler.bypassInsertDefaults) {
            Branch__c b =[select Id from Branch__c limit 1 ];
            for(Quote q :trigger.New){
                q.branch__c=b.Id;
                q.Version_Nmber__c=0;
                integer numberofDays =integer.valueof(q.Quote_Valid_Till_in_days__c);
                date todayDate =system.today();
                q.Valid_Till__c = todayDate.addDays(numberofDays);
                q.ExpirationDate =todayDate.addDays(numberofDays);
            }
            // Generate names for new quotes and for quotes where Branch or Revision_Number changed
            quoteTriggerHandler.generateQuoteNames(Trigger.new);
        }
    }
    if(trigger.isBefore && trigger.isUpdate){
         for(Quote q :trigger.New){
             // If the quote's sync link to the opportunity was turned off,
             // it is no longer the active quote.
             Quote oldQ = trigger.oldMap.get(q.Id);
             if (oldQ != null && oldQ.IsSyncing == true && q.IsSyncing == false && q.is_Active__c == true) {
                 q.is_Active__c = false;
             }
             if(q.Status =='Revision' &&q.Status  !=trigger.oldMap.get(q.Id).Status){
                 // Reason for Revision is mandatory when moving a quote into Revision.
                 if (String.isBlank(q.Reason_for_Revision__c)) {
                     q.addError('Reason for Revision is required when marking a quote as Revised.');
                     continue;
                 }
                 // Queue this record so after-update can create a historical
                 // snapshot clone (quote + all child records) before the
                 // in-place version bump overwrites the original name.
                 quoteTriggerHandler.quotesPendingSnapshot.add(q.Id);

                 q.Version_Nmber__c =q.Version_Nmber__c ==null?0 :(q.Version_Nmber__c+1);
                     q.Status='Draft';
                 q.Revised_Date__c =system.today();
                 integer VersionNmber = integer.valueof(q.Version_Nmber__c);
                 if(VersionNmber != null && VersionNmber == 1){
                       q.Name= q.Name+'-RV'+ VersionNmber;
                   }else if (VersionNmber != null && VersionNmber > 1) {
                 string oldversionNumber ='-RV'+trigger.oldMap.get(q.Id).Version_Nmber__c;
                   string newversionNumber ='-RV'+ VersionNmber;
                 q.Name = q.Name.replace(oldversionNumber,newversionNumber);
                   }
             }
        }
    }

    // When a quote is marked active, deactivate all siblings on the same opportunity
    // and sync this quote to the opportunity (sets Opportunity.SyncedQuoteId).
    if (trigger.isAfter && (trigger.isInsert || trigger.isUpdate)) {
        quoteTriggerHandler.syncActiveQuote(trigger.new, trigger.oldMap);
    }

    // Clone quote + children as a historical snapshot when Status flipped to 'Revision'.
    if (trigger.isAfter && trigger.isUpdate) {
        quoteTriggerHandler.snapshotQuotesOnRevision(trigger.oldMap);
    }
}
