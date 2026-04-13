public with sharing class quoteTriggerHandler {

    // Prevents recursion when the sibling-deactivation DML re-fires the after update trigger.
    private static Boolean isSyncingActiveQuote = false;

    // Set by the trigger so generateQuoteNames and other before-insert defaults
    // skip records that were inserted by our snapshot-clone logic.
    public static Boolean bypassInsertDefaults = false;

    // Quote Ids queued by before-update when the user flips Status to 'Revision'.
    // Processed in after-update to insert historical snapshots with their children.
    public static Set<Id> quotesPendingSnapshot = new Set<Id>();

    private static Boolean isSnapshotInProgress = false;

    /**
     * When a Quote flips is_Active__c to true, mark every other quote on the
     * same Opportunity as inactive and sync the current quote to the
     * Opportunity (Opportunity.SyncedQuoteId -> this Quote). Salesforce then
     * sets Quote.IsSyncing = true automatically on the synced quote.
     */
    public static void syncActiveQuote(List<Quote> newQuotes, Map<Id, Quote> oldMap) {
        if (isSyncingActiveQuote) return;

        Map<Id, Id> oppToActiveQuote = new Map<Id, Id>();
        for (Quote q : newQuotes) {
            if (q.OpportunityId == null || q.is_Active__c != true) continue;
            Boolean justActivated = (oldMap == null)
                || (oldMap.get(q.Id) != null && oldMap.get(q.Id).is_Active__c != true);
            if (justActivated) {
                // Last write wins if multiple quotes on the same opp are activated in one DML.
                oppToActiveQuote.put(q.OpportunityId, q.Id);
            }
        }
        if (oppToActiveQuote.isEmpty()) return;

        isSyncingActiveQuote = true;
        try {
            // Deactivate every other active quote on the impacted opportunities.
            List<Quote> siblings = [
                SELECT Id, OpportunityId, is_Active__c
                FROM Quote
                WHERE OpportunityId IN :oppToActiveQuote.keySet()
                AND Id NOT IN :oppToActiveQuote.values()
                AND is_Active__c = true
            ];
            if (!siblings.isEmpty()) {
                for (Quote s : siblings) s.is_Active__c = false;
                update siblings;
            }

            // Sync the active quote to the opportunity.
            List<Opportunity> oppsToSync = new List<Opportunity>();
            for (Id oppId : oppToActiveQuote.keySet()) {
                oppsToSync.add(new Opportunity(Id = oppId, SyncedQuoteId = oppToActiveQuote.get(oppId)));
            }
            update oppsToSync;
        } finally {
            isSyncingActiveQuote = false;
        }
    }

    /**
     * Generates the auto quote name for a list of Quote records.
     * Called from before insert and before update triggers.
     */
    public static void generateQuoteNames(List<Quote> newQuotes) {
        // Collect branches and financial years for which we need to calculate next numbers
        Set<String> branchYearKeys = new Set<String>();
        set<string> branchIds = new set<string>();
        for (Quote q : newQuotes) {
            // Only process if Branch is populated and Quote Name is empty (or needs regeneration)
            if (q.Branch__c == null) continue;
            branchIds.add(q.Branch__c);
            // Determine if we need to generate a new name
            Boolean needsNewName = false;
            if (Trigger.isInsert) {
                needsNewName = true;
            }
        }

        if (branchIds.isEmpty()) return;

        // Query existing quotes to find the current maximum sequential number per branch/year
        Map<String, Quote_Number_Series__c> maxNumberMap = new Map<String, Quote_Number_Series__c>();
        map<Id,Quote_Number_Series__c> quoteSeriesMap = new    map<Id,Quote_Number_Series__c> ([SELECT Branch__c, Name, Last_Quote_Number__c,Short_Code__c
            FROM Quote_Number_Series__c
            WHERE Branch__c IN :branchIds
            AND isActive__c=true]);
        for (Quote_Number_Series__c ar :quoteSeriesMap.values()) {
           maxNumberMap.put(ar.Branch__c, ar);
        }

        // Assign sequential numbers and build names
        for (Quote q : newQuotes) {
            if (q.Branch__c == null) continue;

            // Determine if this quote needs a name

            if (Trigger.isInsert) {
                  String key = q.Branch__c ;
            decimal nextNumber = maxNumberMap.containsKey(key) ? ((maxNumberMap.get(key).Last_Quote_Number__c !=null?maxNumberMap.get(key).Last_Quote_Number__c:0) + 1) : 1;
            maxNumberMap.get(key).Last_Quote_Number__c=nextNumber; // increment for next quote in same batch
           string  shortCode =maxNumberMap.get(key).Short_Code__c ;
            // Store the sequential number and financial year on the quote (for future queries)
            string financialYear =  maxNumberMap.get(key).Name;


            // Build the name
            String baseName = 'C-' + shortCode +'/'+q.Business_Vertical__c +'/QTN-' + String.valueOf(nextNumber.intValue()).leftPad(3, '0') + '/' + financialYear;
            if (q.Version_Nmber__c != null && q.Version_Nmber__c >= 1) {
                baseName += '-RV' + q.Version_Nmber__c;
            }
            q.Name = baseName;
            }

        update maxNumberMap.values();


        }
    }

    /**
     * When a user flips Quote.Status to 'Revision', insert a locked historical
     * snapshot of the quote *before* the existing before-update logic renames
     * the record and increments its version. The snapshot carries clones of
     * every child record the sales team keeps on a quote: line items, payment
     * terms, notes, exclusions, and terms & conditions.
     *
     * Clone-inserted quotes skip the before-insert defaults (name generation,
     * version reset, valid-till stamping) via the bypassInsertDefaults flag.
     */
    public static void snapshotQuotesOnRevision(Map<Id, Quote> oldMap) {
        if (isSnapshotInProgress) return;
        if (quotesPendingSnapshot == null || quotesPendingSnapshot.isEmpty()) return;

        List<Id> originalIds = new List<Id>(quotesPendingSnapshot);
        quotesPendingSnapshot.clear();

        isSnapshotInProgress = true;
        try {
            // Build snapshot Quote records from the pre-update (oldMap) values so the
            // snapshot carries the original Name/Version/Status, not the post-rename values.
            List<Quote> snapshots = new List<Quote>();
            List<Id> orderedOrigIds = new List<Id>();
            for (Id origId : originalIds) {
                Quote oldQ = oldMap.get(origId);
                if (oldQ == null) continue;
                Quote snap = oldQ.clone(false, true, false, false);
                snap.is_Active__c = false;
                snapshots.add(snap);
                orderedOrigIds.add(origId);
            }
            if (snapshots.isEmpty()) return;

            bypassInsertDefaults = true;
            insert snapshots;
            bypassInsertDefaults = false;

            Map<Id, Id> originalToSnapshot = new Map<Id, Id>();
            for (Integer i = 0; i < orderedOrigIds.size(); i++) {
                originalToSnapshot.put(orderedOrigIds[i], snapshots[i].Id);
            }

            // Clone QuoteLineItems
            List<QuoteLineItem> newQlis = new List<QuoteLineItem>();
            for (QuoteLineItem qli : [
                SELECT Id, QuoteId, Product2Id, PricebookEntryId, Quantity, UnitPrice,
                       Discount, Description, ServiceDate,
                       Source_Pricebook_Ref__c, Price_Status__c, Tax_Type__c,
                       Product_Line_Description__c, Product_Detailed_Description__c
                FROM QuoteLineItem
                WHERE QuoteId IN :orderedOrigIds
            ]) {
                QuoteLineItem n = new QuoteLineItem(
                    QuoteId = originalToSnapshot.get(qli.QuoteId),
                    Product2Id = qli.Product2Id,
                    PricebookEntryId = qli.PricebookEntryId,
                    Quantity = qli.Quantity,
                    UnitPrice = qli.UnitPrice,
                    Discount = qli.Discount,
                    Description = qli.Description,
                    ServiceDate = qli.ServiceDate,
                    Source_Pricebook_Ref__c = qli.Source_Pricebook_Ref__c,
                    Price_Status__c = qli.Price_Status__c,
                    Tax_Type__c = qli.Tax_Type__c,
                    Product_Line_Description__c = qli.Product_Line_Description__c,
                    Product_Detailed_Description__c = qli.Product_Detailed_Description__c
                );
                newQlis.add(n);
            }
            if (!newQlis.isEmpty()) insert newQlis;

            // Clone Payment_Term__c
            List<Payment_Term__c> newPts = new List<Payment_Term__c>();
            for (Payment_Term__c pt : [
                SELECT Id, Quote__c, Payment_Term__c, Percentage__c
                FROM Payment_Term__c
                WHERE Quote__c IN :orderedOrigIds
            ]) {
                Payment_Term__c n = pt.clone(false, true, false, false);
                n.Quote__c = originalToSnapshot.get(pt.Quote__c);
                newPts.add(n);
            }
            if (!newPts.isEmpty()) insert newPts;

            // Clone Notes__c
            List<Notes__c> newNotes = new List<Notes__c>();
            for (Notes__c nt : [
                SELECT Id, Quote__c, Note__c, Order_No__c
                FROM Notes__c
                WHERE Quote__c IN :orderedOrigIds
            ]) {
                Notes__c n = nt.clone(false, true, false, false);
                n.Quote__c = originalToSnapshot.get(nt.Quote__c);
                newNotes.add(n);
            }
            if (!newNotes.isEmpty()) insert newNotes;

            // Clone Exclusions__c
            List<Exclusions__c> newEx = new List<Exclusions__c>();
            for (Exclusions__c ex : [
                SELECT Id, Quote__c, Exclusions__c
                FROM Exclusions__c
                WHERE Quote__c IN :orderedOrigIds
            ]) {
                Exclusions__c n = ex.clone(false, true, false, false);
                n.Quote__c = originalToSnapshot.get(ex.Quote__c);
                newEx.add(n);
            }
            if (!newEx.isEmpty()) insert newEx;

            // Clone Terms_Condition__c
            List<Terms_Condition__c> newTcs = new List<Terms_Condition__c>();
            for (Terms_Condition__c tc : [
                SELECT Id, Quote__c, T_C__c, Titile__c
                FROM Terms_Condition__c
                WHERE Quote__c IN :orderedOrigIds
            ]) {
                Terms_Condition__c n = tc.clone(false, true, false, false);
                n.Quote__c = originalToSnapshot.get(tc.Quote__c);
                newTcs.add(n);
            }
            if (!newTcs.isEmpty()) insert newTcs;
        } finally {
            isSnapshotInProgress = false;
            bypassInsertDefaults = false;
        }
    }
}
