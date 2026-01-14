public class VisitTriggerHandler {
      /**************************************************************** 
* Class Name  : VisitTriggerHandler  @Company  : Fingertip    @Created Date  : 29-9-2025  
@description : visit object trigger Handler  @author  :Nanma T V   @User By  : -CalculateDistanceAPI
* Change Log: 
* ----------------------------------------------------------------------------- 
* Ver |   Author      |   Date        |   Description 
* ----------------------------------------------------------------------------- 
* 1.0 |   Nanma  |  29-9-2025 |   Initial version      
* -------------------------------------------------------------------
**************************************************************** */   
 
/*@method name:Calculate Distance on Status @createddate:07/1/26 description calculate distance calling distance Api  */

    public static void calculateDistance(List<Visit__c> newVisits, Map<Id, Visit__c> oldVisitMap ) {
        if (newVisits == null || newVisits.isEmpty()) 
            return ;
    
        List<Id> dailylogIds = new List<Id>();
        for (Visit__c v : newVisits) {
            if (v.Status__c == 'In Progress' && oldVisitMap.containsKey(v.Id) && oldVisitMap.get(v.Id).Status__c != v.Status__c &&
                v.Check_In_Location__Latitude__s != null && v.Check_In_Location__Longitude__s != null && v.Visit_Start__c != null && v.Daily_Log__c!=null) {
                    dailylogIds.add(v.Daily_Log__c);
                }
        }
        
        // Avoid callouts during test execution
        if (!dailylogIds.isEmpty() && !Test.isRunningTest() && label.ActivateGMapAPI=='TRUE') {
            CalculateDistanceAPI.distanceCalculation(dailylogIds);
        }
    
    }
    /*
/*@method name:updateDailyLogs @createddate:07/1/26 Description Roll-up Distance to Daily Log*/
    public static void updateDailyLogs(Set<Id> dailyLogIds) {
        
        if (dailyLogIds == null || dailyLogIds.isEmpty()) {
            return;
        }
        
        Map<Id, Daily_Log__c> logsToUpdate = new Map<Id, Daily_Log__c>();
        
        for (AggregateResult ar : [SELECT Daily_log__c logId, SUM(Distance__c) totalDistance,  COUNT(Id) visitCount  FROM Visit__c   WHERE Daily_log__c IN :dailyLogIds GROUP BY Daily_log__c ]) {
            logsToUpdate.put( (Id) ar.get('logId'),
                new Daily_Log__c( Id = (Id) ar.get('logId'),KMs_Travelled__c = (Double) ar.get('totalDistance'), Total_Visits__c = (Integer) ar.get('visitCount') ));
        }
        
        if (!logsToUpdate.isEmpty()) {
            update logsToUpdate.values();
        }
    }
    
    /* @method name:missedVisit @createddate:07/1/26 Create Rescheduled Visit for Missed Visits*/
    public static void missedVisit(List<Visit__c> missedVisits) {
        
        if (missedVisits == null || missedVisits.isEmpty()) {
            return;
        }
        
        List<Visit__c> rescheduledVisits = new List<Visit__c>();
       for (Visit__c v : missedVisits) {
           // Postponed time is mandatory
            if (v.PostPoned_Start_Time__c == null) {
                continue;
            }
            
            Visit__c newVisit = new Visit__c();
            
            /* ---------- REQUIRED LOOKUPS ---------- */
            newVisit.Account__c   = v.Account__c;
            newVisit.Lead__c      = v.Lead__c;
            
            /* ---------- OWNER (FIXED ISSUE) ---------- */
            newVisit.OwnerId = (v.OwnerId != null)
                ? v.OwnerId
                : UserInfo.getUserId();
            
            /* ---------- PICKLISTS ---------- */
            newVisit.Visit_for__c     = v.Visit_for__c;
            newVisit.Visit_Purpose__c = v.Visit_Purpose__c;
            newVisit.Visit_Type__c    = v.Visit_Type__c;
            newVisit.Status__c        = 'Planned';
            
            /* ---------- DATES ---------- */
            newVisit.Planned_Start_Time__c = v.PostPoned_Start_Time__c;
            newVisit.Visit_Date__c = Date.valueOf(v.PostPoned_Start_Time__c);
            
            /* ---------- OPTIONAL BUT SAFE ---------- */
            newVisit.Mode_of_Transport__c = v.Mode_of_Transport__c;
            
            rescheduledVisits.add(newVisit);
        }
        
        //  Do NOT swallow insert errors
        if (!rescheduledVisits.isEmpty()) {
            insert rescheduledVisits;
        }
    }
    
    public static void beforeInsert(List<Visit__c> newVisits) {
        for (Visit__c v : newVisits) {
            if (v.Planned_Start_Time__c != null) {
                // Avoid timezone issues
                v.Visit_Date__c = v.Planned_Start_Time__c.date();
            }
            if(v.Lead__c !=null){
                v.Visit_for__c ='Lead';
            }
               if(v.Account__c !=null){
                v.Visit_for__c ='Customer';
            }
            if(v.Assign_To__c !=null){
                v.OwnerId = v.Assign_To__c; 
            }
        }
    }
}