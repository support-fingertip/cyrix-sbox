@RestResource(urlMapping='/api/*')
global without sharing class SAPIntegrationController {

/* Class Name   : SAPIntegrationController
* Company      : Fingertipplus
* Created Date : 30-03-2026
* @description : REST API for SAP Product integration.
*                Supports POST (upsert products from SAP) and GET (retrieve products) JSON format: {"data":[{...product fields...}]}
*
* Change Log:
* -----------------------------------------------------------------------------
* Ver | Author           | Date       | Description
* -----------------------------------------------------------------------------
* 1.0 | Nanma     | 30-03-2026 | Initial version
* -----------------------------------------------------------------------------
**************************************************************/

 global static void  doPost() {
        RestRequest req=RestContext.request;
        RestResponse res = RestContext.response;
        
        String url = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
        String key = RestContext.request.params.get('key');
        String value = RestContext.request.params.get('value');
        String data = req.requestBody.toString();
        system.debug('data:' + data);
        
        String postfix = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
        if(Label.SAP_API == key){
            
            Map<String, Object> prodMap = (Map<String, Object>) JSON.deserializeUntyped(data);
            Map<String, Object> prodMap2 = (Map<String, Object>) JSON.deserializeUntyped(data);
            
            for(String key2 : prodMap2.keySet()) {
                
                if(prodMap2.get(key2) == null){
                    prodMap2.remove(key2);
                }
            }
            
            
            List<string > finalJsonString = new List<string>();
            List<Map<String, Object>> datalist = new List<Map<String, Object>>();
            
            for (Object instance : (List<Object>)prodMap.get('data')){
                
                finalJsonString.add(JSON.serialize(instance)); 
                datalist.add((Map<String, Object>)instance);
            }
            
            system.debug('finalJsonString:' + finalJsonString);
            
            Map<String, Object> succMap = new Map<String, Object>();
            Map<String, Object> errMap = new Map<String, Object>();
            
            if(value == 'productMaster'){
                
                List < Response > lstResponse = new List < Response > ();
                
                List<Product2> prdlist = new List<Product2>();
                List<String> prdIds = new List<String>();
                for(string s: finalJsonString){
                    s = s.replaceFirst('\\{', '{"attributes" : {"type" : "Product2", "referenceId" : "ref1"},');
                    Product2 prd = (Product2)JSON.deserialize(s, Sobject.class);
                    System.debug('prd '+ prd);
        
                    try{
                        upsert prd Item_Code__c;
                
                    }
                    catch(DmlException ex){
                     
                   
                       
                    }
                    
                }
                res.statusCode = 200;
                res.addHeader('Content-Type', 'application/json');
                res.responseBody = Blob.valueOf(JSON.serialize(lstResponse));
                
                if(label.Enable_Logs == 'TRUE'){
                    String reqsizeString = data;
                    Integer maxSize = 32000;
                    if(reqsizeString.length() > maxSize ){
                        reqsizeString = reqsizeString.substring(0, maxSize);
                    }
                    String ressizeString = JSON.serialize(lstResponse);
                    if(ressizeString.length() > maxSize ){
                        ressizeString = ressizeString.substring(0, maxSize);
                    }                    
                    Log__c getLogs = new Log__c();
                    getLogs.Request__c = reqsizeString;
                    getLogs.Response__c = ressizeString;
                    getLogs.Object__c = 'Product';
                    getLogs.Status_Code__c = string.valueof(res.statusCode);
                    insert getLogs;

                }
                
            }
           
            else{
                
                List < Response > lstResponse = new List < Response > ();
               // lstResponse.add(new Response('Failure', 'Invalid Parameter Value.',false));
                res.statusCode = 403;
                res.addHeader('Content-Type', 'application/json');
                res.responseBody = Blob.valueOf(JSON.serialize(lstResponse));   
               
            }
            
        }
        else{
              
            List < Response > lstResponse = new List < Response > ();
       //     lstResponse.add(new Response('Failure', 'Invalid Key.',false));
            res.statusCode = 401;
            res.addHeader('Content-Type', 'application/json');
            res.responseBody = Blob.valueOf(JSON.serialize(lstResponse));               
            //return errorJson;
        }
        
        
    }
    
   public class response{
        public String SF_RecordId;
        public String SAPUniqueId;
        public string Status;
        public string Message;  
    }
}