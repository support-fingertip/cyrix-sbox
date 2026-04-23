@RestResource(urlMapping='/sapapi/*')
global class sapApiController {
    
    @HttpGet
    global static void  doGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String url = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
        String key = RestContext.request.params.get('key');
        system.debug('key:'+ key);
        String value = RestContext.request.params.get('value');
        system.debug('value:'+ value);
       // SObjectType sObjType = ((SObject) Type.forName(objectName).newInstance()).getSObjectType();
         string query ='',jsonString='';
        String objectname=RestContext.request.params.get('value');
     getResponse g = new getResponse();
        
        getResponse resp = new getResponse(); 
        if(Label.API_Key == key){
             if(objectname == 'customer' || objectname == ''){
            List<account> aList = new  List<account>();
            aList = [SELECT Id,Name from account limit 1];
                      customerResponseWrapper cw = new customerResponseWrapper();
                    cw.data = aList;
                    g =cw;

        }
                 
                Map<String,Object> dataMap = (Map<String,Object>)JSON.deserializeUntyped(JSON.serialize(g));
                Map<String,Object> responseMap = removeAttributes(dataMap);
                jsonString = JSON.serialize(responseMap);
                jsonString = jsonString.replace('{"records":', '').replace('"done":true},','');
                res.responseBody = Blob.valueOf(jsonString); 
                Map<String, String> resMap = new Map<String, String>();
                resMap.put('Content-Type', 'application/json');
                res.statusCode = 200; // OK
                
                
            }
        
   
        res.responseBody = Blob.valueOf(JSON.serialize(g));   
        
       
    }
    
  private static Map<String,Object> removeAttributes(Map<String,Object> jsonObj)  {
        for(String key : jsonObj.keySet()) {
            if(key == 'attributes' || key=='totalSize') {
                jsonObj.remove(key);
            } else {
                if(jsonObj.get(key) == null){
                    jsonObj.remove(key);
                }
                if(jsonObj.get(key) instanceof Map<String,Object>) {
                    removeAttributes((Map<String,Object>)jsonObj.get(key));
                }
                if(jsonObj.get(key) instanceof List<Object>) {
                    for(Object listItem : (List<Object>)jsonObj.get(key)) {
                        if(listItem instanceof Map<String,Object>)  {
                            removeAttributes((Map<String,Object>)listItem);
                        }
                    }
                }
            }
        }  
        return jsonObj;
    }   
    
    
    
    
    //Get customer data  Response
    global class customerResponseWrapper extends getResponse {
        public list<account> data = new list<account>();
    }
       public class response{
        public String SF_RecordId;
        public String TallyUniqueId;
        public string Status;
        public string Message;  
    } 
      global virtual class getResponse{
        
    }
  
}