@IsTest
private class UtilityTest {

    @IsTest
    static void test_getObjectAndCurrentUser_validRecordId() {
          String customerCategory =
            Account.Customer_Category__c.getDescribe()
                .getPicklistValues()[0].getValue();
         Account acc = new Account(
            Name = 'Test Account',
            Phone = '9876543210',
            Customer_Category__c = customerCategory
        );
insert acc;
        Test.startTest();
        Utility u = Utility.getObjectAndCurrentUser(acc.Id);
    Utility.getAllCountryCodeMappings(true);
        Utility.getAllCountryCodeMappings(false);
    
        Test.stopTest();
    }

    @IsTest
    static void test_getObjectAndCurrentUser_blankRecordId() {
        Test.startTest();
        //Utility u1 = Utility.getObjectAndCurrentUser(null);
        Utility.getAllCountryCodeMappings(true);
        Utility.getAllCountryCodeMappings(false);
        Test.stopTest();
    }

   
}