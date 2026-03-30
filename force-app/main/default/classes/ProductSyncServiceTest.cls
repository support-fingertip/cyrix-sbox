// Cyrix Test class for ProductSyncService
/****************************************************************
* Class Name   : ProductSyncServiceTest
* Company      : Fingertipplus
* Created Date : 30-03-2026
* @description : Test class for ProductSyncService
**************************************************************/
@isTest
private class ProductSyncServiceTest {

    @TestSetup
    static void setupTestData() {
        Product2 existingProduct = new Product2(
            Name = 'Existing Ultrasound',
            Item_Code__c = 'IE-000004',
            ProductCode = 'IE-000004',
            HSN_Code__c = '9018',
            HSN_Code_International__c = '901819',
            Product_Category__c = 'Equipment',
            Product_Status__c = 'Active',
            IsActive = true,
            Standard_Price__c = 500000,
            Tax__c = 18,
            UOM__c = 'Nos'
        );
        insert existingProduct;
    }

    @isTest
    static void testSyncProductsFromERP_NewProduct() {
        ProductSyncService.ProductSyncWrapper pw = new ProductSyncService.ProductSyncWrapper();
        pw.itemCode = 'IC-000010';
        pw.productName = 'New Printer Paper';
        pw.productCode = 'IC-000010';
        pw.sapItemCode = 'I-120000';
        pw.lineDescription = 'CIYAN Printer Paper';
        pw.shortDescription = 'Printer paper for ultrasound';
        pw.detailedDescription = 'CIYAN Printer Paper Type 1';
        pw.vertical = 'Product Sales';
        pw.category = 'Consumables';
        pw.subCategory = 'Consumables';
        pw.brand = 'Ciyan';
        pw.make = 'Ciyan';
        pw.model = 'CY110S';
        pw.equipmentName = 'Ultrasound Scanning Machine';
        pw.source = 'OEM New';
        pw.taxPercent = 18;
        pw.hsnCodeDomestic = '4811';
        pw.hsnCodeInternational = '481100';
        pw.uom = 'Nos';
        pw.quantityPackSize = 1;
        pw.defaultWarrantyMonths = 0;
        pw.isInstallationRequired = 'No';
        pw.isTrainingRequired = 'No';
        pw.standardPrice = 650;
        pw.productStatus = 'Active';
        pw.managerDiscount = 8;
        pw.vpSalesDiscount = 4;
        pw.ceoSalesDiscount = 2;

        List<ProductSyncService.ProductSyncWrapper> products = new List<ProductSyncService.ProductSyncWrapper>{ pw };

        Test.startTest();
        List<ProductSyncService.SyncResult> results = ProductSyncService.syncProductsFromERP(products);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should have 1 result');
        System.assertEquals(true, results[0].success, 'Should succeed');
        System.assertEquals('Created', results[0].message, 'Should be created');

        Product2 inserted = [SELECT Id, Name, Item_Code__c, Brand__c, HSN_Code_International__c,
            Default_Warranty_Months__c, Is_Installation_Required__c, ERP_Sync_Status__c, IsActive
            FROM Product2 WHERE Item_Code__c = 'IC-000010'];
        System.assertEquals('Ciyan', inserted.Brand__c);
        System.assertEquals('481100', inserted.HSN_Code_International__c);
        System.assertEquals('Synced', inserted.ERP_Sync_Status__c);
        System.assertEquals(true, inserted.IsActive);
    }

    @isTest
    static void testSyncProductsFromERP_UpdateExisting() {
        ProductSyncService.ProductSyncWrapper pw = new ProductSyncService.ProductSyncWrapper();
        pw.itemCode = 'IE-000004';
        pw.productName = 'Updated Ultrasound';
        pw.productCode = 'IE-000004';
        pw.sapItemCode = 'I-101310';
        pw.hsnCodeDomestic = '9018';
        pw.hsnCodeInternational = '901819';
        pw.standardPrice = 600000;
        pw.productStatus = 'Active';
        pw.uom = 'Nos';
        pw.category = 'Equipment';

        Test.startTest();
        List<ProductSyncService.SyncResult> results = ProductSyncService.syncProductsFromERP(
            new List<ProductSyncService.ProductSyncWrapper>{ pw }
        );
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertEquals('Updated', results[0].message);

        Product2 updated = [SELECT Name, Standard_Price__c FROM Product2 WHERE Item_Code__c = 'IE-000004'];
        System.assertEquals('Updated Ultrasound', updated.Name);
        System.assertEquals(600000, updated.Standard_Price__c);
    }

    @isTest
    static void testSyncProductsFromERP_MissingItemCode() {
        ProductSyncService.ProductSyncWrapper pw = new ProductSyncService.ProductSyncWrapper();
        pw.productName = 'No Code Product';
        pw.hsnCodeDomestic = '9018';
        pw.hsnCodeInternational = '901819';

        Test.startTest();
        List<ProductSyncService.SyncResult> results = ProductSyncService.syncProductsFromERP(
            new List<ProductSyncService.ProductSyncWrapper>{ pw }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assertEquals('Item Code is required', results[0].message);
    }

    @isTest
    static void testSyncProductsFromERP_InactiveProduct() {
        ProductSyncService.ProductSyncWrapper pw = new ProductSyncService.ProductSyncWrapper();
        pw.itemCode = 'IE-INACTIVE';
        pw.productName = 'Inactive Product';
        pw.productCode = 'IE-INACTIVE';
        pw.hsnCodeDomestic = '9018';
        pw.hsnCodeInternational = '901819';
        pw.productStatus = 'Inactive';
        pw.uom = 'Nos';

        Test.startTest();
        List<ProductSyncService.SyncResult> results = ProductSyncService.syncProductsFromERP(
            new List<ProductSyncService.ProductSyncWrapper>{ pw }
        );
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        Product2 p = [SELECT IsActive FROM Product2 WHERE Item_Code__c = 'IE-INACTIVE'];
        System.assertEquals(false, p.IsActive, 'Should be inactive');
    }

    @isTest
    static void testGetHSNCodeByTerritory() {
        Product2 p = [SELECT Id FROM Product2 WHERE Item_Code__c = 'IE-000004' LIMIT 1];

        Test.startTest();
        String domesticHSN = ProductSyncService.getHSNCodeByTerritory(p.Id, 'Domestic');
        String internationalHSN = ProductSyncService.getHSNCodeByTerritory(p.Id, 'International');
        Test.stopTest();

        System.assertEquals('9018', domesticHSN);
        System.assertEquals('901819', internationalHSN);
    }

    @isTest
    static void testGetActiveProducts() {
        Test.startTest();
        List<Product2> products = ProductSyncService.getActiveProducts(null, null, null, 10);
        Test.stopTest();

        System.assert(products.size() > 0, 'Should find active products');
    }
}
