public class Utility {
    /**************************************************************** 
* Class Name  :Utility   @Company  : Fingertip    @Created Date  : 10-10-2025  
@description : general utility class  @author  :Nanma T V   @User By  : - leadtriggerHandler
* Change Log: 
* ----------------------------------------------------------------------------- 
* Ver |   Author      |   Date        |   Description 
* ----------------------------------------------------------------------------- 
* 1.0 |   Nanma  |  10-10-2025 |   Initial version      
* -------------------------------------------------------------------
**************************************************************** */
   @auraEnabled
    public string objectName{get;set;}
     @auraEnabled
    public string profileName{get;set;} 
    
     public static Map<String, String> getAllCountryCodeMappings(Boolean codeAsKey) {
        Map<String, String> countryCodeMappingsMap = new Map<String, String>();
        List<Country_Code_Mapping__mdt> countryList = [SELECT Label, CountryCode__c FROM Country_Code_Mapping__mdt ];
        for(Country_Code_Mapping__mdt co : countryList) {
            if(codeAsKey){
                countryCodeMappingsMap.put(co.CountryCode__c,co.Label);
            }else{
                countryCodeMappingsMap.put(co.Label,co.CountryCode__c);
            }
        }
        return countryCodeMappingsMap;
    }  
   @auraEnabled  
    public static Utility getObjectAndCurrentUser(string recordId){

        if(recordId ==null){
            return null;
        }
        Utility u= new Utility();
        if(recordId != null && recordId !=''){
            Id recId =recordId;
            u.objectName = recId.getSObjectType().getDescribe().getName();
    }
    u.profileName=[select Id,profile.Name from user where Id=:userinfo.getuserId()].profile.Name;    
        return u;
    }
}