trigger Opportunity_Trigger on Opportunity (before insert, after insert, before update, after update) {
    /****************************************************************
    * Trigger Name : Opportunity_Trigger  @Company : Fingertip    @Created Date : 2026-03-25
    * @description : Opportunity object trigger - handles auto-numbering, stage notifications,
    *                assignment notifications, and Closed Won/Lost logic per BRD.
    * @author : Claude AI   @Used By : OpportunityTriggerHandler
    * Change Log:
    * -----------------------------------------------------------------------------
    * Ver |   Author        |   Date        |   Description
    * -----------------------------------------------------------------------------
    * 1.0 |   Claude AI     |  2026-03-25   |   Initial version
    * -------------------------------------------------------------------
    **************************************************************** */

    // ───────────── BEFORE INSERT ─────────────
    if (Trigger.operationType == TriggerOperation.BEFORE_INSERT) {
        OpportunityTriggerHandler.generateAutoNumber(Trigger.new);
        OpportunityTriggerHandler.setDefaultStage(Trigger.new);
        OpportunityTriggerHandler.setOpportunityName(Trigger.new);
    }

    // ───────────── BEFORE UPDATE ─────────────
    if (Trigger.operationType == TriggerOperation.BEFORE_UPDATE) {
        OpportunityTriggerHandler.setOpportunityName(Trigger.new);
    }

    // ───────────── AFTER INSERT ─────────────
    if (Trigger.operationType == TriggerOperation.AFTER_INSERT) {
        List<Opportunity> assignmentList = new List<Opportunity>();
        List<Opportunity> campaignList = new List<Opportunity>();

        for (Opportunity opp : Trigger.new) {
            assignmentList.add(opp);
          /*  if (opp.Campaign__c != null) {
                campaignList.add(opp);
            }*/
        }
        if (!assignmentList.isEmpty()) {
            OpportunityTriggerHandler.sendAssignmentNotification(assignmentList);
        }
        /*if (!campaignList.isEmpty()) {
            OpportunityTriggerHandler.campaignMapping(campaignList);
        }*/
    }

    // ───────────── AFTER UPDATE ─────────────
    if (Trigger.operationType == TriggerOperation.AFTER_UPDATE) {
        List<Opportunity> stageChangedList = new List<Opportunity>();
        List<Opportunity> reassignedList = new List<Opportunity>();
        List<Opportunity> closedWonList = new List<Opportunity>();
        List<Opportunity> closedLostList = new List<Opportunity>();
        List<Opportunity> campaignList = new List<Opportunity>();

        for (Opportunity opp : Trigger.new) {
            Opportunity oldOpp = Trigger.oldMap.get(opp.Id);

            // Stage change notification
            if (opp.StageName != oldOpp.StageName) {
                stageChangedList.add(opp);

                if (opp.StageName == 'Closed Won') {
                    closedWonList.add(opp);
                }
                if (opp.StageName == 'Closed Lost') {
                    closedLostList.add(opp);
                }
            }

            // Owner change (reassignment)
            if (opp.OwnerId != oldOpp.OwnerId) {
                reassignedList.add(opp);
            }

            // Campaign changed or newly set
           // if (opp.Campaign__c != null && opp.Campaign__c != oldOpp.Campaign__c) {
             //   campaignList.add(opp);
            //}
        }

        if (!stageChangedList.isEmpty()) {
            OpportunityTriggerHandler.sendStageChangeNotification(stageChangedList);
        }
        if (!reassignedList.isEmpty()) {
            OpportunityTriggerHandler.sendAssignmentNotification(reassignedList);
        }
        if (!closedWonList.isEmpty()) {
            OpportunityTriggerHandler.sendClosedWonNotification(closedWonList);
        }
        if (!closedLostList.isEmpty()) {
            OpportunityTriggerHandler.sendClosedLostNotification(closedLostList);
        }
        if (!campaignList.isEmpty()) {
          //  OpportunityTriggerHandler.campaignMapping(campaignList);
        }
    }
}