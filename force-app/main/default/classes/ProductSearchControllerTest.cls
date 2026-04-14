//  Test class for ProductSearchController
/****************************************************************
* Class Name   : ProductSearchControllerTest
* Company      : Fingertipplus
* Created Date : 30-03-2026
* @description : Test class for ProductSearchController
**************************************************************/
@isTest
private class ProductSearchControllerTest {

    @TestSetup
    static void setupTestData() {
        List<Product2> products = new List<Product2>();

        products.add(new Product2(
            Name = 'Ultrasound Machine DC80',
            Item_Code__c = 'IE-000004',
            ProductCode = 'IE-000004',
            HSN_Code__c = '9018',
            HSN_Code_International__c = '901819',
            Product_Category__c = 'Equipment',
            Sub_Category__c = 'Diagnostic Imaging',
            Product_Vertical__c = 'Product Sales',
            Brand__c = 'Mindray',
            Make__c = 'Mindray',
            Model__c = 'DC80',
            Equipment_Name__c = 'Ultrasound Scanning Machine',
            Standard_Price__c = 500000,
            Tax__c = 18,
            Product_Status__c = 'Active',
            Default_Warranty_Months__c = 12,
            Is_Installation_Required__c = 'Yes',
           
            IsActive = true
        ));

        products.add(new Product2(
            Name = 'Printer Paper CY110S',
            Item_Code__c = 'IC-000001',
            ProductCode = 'IC-000001',
            HSN_Code__c = '4811',
            HSN_Code_International__c = '481100',
            Product_Category__c = 'Consumables',
            Sub_Category__c = 'Consumables',
            Product_Vertical__c = 'Ciyan',
            Brand__c = 'Ciyan',
            Make__c = 'Ciyan',
            Model__c = 'CY110S 5R',
            Standard_Price__c = 650,
            Tax__c = 18,
            Product_Status__c = 'Active',
            IsActive = true
        ));

        insert products;
    }

    @isTest
    static void testSearchProducts_ByKeyword() {
        Test.startTest();
        List<Product2> results = ProductSearchController.searchProducts('Ultrasound', null, null, 10);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find 1 ultrasound product');
        System.assertEquals('Ultrasound Machine DC80', results[0].Name);
    }

    @isTest
    static void testSearchProducts_ByCategory() {
        Test.startTest();
        List<Product2> results = ProductSearchController.searchProducts('', 'Consumables', null, 10);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find 1 consumable');
    }

    @isTest
    static void testSearchProducts_ByVertical() {
        Test.startTest();
        List<Product2> results = ProductSearchController.searchProducts('', null, 'Ciyan', 10);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find 1 Ciyan product');
    }

    @isTest
    static void testSearchProducts_NoResults() {
        Test.startTest();
        List<Product2> results = ProductSearchController.searchProducts('NonExistent', null, null, 10);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should find no products');
    }

    @isTest
    static void testSearchProducts_AllActive() {
        Test.startTest();
        List<Product2> results = ProductSearchController.searchProducts('', null, null, 50);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should find 2 active products');
    }

    @isTest
    static void testGetProductDetails() {
        Product2 p = [SELECT Id FROM Product2 WHERE Item_Code__c = 'IE-000004' LIMIT 1];

        Test.startTest();
        Product2 details = ProductSearchController.getProductDetails(p.Id);
        Test.stopTest();

        System.assertEquals('Ultrasound Machine DC80', details.Name);
        System.assertEquals('9018', details.HSN_Code__c);
        System.assertEquals('901819', details.HSN_Code_International__c);
        System.assertEquals(12, details.Default_Warranty_Months__c);
        System.assertEquals('Yes', details.Is_Installation_Required__c);
    }

    @isTest
    static void testGetProductCategories() {
        Test.startTest();
        List<String> categories = ProductSearchController.getProductCategories();
        Test.stopTest();

        System.assert(categories.size() > 0, 'Should have categories');
    }

    @isTest
    static void testGetProductVerticals() {
        Test.startTest();
        List<String> verticals = ProductSearchController.getProductVerticals();
        Test.stopTest();

        System.assert(verticals.size() > 0, 'Should have verticals');
    }
}