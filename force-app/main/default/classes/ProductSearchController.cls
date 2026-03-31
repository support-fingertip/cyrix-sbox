// Cyrix Product Master Search Controller - Module 7.
/****************************************************************
* Class Name   : ProductSearchController
* Company      : Fingertipplus
* Created Date : 30-03-2026
* @description : Controller for Product search LWC component.
*                Allows users to search & select products from synced ERP list
*                for use in Opportunities, Quotes, and Orders per BRD Module 7.
*                Read-only access - no create/edit/delete in Salesforce.
*
* Change Log:
* -----------------------------------------------------------------------------
* Ver | Author           | Date       | Description
* -----------------------------------------------------------------------------
* 1.0 | Claude AI        | 30-03-2026 | Initial version
* -----------------------------------------------------------------------------
**************************************************************/
public with sharing class ProductSearchController {

    /**
     * Searches active products by keyword across Name, Item Code, Product Code,
     * Model, Equipment Name, and Description fields.
     * @param searchKey Search keyword (minimum 2 characters)
     * @param category Optional category filter
     * @param vertical Optional vertical filter
     * @param limitVal Maximum number of results (default 50)
     * @return List of matching active Product2 records
     */
    @AuraEnabled(cacheable=true)
    public static List<Product2> searchProducts(String searchKey, String category, String vertical, Integer limitVal) {
        if (limitVal == null || limitVal <= 0) {
            limitVal = 50;
        }

        String query = 'SELECT Id, Name, ProductCode, Item_Code__c, ' +
            'Product_Category__c, Sub_Category__c, Product_Type__c, Product_Vertical__c, ' +
            'Brand__c, Model__c, Equipment_Name__c, Line_Description__c, ' +
            'Standard_Price__c, Tax__c, Standard_Price_with_Tax__c, ' +
            'HSN_Code__c, HSN_Code_International__c, ' +
            'Default_Warranty_Months__c, Is_Installation_Required__c, Is_Training_Required__c, ' +
            'Specification__c, Detailed_Description__c, Source__c, Product_Status__c, Make__c ' +
            'FROM Product2 WHERE IsActive = true';

        if (String.isNotBlank(searchKey) && searchKey.length() >= 2) {
            String key = '%' + String.escapeSingleQuotes(searchKey) + '%';
            query += ' AND (Name LIKE :key OR Item_Code__c LIKE :key OR ProductCode LIKE :key ' +
                'OR Model__c LIKE :key OR Equipment_Name__c LIKE :key ' +
                'OR Brand__c LIKE :key OR Line_Description__c LIKE :key)';
        }
        if (String.isNotBlank(category)) {
            query += ' AND Product_Category__c = :category';
        }
        if (String.isNotBlank(vertical)) {
            query += ' AND Product_Vertical__c = :vertical';
        }

        query += ' ORDER BY Name ASC LIMIT :limitVal';
        return Database.query(query);
    }

    /**
     * Gets a single product by Id with all details.
     * @param productId The Product2 record Id
     * @return Product2 record with full details
     */
    @AuraEnabled(cacheable=true)
    public static Product2 getProductDetails(Id productId) {
        return [
            SELECT Id, Name, ProductCode, Item_Code__c, SAP_Item_Code__c,
                   Product_Category__c, Sub_Category__c, Product_Type__c, Product_Vertical__c,
                   Brand__c, Make__c, Model__c, Equipment_Name__c, Line_Description__c,
                   Standard_Price__c, Tax__c, Standard_Price_with_Tax__c,
                   HSN_Code__c, HSN_Code_International__c, Source__c,
                   Default_Warranty_Months__c, Warranty_Terms_Description__c,
                   Is_Installation_Required__c, Installation_Terms__c,
                   Is_Training_Required__c, Specification__c, Description,
                   Detailed_Description__c, Compatibility__c, Remarks__c,
                   Product_Status__c, ERP_Sync_Status__c, Last_ERP_Sync_Date__c,
                   Product_Image_URL__c, Product_Image_URL_2__c, Product_Image_URL_3__c
            FROM Product2
            WHERE Id = :productId
            LIMIT 1
        ];
    }

    /**
     * Gets distinct category values for filter picklist.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getProductCategories() {
        List<String> categories = new List<String>();
        for (AggregateResult ar : [
            SELECT Product_Category__c cat
            FROM Product2
            WHERE IsActive = true AND Product_Category__c != null
            GROUP BY Product_Category__c
            ORDER BY Product_Category__c
        ]) {
            categories.add((String) ar.get('cat'));
        }
        return categories;
    }

    /**
     * Gets distinct vertical values for filter picklist.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getProductVerticals() {
        List<String> verticals = new List<String>();
        for (AggregateResult ar : [
            SELECT Product_Vertical__c vert
            FROM Product2
            WHERE IsActive = true AND Product_Vertical__c != null
            GROUP BY Product_Vertical__c
            ORDER BY Product_Vertical__c
        ]) {
            verticals.add((String) ar.get('vert'));
        }
        return verticals;
    }
}