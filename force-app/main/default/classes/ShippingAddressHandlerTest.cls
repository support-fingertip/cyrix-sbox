@isTest
public class ShippingAddressHandlerTest {

    private static Account createAccount(String name) {

        Account acc = new Account(
            Name = name,
            Phone = '9876543210', // 10 digit validation rule
            Customer_Category__c = 'Private Customer', // VALID PICKLIST VALUE
            BillingStreet = '123 MG Road',
            BillingCity = 'Mumbai',
            BillingStateCode = 'MH',
            BillingCountryCode = 'IN',
            BillingPostalCode = '400001'
        );

        insert acc;
        return acc;
    }

    @isTest
    static void testPositiveScenario() {

        Account acc = createAccount('Positive Account');

        Shipping_Address__c ship = new Shipping_Address__c(
            Account__c = acc.Id,
            Same_as_BillingAddress__c = true
        );

        Test.startTest();
        insert ship;
        Test.stopTest();

        Shipping_Address__c result = [
            SELECT Address__Street__s,
                   Address__City__s,
                   Address__StateCode__s,
                   Address__CountryCode__s,
                   Address__PostalCode__s
            FROM Shipping_Address__c
            WHERE Id = :ship.Id
        ];

        System.assertEquals('123 MG Road', result.Address__Street__s);
        System.assertEquals('Mumbai', result.Address__City__s);
        System.assertEquals('MH', result.Address__StateCode__s);
        System.assertEquals('IN', result.Address__CountryCode__s);
        System.assertEquals('400001', result.Address__PostalCode__s);
    }

    @isTest
    static void testBulkScenario() {

        Account acc = createAccount('Bulk Account');

        List<Shipping_Address__c> shipList = new List<Shipping_Address__c>();

        for (Integer i = 0; i < 5; i++) {
            shipList.add(new Shipping_Address__c(
                Account__c = acc.Id,
                Same_as_BillingAddress__c = true
            ));
        }

        Test.startTest();
        insert shipList;
        Test.stopTest();

        List<Shipping_Address__c> results = [
            SELECT Address__City__s
            FROM Shipping_Address__c
            WHERE Account__c = :acc.Id
        ];

        for (Shipping_Address__c s : results) {
            System.assertEquals('Mumbai', s.Address__City__s);
        }
    }
}