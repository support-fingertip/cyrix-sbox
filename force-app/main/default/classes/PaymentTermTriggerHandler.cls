public with sharing class PaymentTermTriggerHandler {
    
    /**
     * Validates that total percentage for each Quote does not exceed 100%
     * Called before insert / update.
     */
    public static void validatePercentages(List<Payment_Term__c> newTerms, Map<Id, Payment_Term__c> oldMap) {
        // Collect all Quote IDs involved
        Set<Id> quoteIds = new Set<Id>();
        for (Payment_Term__c term : newTerms) {
            if (term.Quote__c != null) {
                quoteIds.add(term.Quote__c);
            }
        }
        
        if (quoteIds.isEmpty()) return;
        
        // Get existing percentages for these Quotes (excluding the records being updated)
        Map<Id, Decimal> existingTotalMap = getExistingTotals(quoteIds, newTerms, oldMap);
        
        // Calculate new totals and validate
        for (Payment_Term__c term : newTerms) {
            Id qId = term.Quote__c;
            if (qId == null) continue;
            
            Decimal currentTotal = existingTotalMap.containsKey(qId) ? existingTotalMap.get(qId) : 0;
            Decimal newPercentage = term.Percentage__c != null ? term.Percentage__c : 0;
            
            // For updates, subtract the old percentage if it exists
            if (Trigger.isUpdate && oldMap != null && oldMap.containsKey(term.Id)) {
                Payment_Term__c oldTerm = oldMap.get(term.Id);
                Decimal oldPercentage = oldTerm.Percentage__c != null ? oldTerm.Percentage__c : 0;
                currentTotal -= oldPercentage;
            }
            
            Decimal newTotal = currentTotal + newPercentage;
            
            if (newTotal > 100) {
                term.addError('Total payment percentage for this Quote cannot exceed 100%. Current total would be ' + newTotal + '%.');
            }
        }
    }
    
    /**
     * Validates before deletion: after removing the term, total percentage should still be <= 100%
     * (It will always be less than or equal to before deletion, so this is mainly a safety check.
     *  We allow deletion even if total was >100% before? Usually you should allow deletion to fix.
     *  This method is optional; you can skip deletion validation.)
     */
    public static void validatePercentagesOnDelete(List<Payment_Term__c> oldTerms) {
        // Deletion always reduces total, so no error needed unless you want to prevent deletion when total would become negative? Not needed.
        // But we can add a check to prevent deletion if it would cause some other issue – not required.
        // This method is kept for completeness.
    }
    
    // Helper: get current total percentage per Quote, excluding the records being updated
    private static Map<Id, Decimal> getExistingTotals(Set<Id> quoteIds, List<Payment_Term__c> newTerms, Map<Id, Payment_Term__c> oldMap) {
        Map<Id, Decimal> totalMap = new Map<Id, Decimal>();
        
        // Initialize with zero
        for (Id qId : quoteIds) {
            totalMap.put(qId, 0);
        }
        
        // Aggregate all existing Payment Terms for these Quotes
        for (AggregateResult ar : [
            SELECT Quote__c, SUM(Percentage__c) total
            FROM Payment_Term__c
            WHERE Quote__c IN :quoteIds
            GROUP BY Quote__c
        ]) {
            Id qId = (Id) ar.get('Quote__c');
            Decimal total = (Decimal) ar.get('total');
            totalMap.put(qId, total != null ? total : 0);
        }
        
        // Subtract the percentages of records that are being updated (their old values are already counted)
        if (Trigger.isUpdate && oldMap != null) {
            for (Payment_Term__c term : newTerms) {
                if (oldMap.containsKey(term.Id)) {
                    Payment_Term__c oldTerm = oldMap.get(term.Id);
                    Id qId = term.Quote__c;
                    Decimal oldPercentage = oldTerm.Percentage__c != null ? oldTerm.Percentage__c : 0;
                    Decimal current = totalMap.get(qId);
                    totalMap.put(qId, current - oldPercentage);
                }
            }
        }
        
        return totalMap;
    }
}