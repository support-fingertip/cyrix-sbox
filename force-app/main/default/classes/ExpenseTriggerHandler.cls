public with sharing class ExpenseTriggerHandler {

    public static void afterInsert(List<Expense__c> newExpenses) {
   if (newExpenses == null || newExpenses.isEmpty()) {
            return;
        }
        // Fetch General Settings safely
        List<General_Settings__c> settingsList = [SELECT Id, Expense_Level_1_Approver__c,   Expense_Level_2_Approver__c  FROM General_Settings__c LIMIT 1];
       list<Id> userList = new list<Id>();
        map<Id,Id> userManagerMap = new map<Id,Id>();
        for (Expense__c exp : newExpenses) {
            userList.add(exp.OwnerId);
        }
         list<user> expOwnerList =[select id,ManagerId  from user where Id in:userList];
        if(!expOwnerList.isEmpty()){
            for(user u : expOwnerList){
                if(u.ManagerId != null){
                userManagerMap.put(u.Id,u.ManagerId);    
                }
            }
        }
        // Apply approvers
        for (Expense__c exp : newExpenses) {
 
            if(userManagerMap.containsKey(exp.OwnerId)){
                exp.Expense_Approver_L1__c = userManagerMap.get(exp.OwnerId);
            }else {
                if (settingsList[0].Expense_Level_1_Approver__c != null) 
                exp.Expense_Approver_L1__c =  settingsList[0].Expense_Level_1_Approver__c;
            }
         
            if (settingsList[0].Expense_Level_2_Approver__c != null) {
                exp.Expense_Finance_Department_Approver__c =settingsList[0].Expense_Level_2_Approver__c;
            }
        }
    }
}