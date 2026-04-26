/**
 * Backs the "Send to SAP" quick action on Account and Order. Today
 * it just flags the record (Sync_To_SAP__c = true) so a downstream
 * integration job can pick it up. When the SAP REST callout is built,
 * drop it into the per-object branches below.
 */
public with sharing class SapSyncController {

    @AuraEnabled
    public static String sendToSap(Id recordId) {
        if (recordId == null) {
            return 'ERROR: No record id provided';
        }

        String objectType = recordId.getSObjectType().getDescribe().getName();

        try {
            if (objectType == 'Account') {
                update new Account(Id = recordId, Sync_To_SAP__c = true);
                return 'Customer sent successfully';
            } else if (objectType == 'Order') {
                update new Order(Id = recordId, Sync_To_SAP__c = true);
                return 'Order sent successfully';
            } else {
                return 'ERROR: Unsupported object: ' + objectType;
            }
        } catch (Exception e) {
            return 'ERROR: ' + e.getMessage();
        }
    }
}
