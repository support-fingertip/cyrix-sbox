/**
 * Outbound SAP send orchestrator. Mirrors the SAPsend_TriggerHandler
 * pattern from the reference project. Used by the Send to SAP LWC.
 *
 * Entry point for the LWC quick action:
 *   SendToSAP_call(recordId) -> Integer status code
 *     1 = send request submitted
 *     2 = record didn't qualify (already synced)
 *     0 = unsupported object / no record
 *
 * The actual HTTP callout is fired asynchronously via @Future on
 * sendToSap(...), which delegates to SapServiceHelper.sendData().
 */
public without sharing class SAPsend_TriggerHandler {

    /**
     * Called from the Send to SAP quick action LWC. Validates the
     * record, fires the @Future callout, and returns a status code
     * the LWC turns into a toast.
     */
    @AuraEnabled
    public static Integer SendToSAP_call(Id recordId) {
        if (recordId == null) {
            return 0;
        }

        String objName = recordId.getSObjectType().getDescribe().getName();

        Integer eligibleCount = 0;
        if (objName == 'Account') {
            eligibleCount = [
                SELECT COUNT()
                FROM Account
                WHERE Id = :recordId AND Sync_To_SAP__c = false
            ];
        } else if (objName == 'Order') {
            eligibleCount = [
                SELECT COUNT()
                FROM Order
                WHERE Id = :recordId AND Sync_To_SAP__c = false
            ];
        } else {
            return 0;
        }

        if (eligibleCount == 0) {
            // Already sent or doesn't exist for this user.
            return 2;
        }

        sendToSap(new List<Id>{ recordId }, objName);
        return 1;
    }

    /**
     * Async worker — queries the record(s) with the SAP-relevant
     * field set and hands the data to SapServiceHelper for the
     * actual POST callout.
     */
    @Future(callout=true)
    public static void sendToSap(List<Id> recIds, String ObjectName) {
        List<SObject> objData = new List<SObject>();

        if (ObjectName == 'Account') {
            objData = [
                SELECT Id, Name, Phone, Website,
                       BillingStreet, BillingCity, BillingState, BillingStateCode,
                       BillingPostalCode, BillingCountry, BillingCountryCode,
                       ShippingStreet, ShippingCity, ShippingState, ShippingStateCode,
                       ShippingPostalCode, ShippingCountry, ShippingCountryCode,
                       GST_Number__c, PAN_Number__c,
                       SAP_Code__c, Sync_To_SAP__c
                FROM Account
                WHERE Id IN :recIds
            ];
        } else if (ObjectName == 'Order') {
            objData = [
                SELECT Id, Name, OrderNumber, EffectiveDate, EndDate, Status, TotalAmount,
                       CurrencyIsoCode, Description,
                       BillingStreet, BillingCity, BillingState, BillingStateCode,
                       BillingPostalCode, BillingCountry, BillingCountryCode,
                       ShippingStreet, ShippingCity, ShippingState, ShippingStateCode,
                       ShippingPostalCode, ShippingCountry, ShippingCountryCode,
                       Business_Vertical__c,
                       Contract_Period_From_Date__c, Contract_Period_End_Date__c,
                       Delivery__c,
                       SAP_Code__c, Sync_To_SAP__c,
                       AccountId, Account.Name, Account.SAP_Code__c,
                       (SELECT Id, OrderItemNumber, Product2.ProductCode,
                               Quantity, UnitPrice, TotalPrice
                        FROM OrderItems),
                       (SELECT Id, Name, Payment_Term__c, Percentage__c
                        FROM Payment_Terms__r)
                FROM Order
                WHERE Id IN :recIds
            ];
        }

        if (objData.isEmpty()) {
            return;
        }

        try {
            SapServiceHelper.sendData(objData);
        } catch (Exception ex) {
            System.debug('SAPsend_TriggerHandler.sendToSap error: ' + ex.getMessage());
        }
    }
}
