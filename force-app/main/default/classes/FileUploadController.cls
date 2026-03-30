public with sharing class FileUploadController {

    private static final String ISSUE_UPLOADING_FILE = 'There is a problem in uploading the file';

    // Mapping of document names to their corresponding Opportunity checkbox fields
    private static final Map<String, String> DOCUMENT_FIELD_MAP = new Map<String, String>{
        'WO' => 'WO_Uploaded__c',
        'PO' => 'PO_Uploaded__c',
        'Cheque' => 'Cheque_Uploaded__c',
        'DD' => 'DD_Uploaded__c',
        'Cash' => 'Cash_Uploaded__c',
        'UPI' => 'UPI_Uploaded__c'
    };

    @AuraEnabled
    public static String fileUpload(String parentId, String name, String fileType, String fileData, String documentName) {
        list < ContentDocumentLink > conLinks = new list < ContentDocumentLink > ();


        try {
            System.debug('**Uploading File: ' + documentName + '**');

            // Ensure parentId is valid
            if (String.isEmpty(parentId)) {
                throw new AuraHandledException('Parent Record ID is required.');
            }

            // Step 1: Check if the file already exists
            List < ContentDocument > existingDocs = [
                SELECT Id FROM ContentDocument
                WHERE Title =: documentName
                ORDER BY LatestPublishedVersionId DESC
                LIMIT 1
            ];

            // Append current date to the file title (e.g., WO-2026-03-26)
            String todayDate = String.valueOf(Date.today());
            String fileTitle = documentName + '-' + todayDate;

            ContentVersion fileVersion = new ContentVersion();
            fileVersion.Title = fileTitle;
            fileVersion.PathOnClient = name;
            fileVersion.VersionData = EncodingUtil.base64Decode(fileData);

            /* if (!existingDocs.isEmpty()) {
// If the file exists, create a new version
fileVersion.ContentDocumentId = existingDocs[0].Id;
} else {*/
            // For new files, set FirstPublishLocationId to link it to the parent record
            fileVersion.FirstPublishLocationId = parentId;
            //}

            insert fileVersion;
            System.debug('**FileVersion Inserted: ' + fileVersion.Id + '**');

            // Fetch ContentDocumentId from the inserted ContentVersion
            ContentDocument newDoc = [
                SELECT Id FROM ContentDocument
                WHERE LatestPublishedVersionId =: fileVersion.Id
                LIMIT 1
            ];
            String newDocId = newDoc.Id;
            Id reordId = parentId;
            String sObjName = reordId.getSObjectType().getDescribe().getName();


            // Step 2: Always link the document to the parent record

            ContentDocumentLink newLink = new ContentDocumentLink();
            newLink.LinkedEntityId = parentId;
            newLink.ShareType = 'V';
            newLink.ContentDocumentId = newDocId;
            newLink.Visibility = 'AllUsers';
            conLinks.add(newLink);
            //  System.debug('**ContentDocumentLink Created: ' + newLink.Id + '**');
            database.insert(conLinks, false);
            System.debug('**File Successfully Uploaded and Linked**');

            // Step 3: Update the corresponding Opportunity checkbox field
            if (sObjName == 'Opportunity' && String.isNotEmpty(documentName)) {
                updateOpportunityUploadField(parentId, documentName.trim());
            }

            return newDocId;

        } catch (Exception ex) {
            System.debug('### Exception Details ###');
            System.debug('Line Number: ' + ex.getLineNumber());
            System.debug('Error Message: ' + ex.getMessage());
            System.debug('Stack Trace: ' + ex.getStackTraceString());
            throw new AuraHandledException('Exception: ' + ex.getMessage() + ' on Line Number: ' + ex.getLineNumber());
        }
    }


    @AuraEnabled
    public static String multifileUpload(String parentId, String name, String fileType, String fileData, String documentName, Boolean isPicklist) {
        try {
            System.debug('**Uploading File: ' + name + '**');

            // Ensure parentId is valid
            if (String.isEmpty(parentId)) {
                throw new AuraHandledException('Parent Record ID is required.');
            }

            // Step 1: Create a new ContentVersion object without versioning
            ContentVersion fileVersion = new ContentVersion();
            fileVersion.Title = isPicklist == true ? documentName : documentName + '-' + name; // Use 'name' as the title
            fileVersion.PathOnClient = name;
            fileVersion.VersionData = EncodingUtil.base64Decode(fileData);

            // Set the FirstPublishLocationId to link it to the parent record
            fileVersion.FirstPublishLocationId = parentId;

            insert fileVersion;
            System.debug('**FileVersion Inserted: ' + fileVersion.Id + '**');

            // Fetch ContentDocumentId from the inserted ContentVersion
            ContentDocument newDoc = [
                SELECT Id FROM ContentDocument
                WHERE LatestPublishedVersionId =: fileVersion.Id
                LIMIT 1
            ];
            String newDocId = newDoc.Id;

            System.debug('**ContentDocumentId Retrieved: ' + newDocId + '**');

            // Step 2: Always link the document to the parent record
            try {
                ContentDocumentLink newLink = new ContentDocumentLink();
                newLink.LinkedEntityId = parentId;
                newLink.ShareType = 'C';
                newLink.ContentDocumentId = newDocId;
                insert newLink;
                System.debug('**ContentDocumentLink Created: ' + newLink.Id + '**');
            } catch (DmlException linkEx) {
                System.debug('Link may already exist. DML Error: ' + linkEx.getMessage());
            }

            System.debug('**File Successfully Uploaded and Linked**');

            // Confirm that the file is available in ContentDocument
            ContentDocument verifyDoc = [SELECT Id, Title FROM ContentDocument WHERE Id =: newDocId LIMIT 1];
            System.debug('**File Verified: ' + verifyDoc.Title + '**');

            return newDocId;

        } catch (Exception ex) {
            System.debug('### Exception Details ###');
            System.debug('Line Number: ' + ex.getLineNumber());
            System.debug('Error Message: ' + ex.getMessage());
            System.debug('Stack Trace: ' + ex.getStackTraceString());
            throw new AuraHandledException('Exception: ' + ex.getMessage() + ' on Line Number: ' + ex.getLineNumber());
        }
    }


    // Wrapper class for returning file metadata
    public class FileWrapper {
        @AuraEnabled public String fileId;
        @AuraEnabled public String title;
        @AuraEnabled public String fileExtension;
        @AuraEnabled public String previewUrl;
        @AuraEnabled public String downloadUrl;

        public FileWrapper(ContentDocumentLink docLink) {
            this.fileId = docLink.ContentDocumentId;
            this.title = docLink.ContentDocument.Title;
            this.fileExtension = docLink.ContentDocument.FileExtension;
            this.previewUrl = '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB120BY90&versionId=' + docLink.ContentDocument.LatestPublishedVersionId;
            this.downloadUrl = '/sfc/servlet.shepherd/document/download/' + docLink.ContentDocumentId;
        }
    }
    @AuraEnabled
    public static List < FileWrapper > getFiles(String recordId, String fileName, String documentList) {
        List < FileWrapper > files = new List < FileWrapper > ();

        // Split the documentList string into a list of document names (if provided)
        Set < String > documentNamesSet = new Set < String > ();
        if (!String.isEmpty(documentList)) {
            documentNamesSet = new Set < String > (documentList.split(','));
        }

        // Build the query filter based on documentNamesSet
        String queryFilter = 'WHERE LinkedEntityId = :recordId';

        // If fileName is provided, use LIKE to match titles with date suffix (e.g., WO-2026-03-26)
        String fileNameFilter;
        if (!String.isEmpty(fileName)) {
            fileNameFilter = fileName.trim() + '%';
            queryFilter += ' AND ContentDocument.Title LIKE :fileNameFilter';
        }

        //If documentList is provided, build LIKE conditions for each document name
        if (!documentNamesSet.isEmpty() && String.isEmpty(fileName)) {
            List<String> likeClauses = new List<String>();
            for (String docName : documentNamesSet) {
                likeClauses.add('ContentDocument.Title LIKE \'' + String.escapeSingleQuotes(docName.trim()) + '%\'');
            }
            queryFilter += ' AND (' + String.join(likeClauses, ' OR ') + ')';
        }

        // Query for the documents with the dynamic filter
        List < ContentDocumentLink > documentLinks = Database.query(
            'SELECT Id, LinkedEntityId, ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension, ContentDocument.LatestPublishedVersionId ' +
            'FROM ContentDocumentLink ' + queryFilter + ' ORDER BY ContentDocument.CreatedDate DESC'
        );

        // Loop through the documents and add them to the list if they match the filter criteria
        for (ContentDocumentLink docLink: documentLinks) {
            files.add(new FileWrapper(docLink));
        }
        return files;
    }


    @AuraEnabled
    public static List < FileWrapper > getMultiFiles(String recordId, String fileName) {
        List < FileWrapper > files = new List < FileWrapper > ();

        // Construct the SOQL query with LIKE operator for fileName to match starting string
        String fileNameFilter = String.isEmpty(fileName) ? '%' : fileName + '%';

        List < ContentDocumentLink > documentLinks = [
            SELECT Id, LinkedEntityId, ContentDocumentId,
            ContentDocument.Title, ContentDocument.FileExtension,
            ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId =: recordId
            AND ContentDocument.Title LIKE: fileNameFilter ORDER BY ContentDocument.CreatedDate DESC
        ];

        for (ContentDocumentLink docLink: documentLinks) {
            files.add(new FileWrapper(docLink));
        }

        return files;
    }
    @AuraEnabled
    public static void deleteFileFromSalesforce(String fileId) {
        try {
            // Fetch the ContentDocument using the ContentDocumentId (fileId)
            ContentDocument contentDoc = [SELECT Id FROM ContentDocument WHERE Id =: fileId LIMIT 1];

            // Deleting the ContentDocument will also delete all associated ContentVersions
            delete contentDoc;

            // Log success
            System.debug('File successfully deleted: ' + contentDoc.Id);

        } catch (Exception e) {
            // Handle any errors
            throw new AuraHandledException('Error deleting file: ' + e.getMessage());
        }
    }
    /**
     * Updates the corresponding upload checkbox field on the Opportunity
     * when a document of type WO, PO, Cheque, DD, Cash, or UPI is uploaded.
     */
    private static void updateOpportunityUploadField(String opportunityId, String documentName) {
        String fieldName = DOCUMENT_FIELD_MAP.get(documentName);
        if (fieldName != null) {
            Opportunity opp = new Opportunity(Id = opportunityId);
            opp.put(fieldName, true);
            update opp;
            System.debug('**Opportunity field ' + fieldName + ' set to true**');
        }
    }

@AuraEnabled(cacheable=true)
public static Map<ID, String> getRelatedFilesByRecordId(String recordId, String fileName, String documentList) {
    // Initialize map to store filtered file IDs and titles
    Map<ID, String> mapIdTitle = new Map<ID, String>();

    // Split documentList into a set of document names (if provided)
    Set<String> documentNamesSet = new Set<String>();
    if (!String.isEmpty(documentList)) {
        documentNamesSet = new Set<String>(documentList.split(','));
    }

    // Build the query filter based on documentNamesSet
    String queryFilter = 'WHERE LinkedEntityId = :recordId';
    
    // If fileName is provided, adjust it to match any file extensions (.pdf, .png, etc.)
    if (!String.isEmpty(fileName)) {
        // Ensure fileName includes wildcards for possible extensions
        fileName = fileName.trim() + '%'; // match any extension after the file name
        
        // Apply fileName filter
        queryFilter += ' AND ContentDocument.Title LIKE :fileName';
    }
    
    // If documentList is provided but fileName is empty, add the filter for document names
    if (!documentNamesSet.isEmpty() && String.isEmpty(fileName)) {
        queryFilter += ' AND ContentDocument.Title IN :documentNamesSet';
    }

    // If both fileName and documentList are provided, filter by both conditions
    if (!String.isEmpty(fileName) && !documentNamesSet.isEmpty()) {
        queryFilter += ' AND ContentDocument.Title LIKE :fileName AND ContentDocument.Title IN :documentNamesSet';
    }

    // Query for the documents with the dynamic filter
    List<ContentDocumentLink> documentLinks = Database.query(
        'SELECT Id, LinkedEntityId, ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension, ContentDocument.LatestPublishedVersionId ' +
        'FROM ContentDocumentLink ' + queryFilter + ' ORDER BY ContentDocument.CreatedDate DESC'
    );
    
    // Loop through the documents and add them to the map if they match the filter criteria
    for (ContentDocumentLink docLink : documentLinks) {
        mapIdTitle.put(docLink.ContentDocumentId, docLink.ContentDocument.Title);
    }

    return mapIdTitle;
}




}