trigger QuoteTrigger on Quote (before insert, before update) {
    if(trigger.isInsert ){
        
        Branch__c b =[select Id from Branch__c limit 1 ];
        for(Quote q :trigger.New){
            q.branch__c=b.Id;
            q.Version_Nmber__c=0;
            integer numberofDays =integer.valueof(q.Quote_Valid_Till_in_days__c);
            date todayDate =system.today();
            q.Valid_Till__c = todayDate.addDays(numberofDays);
            q.ExpirationDate =todayDate.addDays(numberofDays);
        }
        // Generate names for new quotes and for quotes where Branch or Revision_Number changed
        quoteTriggerHandler.generateQuoteNames(Trigger.new);
    }
    if(trigger.isUpdate){
         for(Quote q :trigger.New){
             if(q.Status =='Revision' &&q.Status  !=trigger.oldMap.get(q.Id).Status){
                 q.Version_Nmber__c =q.Version_Nmber__c ==null?0 :(q.Version_Nmber__c+1);
                     q.Status='Draft';
                 q.Revised_Date__c =system.today();
                 integer VersionNmber = integer.valueof(q.Version_Nmber__c);
                 if(VersionNmber != null && VersionNmber == 1){
                       q.Name= q.Name+'-RV'+ VersionNmber; 
                   }else if (VersionNmber != null && VersionNmber > 1) {
                 string oldversionNumber ='-RV'+trigger.oldMap.get(q.Id).Version_Nmber__c;
                   string newversionNumber ='-RV'+ VersionNmber;
                 q.Name = q.Name.replace(oldversionNumber,newversionNumber);
                   }
             }
        } 
    }
       
  
}