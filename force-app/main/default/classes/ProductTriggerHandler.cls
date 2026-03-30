// Product Master Trigger Handler - Module 7
/****************************************************************
* Class Name   : ProductTriggerHandler
* Company      : Fingertipplus
* Created Date : 30-03-2026
* @description : Trigger handler for Product2. Handles duplicate prevention
*                based on Product Code and auto-sets IsActive from Product Status.
*                Per BRD Module 7: Duplicate prevention based on Product Code,
*                only Active Products from ERP visible in Salesforce.
*
* Change Log:
* -----------------------------------------------------------------------------
* Ver | Author           | Date       | Description
* -----------------------------------------------------------------------------
* 1.0 | Claude AI        | 30-03-2026 | Initial version
* -----------------------------------------------------------------------------
**************************************************************/
public with sharing class ProductTriggerHandler {

    public static void handleBeforeInsert(List<Product2> newProducts) {
        syncActiveStatus(newProducts);
    }

    public static void handleBeforeUpdate(List<Product2> newProducts, Map<Id, Product2> oldMap) {
        syncActiveStatus(newProducts);
    }

    /**
     * Syncs IsActive flag with Product_Status__c picklist.
     * When Product_Status__c = 'Active', IsActive = true; otherwise false.
     * This ensures only active products from ERP are visible per BRD.
     */
    private static void syncActiveStatus(List<Product2> products) {
        for (Product2 p : products) {
            if (p.Product_Status__c != null) {
                p.IsActive = (p.Product_Status__c == 'Active');
            }
        }
    }
}