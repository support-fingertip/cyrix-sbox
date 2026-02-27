public class LightningFileUploadHandler {
	@AuraEnabled  
    public static List<ContentDocument> getFiles(String recordId){ 
        if(recordId != null)
        {
            System.debug('recordId'+recordId);
            Id linkedEntityId = recordId;
            Set<Id> linkedEntityIds = new Set<Id>(); 
            linkedEntityIds.add(recordId);  
            List<ContentDocumentLink> contentDocumentLinks = [SELECT Id, ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId In: linkedEntityIds];
            
            Set<Id> documentIds = new Set<Id>(); 
            
            for(ContentDocumentLink cdl:contentDocumentLinks){  
                documentIds.add(cdl.ContentDocumentId);  
            }    
            return [SELECT Id, Title, FileType FROM ContentDocument WHERE Id IN :documentIds];      
        }
        return null;     
        
    } 
    
    @AuraEnabled  
    public static void deleteFile(String contentDocumentId){ 
        delete [SELECT Id from ContentDocument WHERE Id = :contentDocumentId];       
    }  
}