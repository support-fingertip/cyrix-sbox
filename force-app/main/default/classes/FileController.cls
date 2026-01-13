//using in beatplanner
public with sharing class FileController {

     @AuraEnabled
    public static String saveFile(String parentId, String fileName, String base64Data,String uniqueId) {
        try {
            system.debug(base64Data);
            Blob body = EncodingUtil.base64Decode(base64Data);
            
            // Insert ContentVersion
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName+'-'+'Store-Image';
            cv.VersionData = body;
            cv.ContentLocation = 'S';
            cv.OwnerId = UserInfo.getUserId();
            if(uniqueId != null && uniqueId != '')
            {
                cv.Description = uniqueId;
            }
            
            cv.PathOnClient = fileName;
            insert cv;

            // Get the ContentDocumentId
            ContentVersion cvn = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            system.debug(cvn);

            // Check if the ContentDocument is already linked to the parentId
            Boolean isLinked = [
                SELECT Id FROM ContentDocumentLink 
                WHERE ContentDocumentId = :cvn.ContentDocumentId 
                AND LinkedEntityId = :parentId
                LIMIT 1
            ].size() > 0;

            if (!isLinked) { // Only insert if not already linked
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = cvn.ContentDocumentId;
                cdl.LinkedEntityId = parentId;
                cdl.ShareType = 'I';
                cdl.Visibility = 'AllUsers';
                insert cdl;
            }

            return cvn.ContentDocumentId;

        } catch (Exception e) {
            throw new AuraHandledException('Error saving file: ' + e.getMessage());
        }
    
}
}