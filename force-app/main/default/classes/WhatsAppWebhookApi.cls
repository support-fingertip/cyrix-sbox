@RestResource(urlMapping='/whatsappWebhook/*')
global with sharing class WhatsAppWebhookApi {
    
    @HttpPost
    global static void handleWebhook() {
        Integer maxSize = 32000;
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String key = RestContext.request.params.get('key');
        Log__c log = new Log__c();
        String requestBody = req.requestBody.toString();
        if(requestBody.length() > maxSize ){
            log.Request__c = requestBody.substring(0, maxSize);
        }else{
            log.Request__c = requestBody;
        }
        if(Label.API_Key == key){
            try {
                leadWrapper cw = (leadWrapper) JSON.deserialize(requestBody, leadWrapper.class);
                if(cw !=null ){
                    if(cw.contact !=null){
                        list<lead> existLead =[select Id,Whatsapp_uid__c from lead where Whatsapp_uid__c=:cw.contact.uid];
                        lead ld = new lead();
                        ld.Whatsapp_Lead_Status__c =cw.contact.status;
                        ld.Whatsapp_uid__c = cw.contact.uid;
                        ld.FirstName = cw.contact.first_name;
                        ld.LastName = cw.contact.last_name;
                        ld.Email = cw.contact.email;
                        ld.Language_Code__c = cw.contact.language_code;
                        ld.webLead_country__c = cw.contact.country;
                        if(!existLead.isEmpty()){
                            ld.Id =existLead[0].Id;
                        }else{
                            ld.Company='.'; 
                        }
                        if(ld.Id == null){
                        list<AssignmentRule> leadAR = [SELECT Id  FROM AssignmentRule   WHERE SobjectType = 'Lead'   AND Active = true and Name='Telecaller Lead Assignment' LIMIT 1 ];//Fetch the active Lead Assignment Rule (if you want a specific rule, filter by Name)
                        if(!leadAR.isEmpty()){
                            Database.DMLOptions dmlOpts = new Database.DMLOptions();
                            dmlOpts.assignmentRuleHeader.assignmentRuleId = leadAR[0].Id; // leadassignment ruleId
                            Database.SaveResult sr = Database.insert(ld, dmlOpts);
                            if (sr.isSuccess()) {
                                ld.Id = sr.getId(); // so your response JSON still has ld.Id
                            } else {
                                Database.Error err = sr.getErrors()[0];
                                Error_Log__c erro = new Error_Log__c();
                                erro.className__c ='WebsiteAPIController';
                                erro.Message__c = err.getMessage()+' '+ err.getFields();
                                erro.User__c = UserInfo.getUserId();
                                database.insert(erro,false);  
                                insert ld;
                            }
                        }else{ upsert ld;} 
                        }else{
                            update ld;
                        }
                        res.statusCode = 200;
                        res.addHeader('Content-Type', 'application/json'); 
                        res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                            'success'=>true , 'Salesforce LeadId' => ld.Id }));
                    }
                    else{
                        res.statusCode = 400;
                        res.addHeader('Content-Type', 'application/json');
                        res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                            'success'=>false , 'Error' => 'Request body is missing' }));  
                        
                    }
                }else{
                    res.statusCode = 400;
                    res.addHeader('Content-Type', 'application/json');
                    res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                        'success'=>false , 'Error'=>'Request body missing'} ));  
                }
            } catch (Exception ex) {
                res.statusCode = 400;
                res.addHeader('Content-Type', 'application/json');
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                    'success'=> false ,'Error'=> ex.getMessage() }));
                log.Status_Code__c ='400';
                log.Status_Message__c='Failed';
            }
            
        }
    }                                                           


    global class leadWrapper {
        public ContactWrapper contact;
        public String source;
    }

    global class ContactWrapper {
        public String status;
        public String uid;
        public String first_name;
        public String last_name;
        public String email;
        public String language_code;
        public String country;
    }

   
    global class MessageWrapper {
        public String text;
        public Object media;
    }

    global class ResponseWrapper {
        public String status;
        public String message;
        public Id contactId;
        public Id eventId;
    }
}