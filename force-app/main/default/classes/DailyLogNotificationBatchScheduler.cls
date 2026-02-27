global class DailyLogNotificationBatchScheduler implements Schedulable {
    global void execute(SchedulableContext SC) 
    {        
        DailyLogNotificationBatch revenueBatch = new DailyLogNotificationBatch();
        Database.executeBatch(revenueBatch, 200);
    }
}