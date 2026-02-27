@isTest
public class DailyLogNotificationBatchTest 
{
    @isTest
    public static void testDailyLogNotificationBatch()
    {
        list<Daily_Log__c> lstDailyLog = new list <Daily_Log__c>();
        
        for(integer counter = 1 ; counter<=10 ; counter ++)
        {
            Daily_Log__c dg = new Daily_Log__c();
            dg.Day_started_time__c = DateTime.newInstance(2023, 11, 20, 0, 0, 0);
            
            
            lstDailyLog.add(dg);
            
        }
        insert lstDailyLog;
        
      
       
        test.startTest();
 
        
        DailyLogNotificationBatch contactsBatch = new DailyLogNotificationBatch();
        
        database.executeBatch(contactsBatch);
        
        DailyLogNotificationBatchScheduler scheduler = new DailyLogNotificationBatchScheduler();
        String jobId = System.schedule('DailyLogNotificationBatchJob', '0 0 0 * * ?', scheduler);

        
        test.stopTest();
    }

}