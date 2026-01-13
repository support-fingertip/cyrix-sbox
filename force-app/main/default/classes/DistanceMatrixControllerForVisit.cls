public class DistanceMatrixControllerForVisit 
{
    
    //From Visit Trigger we calling this method
    
    public static void distanceCalculation(List<String> visitIds){
        try{
            if(visitIds == null || visitIds.isEmpty()) return;
            
            List<Visit__c> visitsToUpdate = new List<Visit__c>();
            
            // Collect visit data and daily logs in bulk
            List<Visit__c> visits = [SELECT Id, Name, Visit_Start__c, Visit_for__c, Lead__c, Account__c,
                                     Check_In_Location__Latitude__s, Check_In_Location__Longitude__s, Distance__c, 
                                     OwnerId, Daily_Log__c 
                                     FROM Visit__c WHERE Id IN :visitIds];
            
            // Create a map to store visit id and their corresponding distance
            Map<Id, Decimal> visitDistanceMap = new Map<Id, Decimal>();
            
            // Collect related Daily_Log__c records
            Set<Id> dailyLogIds = new Set<Id>();
            for(Visit__c vis : visits) {
                if(vis.Daily_Log__c != null) {
                    dailyLogIds.add(vis.Daily_Log__c);
                }
            }
            
            // Query Daily Logs in bulk
            Map<Id, Daily_Log__c> dailyLogsMap = new Map<Id, Daily_Log__c>(
                [SELECT Id, Clock_In_Location__Latitude__s, Clock_In_Location__Longitude__s 
                 FROM Daily_Log__c WHERE Id IN :dailyLogIds]);
            
            // Collect OwnerId and Visit Start Dates for previous visits query
            Set<Id> visitsOwnerIds = new Set<Id>();
            Set<Date> visitDates = new Set<Date>();
            for(Visit__c vis : visits) {
                visitsOwnerIds.add(vis.OwnerId);
                visitDates.add(vis.Visit_Start__c.date());
            }
            
            // Query all previous visits for the same owner on the same day
            List<Visit__c> prevVisits = [SELECT Id, OwnerId, Visit_Start__c, 
                                         Check_In_Location__Latitude__s, Check_In_Location__Longitude__s 
                                         FROM Visit__c 
                                         WHERE OwnerId IN :visitsOwnerIds 
                                         AND DAY_ONLY(Visit_Start__c) IN :visitDates
                                         AND Visit_Start__c < :visits[0].Visit_Start__c
                                         ORDER BY Visit_Start__c DESC];
            
            // Create a map of previous visits by visit Id for quick lookup
            Map<Id, Visit__c> prevVisitMap = new Map<Id, Visit__c>();
            for (Visit__c prevVisit : prevVisits) {
                prevVisitMap.put(prevVisit.OwnerId, prevVisit);
            }
            
            // Process each visit
            for(Visit__c vis : visits) {
                Decimal distance = 0;
                Date visitDate = vis.Visit_Start__c.date();
                
                // Get the previous visit for the same owner on the same day
                Visit__c prevVisit = prevVisitMap.get(vis.OwnerId);
                
                if (prevVisit != null && prevVisit.Check_In_Location__Latitude__s != null && prevVisit.Check_In_Location__Longitude__s != null) {
                    distance = calculateHaversineDistance(
                        prevVisit.Check_In_Location__Latitude__s, 
                        prevVisit.Check_In_Location__Longitude__s, 
                        vis.Check_In_Location__Latitude__s, 
                        vis.Check_In_Location__Longitude__s
                    );
                } 
                // If no previous visit, use daily log location for distance calculation
                else if (vis.Daily_Log__c != null && dailyLogsMap.containsKey(vis.Daily_Log__c)) {
                    Daily_Log__c dl = dailyLogsMap.get(vis.Daily_Log__c);
                    if (dl.Clock_In_Location__Latitude__s != null && dl.Clock_In_Location__Longitude__s != null) {
                        distance = calculateHaversineDistance(
                            dl.Clock_In_Location__Latitude__s, 
                            dl.Clock_In_Location__Longitude__s, 
                            vis.Check_In_Location__Latitude__s, 
                            vis.Check_In_Location__Longitude__s
                        );
                    }
                }
                
                // Store the calculated distance for each visit in the map
                if (distance != 0) {
                    visitDistanceMap.put(vis.Id, distance);
                }
            }
            
            // Update visits with calculated distances
            for (Visit__c vis : visits) {
                if (visitDistanceMap.containsKey(vis.Id)) {
                    vis.SF_Distance__c = visitDistanceMap.get(vis.Id);
                    visitsToUpdate.add(vis);
                }
            }
            
            if (!visitsToUpdate.isEmpty()) {
                system.debug('visitsToUpdate'+visitsToUpdate);
                update visitsToUpdate;
            }
        }catch(exception ex){}
        
    }
    
    //From Daily log Trigger we are callint this method
    /*  @future(callout=true)
public static void distanceCalculationForLastVisit(string dlId,decimal l1lat, decimal l1long,decimal  l2lat,decimal l2long){
Daily_log__c dl = new Daily_log__c();
dl.Id = dlId;
//get Location from API
/* if(label.ActivateGMapAPI == 'True')
{
Decimal distance = distanceCalculationinKM(l1lat,l1long,l2lat,l2long);
dl.Last_visit_distance__c = distance;
}*/
    //Salesforce Standard Location 
    //  Decimal distanceSalesfroce = calculateHaversineDistance(l1lat,l1long,l2lat,l2long);
    //  dl.Last_Visit_Distance_Salesforce__c = distanceSalesfroce;
    //  Update dl;   
    // }*/
    
    public static Decimal calculateHaversineDistance(Decimal lat1, Decimal lon1, Decimal lat2, Decimal lon2){
        // Earth's radius varies from 6356.752 km at the poles to 6378.137 km at the equator
        Double radius = 6371.00;
        Double dLat = toRadians(lat2-lat1);
        Double dLon = toRadians(lon2-lon1);
        Double a = Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
            Math.sin(dLon/2) * Math.sin(dLon/2);
        Double c = 2 * Math.asin(Math.sqrt(a));
        
        double kmToMiles = 0.621371;
        return radius * c * kmToMiles;
    }
    
    private static Double toRadians(Decimal degree){
        return degree * 3.1415926 / 180;
    }
    
    //Calling Google matrix api to get distance
    /*   public static decimal distanceCalculationinKM(decimal l1lat, decimal l1long,decimal  l2lat,decimal l2long){ 
string ApiKey = label.DistanceMatrixApi_Key;
string url = 'https://maps.googleapis.com/maps/api/distancematrix/json?';   
url = url + 'origins='+ l1lat+','+ l1long;
url = url + '&destinations='+ l2lat+','+ l2long;           
url = url + '&key='+ApiKey;   
HttpRequest req = new HttpRequest();
req.setEndpoint(url);
req.setMethod('GET');    
Http http = new Http();

if(!test.isrunningtest()){


HTTPResponse res = http.send(req);
System.debug(res.getBody());

distancematrix dm =  (distancematrix)JSON.deserialize(res.getBody(),distancematrix.class);   
if( ( dm.rows.size() > 0 )&& ( dm.rows[0].elements.size() > 0 )  ){
system.debug(dm.rows[0].elements[0].distance.value/1000);
return dm.rows[0].elements[0].distance.value/1000; 

}else{ 
return 0;
} 


}else{
return 0; 
} 

}*/
    
    public class distancematrix{  
        public List<row> rows;   
    } 
    public class row{ 
        public List<element> elements;
    }
    public class element{ 
        public duration duration;
        public distance distance;
    }
    public class distance{ 
        public  string text;
        public  decimal value; 
    }
    public class duration{ 
        public  string text;
        public  decimal  value; 
    }
    
}