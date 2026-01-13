public class CalculateDistanceAPI {
    /**************************************************************** 
* Class Name  : CalculateDistanceAPI  @Company  : Fingertip    @Created Date  : 29-9-2025  
@description : CalculateDISTANCE USING GOOGLE API   @author  :Nanma T V   @User By  : -visitrigger
* Change Log: 
* ----------------------------------------------------------------------------- 
* Ver |   Author      |   Date        |   Description 
* ----------------------------------------------------------------------------- 
* 1.0 |   Nanma  |  05-01-2025 |   Initial version      
* -------------------------------------------------------------------*/
    
    /*@methodName:distanceCalculation API call @param1:dailylogIds @des : visit calculation*/
    @future(callout=true)
    public static void distanceCalculation(List<String> dailyLogIds){
        list<log__c> logs= new list<log__c>();
        list<Daily_Log__c> dailylogsToUpdate= new list<Daily_Log__c>();
        list<Visit__c> visitsToUpdate= new list<Visit__c>();
        map<Id,Daily_Log__c> dailylogMap = new  map<Id,Daily_Log__c>([select Id,KMs_Travelled__c,Last_visit_distance__c,Distance_Calculated_by_Google_API__c,Clock_In_Location__Latitude__s,Clock_In_Location__Longitude__s,
                                                                      Clock_Out_Location__Latitude__s,Clock_Out_Location__Longitude__s,
                                                                      (select Id, Name, Visit_Start__c, Visit_for__c, Lead__c, Account__c,
                                                                       Check_In_Location__Latitude__s, Check_In_Location__Longitude__s, Distance__c, 
                                                                       OwnerId, Daily_Log__c,Distance_Calculated_by_Google_API__c  from Visits__r where Status__c!='Planned' and Status__c!='Missed' order by Visit_Start__c asc ) from Daily_Log__c WHERE Id IN :dailyLogIds order by createddate desc]);
        
        
        for(Daily_Log__c d : dailylogMap.values()){
            integer noOfvisit =d.Visits__r.size();
            distanceValue dis = new distanceValue();
            
            if(noOfvisit != 0 ){
                if(  d.Clock_In_Location__Latitude__s !=null && d.Clock_In_Location__Longitude__s !=null ){ //first vist daily log checkin to first visit chekin
                    Visit__c visit =new Visit__c();
                    visit =d.Visits__r[0];
                    if(visit.Check_In_Location__Latitude__s !=null && visit.Check_In_Location__Longitude__s !=null){
                        dis =distanceCalculationinKM( d.Clock_In_Location__Latitude__s, d.Clock_In_Location__Longitude__s,visit.Check_In_Location__Latitude__s ,visit.Check_In_Location__Longitude__s);
                        visit.Distance__c =dis.distance;
                        visit.Distance_Calculated_by_Google_API__c =true;
                        logs.add(dis.log);
                        visitsToUpdate.add(visit);
                    }
                }
                
                if(noOfvisit >1){ //more than one visit
                    list<Visit__c > visits =new list<Visit__c >();
                    visits =d.Visits__r;
                    for(integer i=1 ; i<noOfvisit;i++ ){
                        
                        system.debug(visits[i].name);
                        if( visits[i].Distance_Calculated_by_Google_API__c  ){
                            continue;
                        }
                        if(visits[i-1].Check_In_Location__Latitude__s !=null && visits[i-1].Check_In_Location__Longitude__s !=null && visits[i].Check_In_Location__Latitude__s !=null && visits[i].Check_In_Location__Longitude__s !=null){
                            dis =distanceCalculationinKM(visits[i-1].Check_In_Location__Latitude__s ,visits[i-1].Check_In_Location__Longitude__s,visits[i].Check_In_Location__Latitude__s ,visits[i].Check_In_Location__Longitude__s );
                            visits[i].Distance__c =dis.distance;
                            visits[i].Distance_Calculated_by_Google_API__c =true;
                            logs.add(dis.log);
                            visitsToUpdate.add(visits[i]);
                        }
                    }
                    
                }
            }
            if(d.Clock_Out_Location__Latitude__s !=null && d.Clock_Out_Location__Longitude__s !=null ){ //completed daily log
                if(noOfvisit >0){ // last visit
                    Visit__c visit =new Visit__c();
                    if(noOfvisit ==1 ){
                        visit =d.Visits__r[0];
                    }else{
                        visit =d.Visits__r[noOfvisit -1];
                    }
                    if(visit.Check_In_Location__Latitude__s !=null && visit.Check_In_Location__Longitude__s !=null){
                        dis =distanceCalculationinKM( visit.Check_In_Location__Latitude__s ,visit.Check_In_Location__Longitude__s,d.Clock_Out_Location__Latitude__s ,d.Clock_Out_Location__Longitude__s );
                        d.Distance_Calculated_by_Google_API__c =true;  
                     //   visit.Distance__c =dis.distance;
                       // visit.Distance_Calculated_by_Google_API__c =true;
                        d.Last_visit_distance__c =dis.distance;
                        dailylogsToUpdate.add(d);
                        logs.add(dis.log);  
                    }
                }else if(noOfvisit ==0){ //no visits distance b/w dailylog
                    if(d.Clock_In_Location__Latitude__s !=null && d.Clock_In_Location__Longitude__s !=null ){
                        dis =distanceCalculationinKM(d.Clock_In_Location__Latitude__s , d.Clock_In_Location__Longitude__s ,d.Clock_Out_Location__Latitude__s ,d.Clock_Out_Location__Longitude__s );
                        d.KMs_Travelled__c =dis.distance;
                        d.Distance_Calculated_by_Google_API__c =true;    
                        d.Last_visit_distance__c =0;
                        dailylogsToUpdate.add(d);
                        logs.add(dis.log); 
                    }
                }
            }
        }
        
        if(dailylogsToUpdate.size() >0){
            update dailylogsToUpdate;
        }
        if(visitsToUpdate.size() >0){
            update visitsToUpdate;
        }
        if(logs.size() > 0){
            database.insert(logs);
        }
        
        
    }
    //Calling Google matrix api to get distance
    public static distanceValue distanceCalculationinKM(decimal l1lat, decimal l1long,decimal  l2lat,decimal l2long){ 
        distanceValue d = new distanceValue();
        d.distance =0;
        log__c log = new log__c();
        string ApiKey = label.GOOGLE_MAPS_API_KEY;
        string url = 'https://maps.googleapis.com/maps/api/distancematrix/json?';   
        url = url + 'origins='+ l1lat+','+ l1long;
        url = url + '&destinations='+ l2lat+','+ l2long;           
        url = url + '&key='+ApiKey;   
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');    
        Http http = new Http();
        log.Request__c  = url;
        if(!test.isrunningtest()){
            HTTPResponse res = http.send(req);
            log.Response__c = res.getBody().tostring() ; 
            distancematrix dm =  (distancematrix)JSON.deserialize(res.getBody(),distancematrix.class);   
            if( ( dm.rows.size() > 0 )&& ( dm.rows[0].elements.size() > 0 )  ){
                d.distance= dm.rows[0].elements[0].distance.value/1000; 
            }   
        }
        log.Status_Message__c='Success';
        d.log =log;
        return d;
    }
    
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
    

    public static void distanceCalculationSF(List<String> dailyLogIds){
        list<log__c> logs= new list<log__c>();
        list<Daily_Log__c> dailylogsToUpdate= new list<Daily_Log__c>();
        list<Visit__c> visitsToUpdate= new list<Visit__c>();
        map<Id,Daily_Log__c> dailylogMap = new  map<Id,Daily_Log__c>([select Id,KMs_Travelled__c,Last_Visit_Distance_SF__c,Distance_by_SF__c,Distance_Calculated_by_SF__c,Clock_In_Location__Latitude__s,Clock_In_Location__Longitude__s,
                                                                      Clock_Out_Location__Latitude__s,Clock_Out_Location__Longitude__s,
                                                                      (select Id, Name, Visit_Start__c, Visit_for__c, Lead__c, Account__c,
                                                                       Check_In_Location__Latitude__s, Check_In_Location__Longitude__s, SF_Distance__c, 
                                                                       OwnerId, Daily_Log__c,Distance_Calculated_by_SF__c  from Visits__r where Status__c!='Planned' and Status__c!='Missed' order by Visit_Start__c asc ) from Daily_Log__c WHERE Id IN :dailyLogIds order by createddate desc]);
        
        
        for(Daily_Log__c d : dailylogMap.values()){
            integer noOfvisit =d.Visits__r.size();
            
            if(noOfvisit != 0 ){
                if(  d.Clock_In_Location__Latitude__s !=null && d.Clock_In_Location__Longitude__s !=null ){ //first vist daily log checkin to first visit chekin
                    Visit__c visit =new Visit__c();
                    visit =d.Visits__r[0];
                    if(visit.Check_In_Location__Latitude__s !=null && visit.Check_In_Location__Longitude__s !=null){
                        visit.SF_Distance__c =calculateHaversineDistance( d.Clock_In_Location__Latitude__s, d.Clock_In_Location__Longitude__s,visit.Check_In_Location__Latitude__s ,visit.Check_In_Location__Longitude__s);
                        visit.Distance_Calculated_by_SF__c =true;
                        visitsToUpdate.add(visit);
                    }
                }
                
                if(noOfvisit >1){ //more than one visit
                    list<Visit__c > visits =new list<Visit__c >();
                    visits =d.Visits__r;
                    for(integer i=1 ; i<noOfvisit;i++ ){
                        
                        system.debug(visits[i].name);
                        if( visits[i].Distance_Calculated_by_SF__c  ){
                            continue;
                        }
                        if(visits[i-1].Check_In_Location__Latitude__s !=null && visits[i-1].Check_In_Location__Longitude__s !=null && visits[i].Check_In_Location__Latitude__s !=null && visits[i].Check_In_Location__Longitude__s !=null){
                             visits[i].SF_Distance__c =calculateHaversineDistance(visits[i-1].Check_In_Location__Latitude__s ,visits[i-1].Check_In_Location__Longitude__s,visits[i].Check_In_Location__Latitude__s ,visits[i].Check_In_Location__Longitude__s );
                            visits[i].Distance_Calculated_by_SF__c =true;
                            visitsToUpdate.add(visits[i]);
                        }
                    }
                    
                }
            }
            if(d.Clock_Out_Location__Latitude__s !=null && d.Clock_Out_Location__Longitude__s !=null ){ //completed daily log
                if(noOfvisit >0){ // last visit
                    Visit__c visit =new Visit__c();
                    if(noOfvisit ==1 ){
                        visit =d.Visits__r[0];
                    }else{
                        visit =d.Visits__r[noOfvisit -1];
                    }
                    if(visit.Check_In_Location__Latitude__s !=null && visit.Check_In_Location__Longitude__s !=null){
                         d.Last_Visit_Distance_SF__c =calculateHaversineDistance( visit.Check_In_Location__Latitude__s ,visit.Check_In_Location__Longitude__s,d.Clock_Out_Location__Latitude__s ,d.Clock_Out_Location__Longitude__s );
                        d.Distance_Calculated_by_SF__c =true;  
                        dailylogsToUpdate.add(d); 
                    }
                }else if(noOfvisit ==0){ //no visits distance b/w dailylog
                    if(d.Clock_In_Location__Latitude__s !=null && d.Clock_In_Location__Longitude__s !=null ){
                         d.Distance_by_SF__c =calculateHaversineDistance(d.Clock_In_Location__Latitude__s , d.Clock_In_Location__Longitude__s ,d.Clock_Out_Location__Latitude__s ,d.Clock_Out_Location__Longitude__s );
                        d.Distance_Calculated_by_SF__c =true;    
                        d.Last_Visit_Distance_SF__c =0;
                        dailylogsToUpdate.add(d);

                    }
                }
            }
        }
        
        if(dailylogsToUpdate.size() >0){
            update dailylogsToUpdate;
        }
        if(visitsToUpdate.size() >0){
            update visitsToUpdate;
        }
        if(logs.size() > 0){
            database.insert(logs);
        }
        
        
    }
    public class distanceValue{  
        public decimal distance; 
        public log__c log;
    }
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