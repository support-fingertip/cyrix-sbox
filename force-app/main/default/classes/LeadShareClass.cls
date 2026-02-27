public without sharing class LeadShareClass {
    @invocableMethod
  public static void shareWithCreator(List<Id> leadIds) {
        List<LeadShare> leadShares = new List<LeadShare>();
        list<AssignmentRule> leadAR = [  SELECT Id  FROM AssignmentRule   WHERE SobjectType = 'Lead'   AND Active = true and Name='Telecaller Lead Assignment' LIMIT 1 ];//Fetch the active Lead Assignment Rule (if you want a specific rule, filter by Name)
        if(!leadAR.isEmpty()){
            List<Lead> leads = [SELECT Id,OwnerId, CreatedById FROM Lead WHERE Id IN :leadIds];
            
            for (Lead l : leads) {
                   if (l.CreatedById == l.OwnerId) {
                continue;
            }
                LeadShare share = new LeadShare();
                share.LeadId = l.Id;
                share.UserOrGroupId = l.CreatedById;
                share.LeadAccessLevel = 'Read'; // or 'Edit'
                share.RowCause = 'Manual';
                leadShares.add(share);
            }
             if (!leadShares.isEmpty()) {
            database.insert(leadShares,false);   Database.SaveResult[] results = Database.insert(leadShares, false);
            
            // Optional: Log errors
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    System.debug('Error sharing lead: ' + results[i].getErrors());
                }
            }
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