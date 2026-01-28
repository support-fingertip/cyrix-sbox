trigger VisitTrigger on Visit__c (before insert,after insert, after update, before delete,after undelete) {
  /**************************************************************** 
* Class Name  : VisitTrigger  @Company  : Fingertip    @Created Date  : 29-9-2025  
@description : visit object trigger   @author  :Nanma T V   @User By  : -visittriggerHandler
* Change Log: 
* ----------------------------------------------------------------------------- 
* Ver |   Author      |   Date        |   Description 
* ----------------------------------------------------------------------------- 
* 1.0 |   Nanma  |  29-9-2025 |   Initial version      
* -------------------------------------------------------------------
**************************************************************** */  

      if(trigger.operationType == TriggerOperation.BEFORE_INSERT ){
        VisitTriggerHandler.beforeInsert(Trigger.new);
    }
    
      if(trigger.operationType == TriggerOperation.AFTER_INSERT ){
        VisitTriggerHandler.visitAssignedNotification(Trigger.new);
    }


     if(trigger.operationType == TriggerOperation.AFTER_UPDATE ){
        // Missed visit creation
        List<Visit__c> missedVisits = new List<Visit__c>();
        for (Visit__c v : Trigger.new) {
            Visit__c oldV = Trigger.oldMap.get(v.Id);
            if ( v.Status__c == 'Missed' && oldV.Status__c != v.Status__c && v.PostPoned_Start_Time__c != null) {
                missedVisits.add(v);
            }
        }
        if (!missedVisits.isEmpty()) {
            VisitTriggerHandler.missedVisit(missedVisits);
        }
       // Distance calculation
        VisitTriggerHandler.calculateDistance(Trigger.new, Trigger.oldMap);
    }

    /* -------------------------
       DAILY LOG ROLLUP
       ------------------------- */
    if ( (Trigger.isAfter && (Trigger.isUpdate || Trigger.isUndelete)) || (Trigger.isBefore && Trigger.isDelete) ) {
            Set<Id> dailyLogIds = new Set<Id>();
            if (Trigger.isUpdate || Trigger.isUndelete) {
                for (Visit__c v : Trigger.new) {
                    Visit__c oldV = Trigger.oldMap.get(v.Id);
                    if ( v.Daily_Log__c != null && ( v.Daily_Log__c != oldV.Daily_Log__c || (v.Distance__c != null && v.Distance__c != oldV.Distance__c))) {
                        dailyLogIds.add(v.Daily_Log__c);
                    }
                }
            } else {
                for (Visit__c v : Trigger.old) {
                    if (v.Daily_Log__c != null) {
                        dailyLogIds.add(v.Daily_Log__c);
                    }
                }
            }

        if (!dailyLogIds.isEmpty()) {
            VisitTriggerHandler.updateDailyLogs(dailyLogIds);
        }
    }
}