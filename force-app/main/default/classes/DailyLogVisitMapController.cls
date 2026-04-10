public with sharing class DailyLogVisitMapController {

    @AuraEnabled(cacheable=true)
    public static List<VisitMapWrapper> getVisitLocations(Id dailyLogId) {
        List<VisitMapWrapper> results = new List<VisitMapWrapper>();

        List<Visit__c> visits = [
            SELECT Id, Name, Visit_ID__c,
                   AccountName__c, Lead_Name__c, Visit_for__c,
                   Visit_Start__c, Visit_End__c, Visit_Purpose__c, Status__c,
                   Check_In_Location__Latitude__s, Check_In_Location__Longitude__s,
                   Check_Out_Location__Latitude__s, Check_Out_Location__Longitude__s,
                   Address__c
            FROM Visit__c
            WHERE Daily_Log__c = :dailyLogId
            ORDER BY Visit_Start__c ASC
        ];

        Integer idx = 1;
        for (Visit__c v : visits) {
            String visitTarget = (v.Visit_for__c == 'Customer')
                ? (v.AccountName__c != null ? v.AccountName__c : 'Customer')
                : (v.Lead_Name__c != null ? v.Lead_Name__c : 'Lead');

            // Check-In location
            if (v.Check_In_Location__Latitude__s != null && v.Check_In_Location__Longitude__s != null) {
                VisitMapWrapper w = new VisitMapWrapper();
                w.id = v.Id + '_in';
                w.title = idx + '. ' + visitTarget + ' (Check-In)';
                w.description = 'Visit: ' + v.Name +
                    '\nPurpose: ' + (v.Visit_Purpose__c != null ? v.Visit_Purpose__c : 'N/A') +
                    '\nStart: ' + (v.Visit_Start__c != null ? v.Visit_Start__c.format() : 'N/A') +
                    '\nStatus: ' + (v.Status__c != null ? v.Status__c : 'N/A');
                w.latitude = v.Check_In_Location__Latitude__s;
                w.longitude = v.Check_In_Location__Longitude__s;
                w.icon = 'standard:location';
                results.add(w);
            }

            // Check-Out location
            if (v.Check_Out_Location__Latitude__s != null && v.Check_Out_Location__Longitude__s != null) {
                VisitMapWrapper w = new VisitMapWrapper();
                w.id = v.Id + '_out';
                w.title = idx + '. ' + visitTarget + ' (Check-Out)';
                w.description = 'Visit: ' + v.Name +
                    '\nEnd: ' + (v.Visit_End__c != null ? v.Visit_End__c.format() : 'N/A');
                w.latitude = v.Check_Out_Location__Latitude__s;
                w.longitude = v.Check_Out_Location__Longitude__s;
                w.icon = 'standard:flow';
                results.add(w);
            }

            idx++;
        }

        return results;
    }

    public class VisitMapWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String title;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
        @AuraEnabled public String icon;
    }
}