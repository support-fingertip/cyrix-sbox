//  Test class for ProductTriggerHandler
/****************************************************************
* Class Name   : ProductTriggerHandlerTest
* Company      : Fingertipplus
* Created Date : 30-03-2026
* @description : Test class for ProductTriggerHandler
**************************************************************/
@isTest
private class ProductTriggerHandlerTest {

    @isTest
    static void testActiveStatusSync_Insert() {
        Product2 p = new Product2(
            Name = 'Test Product',
            Item_Code__c = 'TEST-001',
            HSN_Code__c = '9018',
            Product_Status__c = 'Active'
        );

        Test.startTest();
        insert p;
        Test.stopTest();

        Product2 inserted = [SELECT IsActive FROM Product2 WHERE Id = :p.Id];
        System.assertEquals(true, inserted.IsActive, 'IsActive should be true when Product_Status__c is Active');
    }

    @isTest
    static void testActiveStatusSync_InsertInactive() {
        Product2 p = new Product2(
            Name = 'Inactive Product',
            Item_Code__c = 'TEST-002',
            HSN_Code__c = '9018',
            Product_Status__c = 'Inactive'
        );

        Test.startTest();
        insert p;
        Test.stopTest();

        Product2 inserted = [SELECT IsActive FROM Product2 WHERE Id = :p.Id];
        System.assertEquals(false, inserted.IsActive, 'IsActive should be false when Product_Status__c is Inactive');
    }

    @isTest
    static void testActiveStatusSync_Update() {
        Product2 p = new Product2(
            Name = 'Test Product Update',
            Item_Code__c = 'TEST-003',
            HSN_Code__c = '9018',
            Product_Status__c = 'Active'
        );
        insert p;

        Test.startTest();
        p.Product_Status__c = 'Inactive';
        update p;
        Test.stopTest();

        Product2 updated = [SELECT IsActive FROM Product2 WHERE Id = :p.Id];
        System.assertEquals(false, updated.IsActive, 'IsActive should be false after update to Inactive');
    }
}