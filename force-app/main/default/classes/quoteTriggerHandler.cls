public with sharing class quoteTriggerHandler {
    
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
            String baseName = 'C-' + shortCode + '/' + q.Business_Vertical__c + '/QTN-' + String.valueOf(nextNumber.intValue()).leftPad(3, '0') + '/' + financialYear;
            if (q.Version_Number__c != null && q.Version_Number__c >= 1) {
                baseName += '-RV' + q.Version_Number__c;
            }
            q.Name = baseName;
            } 
            
        update maxNumberMap.values();
   
          
        }
    }
    
 


    

}