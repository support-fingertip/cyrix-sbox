public class ExpenseLineItemTriggerHandler {
    public static void afterInsert(List<Expenses_Line_Item__c> newExpenseItems) {
        Set<String> uniqueFileIds = new Set<String>();
        Map<String, Id> expItemIdMap = new Map<String, Id>();

        // Collect all unique file IDs from new accounts
        for (Expenses_Line_Item__c expItem : newExpenseItems) {
            if (expItem.localId__c != null) {
                uniqueFileIds.add(expItem.localId__c);
                expItemIdMap.put(expItem.localId__c, expItem.Id);
            }
        }
        
        if (!uniqueFileIds.isEmpty()) {
            // Query files with matching unique IDs
            List<ContentDocument> files = [
                SELECT Id, Description 
                FROM ContentDocument 
                WHERE Description IN :uniqueFileIds
            ];
            system.debug('files'+files);
            
            List<ContentDocumentLink> fileLinks = new List<ContentDocumentLink>();
            // Link each file to the correct account
            for (ContentDocument file : files) {
                if (expItemIdMap.containsKey(file.Description)) {
                    ContentDocumentLink link = new ContentDocumentLink();
                    link.ContentDocumentId = file.Id;
                    link.LinkedEntityId = expItemIdMap.get(file.Description);
                    link.ShareType = 'V';
                    link.Visibility = 'AllUsers';
                    fileLinks.add(link);
                }
            }
            
            if (!fileLinks.isEmpty()) {
                insert fileLinks;
            }
        }
        
    }
}