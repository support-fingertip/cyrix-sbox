// Cyrix Product Master ERP Sync Service - Module 7
/****************************************************************
* Class Name   : ProductSyncService
* Company      : Fingertipplus
* Created Date : 30-03-2026
* @description : Service class for ERP-to-Salesforce Product Master sync.
*                Handles real-time product upsert from ERP, duplicate prevention,
*                tax/HSN logic, and sync failure notifications per BRD Module 7.
*
* Change Log:
* -----------------------------------------------------------------------------
* Ver | Author           | Date       | Description
* -----------------------------------------------------------------------------
* 1.0 | Claude AI        | 30-03-2026 | Initial version - Product Master sync
* -----------------------------------------------------------------------------
**************************************************************/
public with sharing class ProductSyncService {

    /**
     * Upserts products received from ERP. Uses Item_Code__c as external ID
     * for duplicate prevention. Only ERP can create/edit products in Salesforce.
     * @param products List of ProductSyncWrapper containing product data from ERP
     * @return List of SyncResult with success/failure per product
     */
    public static List<SyncResult> syncProductsFromERP(List<ProductSyncWrapper> products) {
        List<SyncResult> results = new List<SyncResult>();
        List<Product2> productsToUpsert = new List<Product2>();
        Map<String, Integer> itemCodeToIndex = new Map<String, Integer>();

        for (Integer i = 0; i < products.size(); i++) {
            ProductSyncWrapper pw = products[i];

            if (String.isBlank(pw.itemCode)) {
                results.add(new SyncResult(pw.itemCode, false, 'Item Code is required'));
                continue;
            }

            Product2 p = mapWrapperToProduct(pw);
            productsToUpsert.add(p);
            itemCodeToIndex.put(pw.itemCode, i);
            results.add(new SyncResult(pw.itemCode, true, 'Pending'));
        }

        if (!productsToUpsert.isEmpty()) {
            List<Database.UpsertResult> upsertResults =
                Database.upsert(productsToUpsert, Product2.Item_Code__c, false);

            Integer idx = 0;
            for (Database.UpsertResult ur : upsertResults) {
                String itemCode = productsToUpsert[idx].Item_Code__c;
                Integer originalIdx = itemCodeToIndex.get(itemCode);

                if (ur.isSuccess()) {
                    results[originalIdx] = new SyncResult(
                        itemCode, true,
                        ur.isCreated() ? 'Created' : 'Updated'
                    );
                } else {
                    String errorMsg = '';
                    for (Database.Error err : ur.getErrors()) {
                        errorMsg += err.getMessage() + '; ';
                    }
                    results[originalIdx] = new SyncResult(itemCode, false, errorMsg);
                }
                idx++;
            }

            // Notify admins if any sync failures occurred
            List<String> failedItems = new List<String>();
            for (SyncResult sr : results) {
                if (!sr.success) {
                    failedItems.add(sr.itemCode + ': ' + sr.message);
                }
            }
            if (!failedItems.isEmpty()) {
                notifySyncFailure(failedItems);
            }
        }

        return results;
    }

    /**
     * Maps a ProductSyncWrapper to a Product2 sObject.
     */
    private static Product2 mapWrapperToProduct(ProductSyncWrapper pw) {
        Product2 p = new Product2();
        p.Item_Code__c = pw.itemCode;
        p.Name = pw.productName;
        p.ProductCode = pw.productCode;
        p.SAP_Item_No__c = pw.sapItemCode;
        p.Line_Description__c = pw.lineDescription;
        p.Description = pw.shortDescription;
        p.Detailed_Description__c = pw.detailedDescription;
        p.Product_V__c = pw.vertical;
        p.Product_Category__c = pw.category;
        p.Sub_Category__c = pw.subCategory;
        p.Brand__c = pw.brand;
        p.Make__c = pw.make;
        p.Model__c = pw.model;
        p.Equipment_Name__c = pw.equipmentName;
        p.OEM_Part_Number__c = pw.oemPartNumber;
        p.Source__c = pw.source;
        p.Tax__c = pw.taxPercent;
        p.HSN_Code__c = pw.hsnCodeDomestic;
        p.HSN_Code_International__c = pw.hsnCodeInternational;
        p.UOM__c = pw.uom;
        p.Quantity_Pack_Size__c = pw.quantityPackSize;
        p.Specification__c = pw.specification;
        p.Compatibility__c = pw.compatibility;
        p.Default_Warranty_Months__c = pw.defaultWarrantyMonths;
        p.Warranty_Terms_Description__c = pw.warrantyTerms;
        p.Installation_Terms__c = pw.installationTerms;
        p.Is_Installation_Required__c = pw.isInstallationRequired;
        p.Is_Training_Required__c = pw.isTrainingRequired;
        p.Standard_Price__c = pw.standardPrice;
        p.Product_Status__c = pw.productStatus;
        p.IsActive = pw.productStatus == 'Active';
        p.Product_Image_URL__c = pw.imageUrl1;
        p.Product_Image_URL_2__c = pw.imageUrl2;
        p.Product_Image_URL_3__c = pw.imageUrl3;
        p.ERP_Sync_Status__c = 'Synced';
        p.Last_ERP_Sync_Date__c = Datetime.now();

        if (pw.managerDiscount != null) {
            p.Manager_Discount_Up_to__c = pw.managerDiscount;
        }
        if (pw.vpSalesDiscount != null) {
            p.VP_Sales_Discount_Up_to__c = pw.vpSalesDiscount;
        }
        if (pw.ceoSalesDiscount != null) {
            p.CEO_Sales_Discount_Up_to__c = pw.ceoSalesDiscount;
        }

        return p;
    }

    /**
     * Retrieves the applicable HSN code based on customer territory.
     * Domestic territory uses HSN_Code__c, International uses HSN_Code_International__c.
     * @param productId The Product2 Id
     * @param territory Customer territory - 'Domestic' or 'International'
     * @return The applicable HSN code string
     */
    public static String getHSNCodeByTerritory(Id productId, String territory) {
        Product2 product = [
            SELECT HSN_Code__c, HSN_Code_International__c
            FROM Product2
            WHERE Id = :productId
            LIMIT 1
        ];

        if (territory == 'International') {
            return product.HSN_Code_International__c;
        }
        return product.HSN_Code__c;
    }

    /**
     * Returns active products filtered by category, type, and vertical.
     * Only active products from ERP are visible in Salesforce per BRD.
     */
    public static List<Product2> getActiveProducts(String category, String productType, String vertical, Integer limitVal) {
        String query = 'SELECT Id, Name, ProductCode, Item_Code__c, SAP_Item_No__c, ' +
            'Product_Category__c, Sub_Category__c, Product_Type__c, Product_V__c, ' +
            'Brand__c, Make__c, Model__c, Equipment_Name__c, Line_Description__c, ' +
            'Standard_Price__c, Tax__c, Standard_Price_with_Tax__c, ' +
            'UOM__c, HSN_Code__c, HSN_Code_International__c, Source__c, ' +
            'Default_Warranty_Months__c, Is_Installation_Required__c, Is_Training_Required__c, ' +
            'Product_Status__c, ERP_Sync_Status__c, IsActive ' +
            'FROM Product2 WHERE IsActive = true';

        if (String.isNotBlank(category)) {
            query += ' AND Product_Category__c = :category';
        }
        if (String.isNotBlank(productType)) {
            query += ' AND Product_Type__c = :productType';
        }
        if (String.isNotBlank(vertical)) {
            query += ' AND Product_V__c = :vertical';
        }
        if (limitVal == null || limitVal <= 0) {
            limitVal = 200;
        }
        query += ' ORDER BY Name ASC LIMIT :limitVal';

        return Database.query(query);
    }

    /**
     * Sends notification to System Admins when ERP sync fails.
     * BRD Module 7: Notification to Admins if sync fails.
     */
    private static void notifySyncFailure(List<String> failedItems) {
        try {
            List<Log__c> logs = new List<Log__c>();
            Log__c log = new Log__c();
            log.Object__c = 'Product ERP Sync';
            String failureDetails = 'Product sync failures:\n' + String.join(failedItems, '\n');
            log.Request__c = failureDetails.length() > 32000
                ? failureDetails.substring(0, 32000) : failureDetails;
            log.Response__c = 'Sync Failed - ' + failedItems.size() + ' product(s)';
            logs.add(log);
            insert logs;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to log sync failure: ' + e.getMessage());
        }
    }

    // ---- Wrapper Classes ----

    public class ProductSyncWrapper {
        public String itemCode;
        public String productCode;
        public String sapItemCode;
        public String productName;
        public String lineDescription;
        public String shortDescription;
        public String detailedDescription;
        public String vertical;
        public String category;
        public String subCategory;
        public String brand;
        public String make;
        public String model;
        public String equipmentName;
        public String oemPartNumber;
        public String source;
        public Decimal taxPercent;
        public String hsnCodeDomestic;
        public String hsnCodeInternational;
        public String uom;
        public Decimal quantityPackSize;
        public String specification;
        public String compatibility;
        public Decimal defaultWarrantyMonths;
        public String warrantyTerms;
        public String installationTerms;
        public String isInstallationRequired;
        public String isTrainingRequired;
        public Decimal standardPrice;
        public String productStatus;
        public String imageUrl1;
        public String imageUrl2;
        public String imageUrl3;
        public Decimal managerDiscount;
        public Decimal vpSalesDiscount;
        public Decimal ceoSalesDiscount;
    }

    public class SyncResult {
        public String itemCode;
        public Boolean success;
        public String message;

        public SyncResult(String itemCode, Boolean success, String message) {
            this.itemCode = itemCode;
            this.success = success;
            this.message = message;
        }
    }
}
