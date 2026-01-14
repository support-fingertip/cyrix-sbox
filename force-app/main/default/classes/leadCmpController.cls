public class leadCmpController {
    @auraEnabled
    public list<Map_Sub_Region__c> subRegions {get;set;}
      @auraEnabled
    public Region__c region {get;set;}
    
    @auraEnabled(cacheable=true)
    public static leadCmpController fetchLead(string leadId){
        if (String.isEmpty(leadId)) {
            return null;
        }
        lead lead =[select id ,Region__c,Region__r.Name from lead where Id=:leadId];
        if(lead.Region__c !=null){
            list<Map_Sub_Region__c> subRegions = new list<Map_Sub_Region__c>();
            leadCmpController l = new leadCmpController();
            l.region =[select Id,Name from Region__c where Id=:lead.Region__c];
            l.subRegions =[select Id,name,Sales_Engineer__c,Sales_Engineer__r.Name,ASM__c,ASM__r.Name from Map_Sub_Region__c where Region__c=:lead.Region__c and Active__c=true];
          return l;
        }else{
           return null;
        }
       
    }

  @auraEnabled
  public static void leadAssignment(string leadOwnerId,string leadId){
    lead ld = new lead();
        ld.Id = leadId;
          ld.ownerId =leadOwnerId;        
    update ld;
  }
}