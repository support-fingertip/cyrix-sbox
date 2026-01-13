public class ExceptionHandler {
    
    public static void addLog(Exception ae,String data){
        Error_Log__c err = new Error_Log__c();
        err.LineNumber__c = ae.getLineNumber();
        err.Message__c = ae.getMessage();
        err.StackTrace__c = ae.getStackTraceString();
        err.Type__c = ae.getTypeName();
        err.User__c = UserInfo.getUserId();
        err.RecordData__c = data;
        database.insert(err,false);  
    }
      public static void addLog(Exception ae,String data,string className,string recordId){
        Error_Log__c err = new Error_Log__c();
        err.LineNumber__c = ae.getLineNumber();
        err.Message__c = ae.getMessage();
        err.StackTrace__c = ae.getStackTraceString();
        err.Type__c = ae.getTypeName();
        err.User__c = UserInfo.getUserId();
        err.RecordData__c = data;
          err.className__c =className;
          err.Record_Id__c =recordId;
        database.insert(err,false);  
    }
    public static void addLog(Integer line,String msg,String str,String typ,String data){
        Error_Log__c err = new Error_Log__c();
        err.LineNumber__c = line;
        err.Message__c = msg;
        err.StackTrace__c = str;
        err.Type__c = typ;
        err.User__c = UserInfo.getUserId();
        err.RecordData__c = data;
        database.insert(err,false);  
    }
    public static void addLog(Exception ae){
        Error_Log__c err = new Error_Log__c();
        err.LineNumber__c = ae.getLineNumber();
        err.Message__c = ae.getMessage();
        err.StackTrace__c = ae.getStackTraceString();
        err.Type__c = ae.getTypeName();
        err.User__c = UserInfo.getUserId();
        database.insert(err,false);  
    }
    
}