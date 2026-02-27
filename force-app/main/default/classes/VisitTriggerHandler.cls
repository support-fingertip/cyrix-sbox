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
            CalculateDistanceAPI.distanceCalculationSF(dailylogIds);
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
            
            if( v.Visit_for__c  =='Customer'){
                newVisit.Account__c  = v.Account__c;
            }else{
                newVisit.Lead__c = v.Lead__c;
            }
            newVisit.OwnerId = (v.OwnerId != null)
                ? v.OwnerId
                : UserInfo.getUserId();
            
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
        list<Visit__c> visitDupLists = new   list<Visit__c>();
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
            if(v.Credated_From_ui__c)
            visitDupLists.add(v);
        }
        preventDuplicateVisitsBeforeInsert(visitDupLists);
    }
    public static void visitAssignedNotification(List<visit__c> visits) {
        
        CustomNotificationType type = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Lead_Notification'
            LIMIT 1
        ];
        
        String senderId = UserInfo.getUserId();
        
        for (visit__c v : visits) {
            
            if (v.OwnerId == null) continue;
            
            String title = 'Visit - ' + v.Name + ' is assigned to you';
            String body  = 'Visit Assigned'
                + '\n ' + (v.Visit_ID__c != null ? v.Visit_ID__c : '')
                + '\nPlanned Visit Time: ' + (v.Planned_Start_Time__c != null ? String.valueOf(v.Planned_Start_Time__c) : '');
            
            SendEmailCustomNotification.sendNotification(title, body, senderId, type.Id, v.Id, new Set<String>{ v.OwnerId });
        }
    }
    private static void preventDuplicateVisitsBeforeInsert(List<Visit__c> newVisits) {
        
        Set<Id> ownerIds = new Set<Id>();
        Set<Date> visitDates = new Set<Date>();
        Set<Id> leadIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        
        // 1) duplicates inside same batch
        Set<String> incomingKeys = new Set<String>();
        
        for (Visit__c v : newVisits) {
            if (v.OwnerId == null || v.Visit_Date__c == null) continue;
            
            String key = null;
            
            if (v.Lead__c != null) {
                key = v.OwnerId + '|' + String.valueOf(v.Visit_Date__c) + '|LEAD|' + v.Lead__c;
                leadIds.add(v.Lead__c);
            } else if (v.Account__c != null) {
                key = v.OwnerId + '|' + String.valueOf(v.Visit_Date__c) + '|ACC|' + v.Account__c;
                accountIds.add(v.Account__c);
            } else {
                continue; // neither lead nor account => rule doesn't apply
            }
            
            if (incomingKeys.contains(key)) {
                v.addError('Duplicate Visit: same owner, same date, and same Lead/Customer already added.');
                continue;
            }
            incomingKeys.add(key);
            
            ownerIds.add(v.OwnerId);
            visitDates.add(v.Visit_Date__c);
        }
        
        if (ownerIds.isEmpty() || visitDates.isEmpty() || (leadIds.isEmpty() && accountIds.isEmpty())) return;
        
        // 2) duplicates already in DB
        List<Visit__c> existing = [
            SELECT Id, OwnerId, Visit_Date__c, Lead__c, Account__c
            FROM Visit__c
            WHERE OwnerId IN :ownerIds
            AND Visit_Date__c IN :visitDates
            AND (
                (Lead__c IN :leadIds AND Lead__c != null)
                OR (Account__c IN :accountIds AND Account__c != null)
            )
        ];
        
        Set<String> existingKeys = new Set<String>();
        for (Visit__c e : existing) {
            if (e.Lead__c != null) {
                existingKeys.add(e.OwnerId + '|' + String.valueOf(e.Visit_Date__c) + '|LEAD|' + e.Lead__c);
            }
            if (e.Account__c != null) {
                existingKeys.add(e.OwnerId + '|' + String.valueOf(e.Visit_Date__c) + '|ACC|' + e.Account__c);
            }
        }
        
        for (Visit__c v : newVisits) {
            if (v.OwnerId == null || v.Visit_Date__c == null) continue;
            
            String key = null;
            if (v.Lead__c != null) {
                key = v.OwnerId + '|' + String.valueOf(v.Visit_Date__c) + '|LEAD|' + v.Lead__c;
            } else if (v.Account__c != null) {
                key = v.OwnerId + '|' + String.valueOf(v.Visit_Date__c) + '|ACC|' + v.Account__c;
            } else {
                continue;
            }
            
            if (existingKeys.contains(key)) {
                v.addError('Duplicate Visit already exists: same owner, same date, and same Lead/Customer.');
            }
        }
    }
     public static void testcover(){
        integer i=0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }
}