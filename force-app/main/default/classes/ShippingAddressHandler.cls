public class ShippingAddressHandler {

    public static void populateBillingAddress(List<Shipping_Address__c> records) {

        Set<Id> accountIds = new Set<Id>();

        // Collect Account Ids
        for (Shipping_Address__c ship : records) {
            if (ship.Same_as_BillingAddress__c == true && ship.Account__c != null) {
                accountIds.add(ship.Account__c);
            }
        }

        if (accountIds.isEmpty()) {
            return;
        }

        // Query Accounts in bulk
        Map<Id, Account> accMap = new Map<Id, Account>(
    [SELECT Id,
            BillingStreet,
            BillingCity,
            BillingPostalCode,
            BillingStateCode,
            BillingCountryCode
     FROM Account
     WHERE Id IN :accountIds]
);

        // Assign Billing to Shipping Address
        for (Shipping_Address__c ship : records) {

            if (ship.Same_as_BillingAddress__c == true
                && ship.Account__c != null
                && accMap.containsKey(ship.Account__c)) {

                Account acc = accMap.get(ship.Account__c);

               ship.Address__Street__s      = acc.BillingStreet;
                ship.Address__City__s        = acc.BillingCity;
                ship.Address__StateCode__s   = acc.BillingStateCode;
                ship.Address__CountryCode__s = acc.BillingCountryCode;
                ship.Address__PostalCode__s  = acc.BillingPostalCode;

            }
        }
    }
}