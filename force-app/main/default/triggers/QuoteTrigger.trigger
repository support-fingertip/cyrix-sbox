trigger QuoteTrigger on Quote (before insert, before update) {
    if(trigger.isInsert ){
        
        Branch__c b =[select Id from Branch__c limit 1 ];
        for(Quote q :trigger.New){
            q.branch__c=b.Id;
            q.Version_Nmber__c=1;
        }
        // Generate names for new quotes and for quotes where Branch or Revision_Number changed
        quoteTriggerHandler.generateQuoteNames(Trigger.new);
    }
    if(trigger.isUpdate){
         for(Quote q :trigger.New){
             if(q.Status =='Revision' &&q.Status  !=trigger.oldMap.get(q.Id).Status){
                 q.Version_Nmber__c =q.Version_Nmber__c ==null?1 :(q.Version_Nmber__c+1);
                     q.Status='Draft';
                   if (q.Version_Nmber__c != null && q.Version_Nmber__c > 1) {
                 string oldversionNumber ='-RV'+trigger.oldMap.get(q.Id).Version_Nmber__c;
                   string newversionNumber ='-RV'+  q.Version_Nmber__c;
                 q.Name = q.Name.replace(oldversionNumber,newversionNumber);
                   }else{
                       q.Name= q.Name+'-RV'+  q.Version_Nmber__c; 
                   }
             }
        } 
    }
       
  
}