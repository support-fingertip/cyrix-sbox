trigger ShippingAddressTrigger on Shipping_Address__c (before insert, before update) {

    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            ShippingAddressHandler.populateBillingAddress(Trigger.new);
        }
    }
}