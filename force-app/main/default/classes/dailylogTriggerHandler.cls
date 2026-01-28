public class dailylogTriggerHandler {
    
    //Update last visit 
       public static void beforeUpdate(List<Daily_Log__c> newDailyLogs, Map<Id, Daily_Log__c> oldDailyLogMap) {
    

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