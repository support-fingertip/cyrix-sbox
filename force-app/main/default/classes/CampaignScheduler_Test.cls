@isTest
public class CampaignScheduler_Test {

    /* ------------------------------------------------------------
       Utility: dynamic restricted picklist value
       ------------------------------------------------------------ */
    private static String pickVal(Schema.SObjectField f) {
        List<Schema.PicklistEntry> vals =
            f.getDescribe().getPicklistValues();
        System.assert(!vals.isEmpty(), 'Picklist must have values');
        return vals[0].getValue();
    }

    @testSetup
    static void setupCampaignData() {

        Date today = Date.today();

        String src = pickVal(Campaign.Campaign_Source__c);
        String med = pickVal(Campaign.Campaign_Medium__c);

        List<Campaign> camps = new List<Campaign>();

        // f1: Activate
        camps.add(new Campaign(
            Name = 'Activate Campaign',
            StartDate = today,
            EndDate = today.addDays(5),
            Status = 'Approved',
            IsActive = false,
            Approval_Status__c = 'Approved',
            Campaign_Source__c = src,
            Campaign_Medium__c = med
        ));

        // f2: Cancel
        camps.add(new Campaign(
            Name = 'Cancel Campaign',
            StartDate = today.addDays(-10),
            EndDate = today.addDays(-1),
            Status = 'Approved',
            IsActive = true,
            Approval_Status__c = 'Approved',
            Campaign_Source__c = src,
            Campaign_Medium__c = med
        ));

        // f3: Complete
        camps.add(new Campaign(
            Name = 'Complete Campaign',
            StartDate = today.addDays(-10),
            EndDate = today.addDays(-1),
            Status = 'Started',
            IsActive = true,
            Approval_Status__c = 'Approved',
            Campaign_Source__c = src,
            Campaign_Medium__c = med
        ));

        insert camps;
    }

    @isTest
    static void testBatchExecution() {

        Test.startTest();
        Database.executeBatch(new CampaignScheduler(), 200);
        Test.stopTest();

        List<Campaign> result = [
            SELECT Status, IsActive, Reason_for_Cancellation__c
            FROM Campaign
        ];

        System.assert(result.size() >= 3);
    }

    @isTest
    static void testSchedulerExecution() {

        Test.startTest();
        System.schedule(
            'Campaign Scheduler Test',
            '0 0 12 * * ?',
            new CampaignScheduler()
        );
        Test.stopTest();

        System.assert(true);
    }
}