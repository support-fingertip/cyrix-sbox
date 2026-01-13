public with sharing class LeadMergeController {
    /**************************************************************** 
* Class Name  : LeadMergeController  @Company  : Fingertip    @Created Date  : 15-10-2025  
@description : lead merge functionality controller   @author  :Nanma T V   @User By  : -Mergelead_Cmp
* Change Log: 
* ----------------------------------------------------------------------------- 
* Ver |   Author      |   Date        |   Description 
* ----------------------------------------------------------------------------- 
* 1.0 |   Nanma  |  15-10-2025 |   Initial version      
* -------------------------------------------------------------------
**************************************************************** */  
   
    @AuraEnabled(cacheable=true)
   public static  list<lead> duplicateLeads(string leadId){
           Set<String> leadSet = new Set<String>();
       map<Id,lead> leadExitMap = new map<Id,lead>();
        if(leadId == null)
           return null;
        
       list<Lead> leadList =[select Id,Name,email, phone, MobilePhone,Secondary_Email__c from lead where Id=:leadId limit 1];  
            lead l = leadList[0];
        if(l.Phone != null){
            string pho = String.valueOf(l.Phone);
            pho =pho.replaceAll('\\s+','');
            string len='%'+pho.right(10);
            leadSet.add(len);     
        }
        if(l.Mobilephone  != null){
            string mob = String.valueOf(l.Mobilephone);
            mob =mob.replaceAll('\\s+','');
            string len1='%'+mob.right(10);
            leadSet.add(len1);   
        }
        if(l.Email != null){
            leadSet.add(l.Email);
        }
        if(l.Secondary_Email__c != null){
            leadSet.add(l.Secondary_Email__c);
        }

        list<lead> dupLeadList =[select Id,Name,email, phone, MobilePhone,Secondary_Email__c from lead where (Phone like:leadSet or Mobilephone like:leadSet or Email in :leadSet or  Secondary_Email__c in :leadSet )  order by createddate];
        for(Lead ld : leadList){
                for(Lead lea : dupLeadList ){
                    string newMobno = '1', ExistMobno = '2', newPhno = '3', ExistPhno = '4';
                    if(ld.Mobilephone != null ){
                        newMobno =ld.Mobilephone.replaceAll('\\s+','');
                        newMobno = newMobno.right(10);  
                    }
                    if(lea.Mobilephone != null ){
                        ExistMobno =lea.Mobilephone.replaceAll('\\s+','');
                        ExistMobno = ExistMobno.right(10);  
                    }
                    if(l.Phone != null ){
                        newPhno =ld.Phone.replaceAll('\\s+','');
                        newPhno = newPhno.right(10); 
                    }
                    if(lea.Phone != null ){
                        ExistPhno =lea.Phone.replaceAll('\\s+','');
                        ExistPhno = ExistPhno.right(10);  
                    }   
                    if(l.Email == lea.Email || (lea.Secondary_Email__c !=null && ld.Email == lea.Secondary_Email__c) ||  (ld.Secondary_Email__c !=null && lea.Email == ld.Secondary_Email__c) || newMobno == ExistMobno || newPhno == ExistPhno || newMobno == ExistPhno || newPhno == ExistMobno ){
                        leadExitMap.put(lea.Id,lea);
                    }     
                }  
        }
        return leadExitMap.values();
    }

    @AuraEnabled
    public static LeadMergeWrapper fetchLeads(String firstLeadId, String secondLeadId) {
        List<Lead> leads = [
            SELECT Id, Name, Email, Phone, MobilePhone, Company,Lead_Category__c, LeadSource,Lead_ID__c,Lead_Owner_Name__c,CreatedDate,lastmodifieddate
            FROM Lead
            WHERE Id IN :new Set<Id>{firstLeadId, secondLeadId}
        ];
        if (leads.size() != 2) throw new AuraHandledException('Both leads must be valid.');

        Lead l1 = leads[0], l2 = leads[1];
        List<LeadFieldItem> fields = new List<LeadFieldItem>{
            new LeadFieldItem('Principal Record to Merge', 'Use as principal ('+l1.Lead_ID__c+')','Use as principal ('+l2.Lead_ID__c+')'),
                new LeadFieldItem('Name', l1.Name, l2.Name),
                new LeadFieldItem('Email', l1.Email, l2.Email),
                new LeadFieldItem('Primary Contact Number', l1.Phone, l2.Phone),
                new LeadFieldItem('Secondary Contact Number', l1.MobilePhone, l2.MobilePhone),
                new LeadFieldItem('Company/Institution', l1.Company, l2.Company),
                new LeadFieldItem('LeadSource', l1.LeadSource, l2.LeadSource),
                new LeadFieldItem('Lead Category', l1.Lead_Category__c, l2.Lead_Category__c),
                new LeadFieldItem('Lead Owner', l1.Lead_Owner_Name__c, l2.Lead_Owner_Name__c),
                new LeadFieldItem('Lead CreatedDate', l1.createddate.format('dd/MM/yyyy, h:mm a'), l2.createddate.format('dd/MM/yyyy, h:mm a')),  
                new LeadFieldItem('Last ModifiedDate', l1.Lastmodifieddate.format('dd/MM/yyyy, h:mm a'), l2.Lastmodifieddate.format('dd/MM/yyyy, h:mm a'))  
                };

        return new LeadMergeWrapper(l1, l2, fields);
    }

    @AuraEnabled 
public static string mergeLeads(lead firstLead, lead secondLead,Map<String, String> selectedFields) {
        
        string masterLeadCode,fieldApiName;
        lead masterLead = new lead();
        list<lead> duplicateLeadList = new list<lead>();
        system.debug('selectedFields'+selectedFields);
        // Apply selected fields to master lead
        for (String fieldName : selectedFields.keySet()) {
            if(fieldName.contains('Principal Record to Merge')){
                masterLeadCode =  getCodeInsideBrackets(selectedFields.get(fieldName));
                
                if(firstLead.Lead_ID__c == masterLeadCode){
                    masterLead.Id = firstLead.Id;
                    duplicateLeadList.add(secondLead);
                }else if(secondLead.Lead_ID__c == masterLeadCode){
                    masterLead.Id = secondLead.Id; 
                    duplicateLeadList.add(firstLead);
                }
            }
            system.debug(masterLead);
            if(fieldName != 'Owner Name' && !fieldName.contains('Principal Record to Merge')){
                String value = selectedFields.get(fieldName);
                fieldApiName=getValidFieldNameApi(fieldName);   
                if (value == '[Empty]') {
                    masterLead.put(fieldApiName, null);
                }else if(fieldApiName !='Invalid option'){
                    system.debug(fieldApiName);
                    masterLead.put(fieldApiName, value);  
                }
            }
        }
        update masterLead;
        Database.merge(masterLead, duplicateLeadList, true);
    return masterLead.Id;
    }
    
    public static string getValidFieldNameApi(string labelValue){
        string result;
        if (labelValue == 'Name') {
            result = 'LastName';
        } else if (labelValue == 'Secondary Contact Number') {
            result = 'MobilePhone';
        } else if (labelValue == 'Primary Contact Number') {
            result = 'Phone';
        } else if (labelValue == 'Email') {
            result = 'Email';
        } else if (labelValue == 'SECONDARY EMAIL') {
            result = 'Secondary_Email__c';
        } else if (labelValue == 'Company/Institution') {
            result = 'Company';
        } else if (labelValue == 'LeadSource') {
            result = 'LeadSource';
        }else if (labelValue == 'Lead Category') {
            result = 'Lead_Category__c';
        }   else {
            result = 'Invalid option';
        }
        
        return result;
    }
     public static String getCodeInsideBrackets(String input) {
        // Regular expression to match the content inside parentheses
        Pattern p = Pattern.compile('\\((.*?)\\)');
        Matcher m = p.matcher(input);
        
        if (m.find()) {
            // Return the matched code inside parentheses
            return m.group(1); 
        }
        
        return null; // If no match found
    }
    public class LeadMergeWrapper {
        @AuraEnabled public Lead firstLead;
        @AuraEnabled public Lead secondLead;
        @AuraEnabled public List<LeadFieldItem> fieldset;

        public LeadMergeWrapper(Lead l1, Lead l2, List<LeadFieldItem> fields) {
            this.firstLead = l1;
            this.secondLead = l2;
            this.fieldset = fields;
        }
    }

    public class LeadFieldItem {
        @AuraEnabled public String label;
        @AuraEnabled public String value1;
        @AuraEnabled public String value2;

        public LeadFieldItem(String label, String v1, String v2) {
            this.label = label;
            this.value1 = v1 != null ? v1 : '[Empty]';
            this.value2 = v2 != null ? v2 : '[Empty]';
        }
    }
    
}