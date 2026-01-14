public class LightningFileUploadHandler1 {
    
    //Roopesh 22/10/2025
    @AuraEnabled  
    public static List<ContentDocument> getFiles(String recordId,string uniqueId,String operation){ 
        try {
            system.debug('recordId' + recordId);
            List<ContentDocumentLink> cdlList = [SELECT Id, LinkedEntityId, ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId=:recordId];                         
            Set<Id> documentIds = new Set<Id>(); 
            for(ContentDocumentLink cdl: cdlList) {  
                documentIds.add(cdl.ContentDocumentId);  
            }  
            
            if(documentIds.size() > 0) {
                //Once After uploade for Account file we are updating the Description as uniqueId
                if(uniqueId != null && uniqueId != '') {
                    if(operation =='OnUpload')
                    {      
                        ContentVersion version = [SELECT Id, Title,Description FROM ContentVersion WHERE ContentDocumentId IN :documentIds ORDER BY CreatedDate DESC LIMIT 1];
                        if (version != null) {
                            version.Description = uniqueId;
                            update version;
                        }
                    }
             
                    system.debug('entered' + uniqueId);
                    return [SELECT Id, Title, FileType FROM ContentDocument 
                            WHERE Id IN (SELECT ContentDocumentId FROM ContentVersion WHERE Description = :uniqueId)
                            AND ContentAssetId = null];
                  
                }
                else
                {
                    system.debug('entered12');
                    
                    return [SELECT Id, Title, FileType FROM ContentDocument WHERE Id IN :documentIds AND ContentAssetId  = null ]; 
                }
                
               
            }
        } catch(Exception e) {
            system.debug('An error occurred: ' + e.getMessage());
        }
        List<ContentDocument> contentList = new List<ContentDocument>();
        return contentList;
        
        
    } 
    
    @AuraEnabled  
    public static void deleteFile(String contentDocumentId){ 
        delete [SELECT Id from ContentDocument WHERE Id = :contentDocumentId];       
    }  
}