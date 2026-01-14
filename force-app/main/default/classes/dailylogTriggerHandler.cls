public class dailylogTriggerHandler {
    
    //Update last visit 
       public static void beforeUpdate(List<Daily_Log__c> newDailyLogs, Map<Id, Daily_Log__c> oldDailyLogMap) {
        Set<Id> dailyLogIds = new Set<Id>();
        
        // Step 1: Collect relevant Daily Log IDs
        for (Daily_Log__c dl : newDailyLogs) {
            if ( dl.Day_ended_time__c != oldDailyLogMap.get(dl.Id).Day_ended_time__c && dl.Day_ended_time__c != null) {
                dailyLogIds.add(dl.Id);
            }
        }
        
        if (dailyLogIds.isEmpty()) return;
        
        // Step 2: Query Daily Logs with their most recent Visit
        List<Daily_Log__c> logsWithLastVisit = [
            SELECT Id,
            (SELECT Id FROM Visits__r ORDER BY CreatedDate DESC LIMIT 1)
            FROM Daily_Log__c
            WHERE Id IN :dailyLogIds
        ];
        
        // Step 3: Assign Last_Visit__c field
        Map<Id, Id> lastVisitMap = new Map<Id, Id>();
        for (Daily_Log__c log : logsWithLastVisit) {
            if (!log.Visits__r.isEmpty()) {
                lastVisitMap.put(log.Id, log.Visits__r[0].Id);
            }
        }
        
        for (Daily_Log__c dl : newDailyLogs) {
            if (lastVisitMap.containsKey(dl.Id)) {
                dl.Last_Visit__c = lastVisitMap.get(dl.Id);
            }
        }
    }
    
    
  // calculate distance using metrix api  
      public static void afterUpdate(List<Daily_Log__c> newDailyLogs,map<Id,Daily_Log__c> oldDailyLogMap) {
        list<Id> dailyLogIds = new list<Id>();
        Map<Id, Visit__c> visitMap = new Map<Id, Visit__c>();
        Map<String, Id> dailyLogIdMap = new Map<String, Id>();
        for (Daily_Log__c dl :newDailyLogs) {
            //when ever end day is happening we are storing daily log id
            if ((dl.Clock_Out_Location__Latitude__s != oldDailyLogMap.get(dl.Id).Clock_Out_Location__Latitude__s ||
                dl.Clock_Out_Location__Longitude__s != oldDailyLogMap.get(dl.Id).Clock_Out_Location__Longitude__s)  &&
                (dl.Clock_Out_Location__Latitude__s!=null && dl.Clock_Out_Location__Longitude__s !=null)) 
            {
                dailyLogIds.add(dl.Id);
               
            }
            
        } 
          if(dailyLogIds.size() > 0){
            CalculateDistanceAPI.distanceCalculation(dailyLogIds);  
          } 
      
    }
    
}