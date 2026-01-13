public class SystemEndDayController {
    
    public static void autoEndDailyLogs() {
        List<Daily_Log__c> dailyLogsList = [
            SELECT Id, OwnerId, Day_ended_time__c 
            FROM Daily_Log__c 
            WHERE CreatedDate = TODAY
              AND Clock_In_Location__Latitude__s != null 
              AND Clock_In_Location__Latitude__s != 0 
              AND Day_ended_time__c = null
        ];

        if (dailyLogsList.isEmpty()) return;

        Datetime currentTime = Datetime.now();

        for (Daily_Log__c dl : dailyLogsList) {
            dl.Day_ended_time__c = currentTime;
            dl.Is_System_Ended__c = true;
        }

        update dailyLogsList;
    }
}