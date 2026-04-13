public with sharing class quoteTriggerHandler {

    // Prevents recursion when the sibling-deactivation DML re-fires the after update trigger.
    private static Boolean isSyncingActiveQuote = false;

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
    
 


    

}