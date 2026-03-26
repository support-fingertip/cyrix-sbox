public with sharing class OpportunityDocUploadController {

    private static final Map<String, String> DOC_TYPE_TO_FIELD = new Map<String, String>{
        'WO'     => 'WO_Uploaded__c',
        'PO'     => 'PO_Uploaded__c',
        'Cheque' => 'Cheque_Uploaded__c',
        'DD'     => 'DD_Uploaded__c',
        'Cash'   => 'Cash_Uploaded__c',
        'UPI'    => 'UPI_Uploaded__c'
    };

    @AuraEnabled
    public static void handleDocumentUpload(String opportunityId, String documentType) {
        if (String.isBlank(opportunityId) || String.isBlank(documentType)) return;

        String fieldName = DOC_TYPE_TO_FIELD.get(documentType);
        if (fieldName == null) return;

        Opportunity opp = new Opportunity(Id = opportunityId);
        opp.put(fieldName, true);

        try {
            update opp;
        } catch (Exception ex) {
            ExceptionHandler.addLog(ex, opportunityId, 'OpportunityDocUploadController', 'handleDocumentUpload');
            throw new AuraHandledException('Failed to update document checkbox: ' + ex.getMessage());
        }
    }

    @AuraEnabled
    public static void renameUploadedFile(String opportunityId, String documentType) {
        if (String.isBlank(opportunityId) || String.isBlank(documentType)) return;

        List<ContentDocumentLink> cdlList = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :opportunityId
            ORDER BY ContentDocument.CreatedDate DESC
            LIMIT 1
        ];

        if (cdlList.isEmpty()) return;

        ContentVersion cv = [
            SELECT Id, Title, FileExtension
            FROM ContentVersion
            WHERE ContentDocumentId = :cdlList[0].ContentDocumentId
            AND IsLatest = true
            LIMIT 1
        ];

        if (cv == null) return;

        String dateSuffix = Datetime.now().format('yyyy-MM-dd');
        cv.Title = documentType + '_' + dateSuffix;

        try {
            update cv;
        } catch (Exception ex) {
            ExceptionHandler.addLog(ex, opportunityId, 'OpportunityDocUploadController', 'renameUploadedFile');
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Boolean> getDocumentStatus(String opportunityId) {
        Opportunity opp = [
            SELECT WO_Uploaded__c, PO_Uploaded__c, Cheque_Uploaded__c,
                   DD_Uploaded__c, Cash_Uploaded__c, UPI_Uploaded__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        return new Map<String, Boolean>{
            'WO'     => opp.WO_Uploaded__c,
            'PO'     => opp.PO_Uploaded__c,
            'Cheque' => opp.Cheque_Uploaded__c,
            'DD'     => opp.DD_Uploaded__c,
            'Cash'   => opp.Cash_Uploaded__c,
            'UPI'    => opp.UPI_Uploaded__c
        };
    }
}
