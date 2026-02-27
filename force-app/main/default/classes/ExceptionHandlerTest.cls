@isTest
public class ExceptionHandlerTest {

    public static testmethod void test1(){
        Exception ex = new DMLException();
        ex.setMessage('dd');
        ExceptionHandler.addLog(ex,'test');
        ExceptionHandler.addLog(ex,'test','test','test');
        ExceptionHandler.addLog(ex);
    }
}