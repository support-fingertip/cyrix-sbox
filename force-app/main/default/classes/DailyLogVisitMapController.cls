public with sharing class DailyLogVisitMapController {

    @AuraEnabled(cacheable=true)
    public static List<VisitMapWrapper> getVisitLocations(Id dailyLogId) {
        return buildVisitMarkers(dailyLogId);
    }

    @AuraEnabled
    public static List<VisitMapWrapper> getVisitLocationsByUserAndDate(Id userId, Date visitDate) {
        // Find Daily Log for this user and date
        List<Daily_Log__c> logs = [
            SELECT Id
            FROM Daily_Log__c
            WHERE OwnerId = :userId
            AND Date__c = :visitDate
            LIMIT 1
        ];

        if (logs.isEmpty()) {
            return new List<VisitMapWrapper>();
        }

        return buildVisitMarkers(logs[0].Id);
    }

    private static List<VisitMapWrapper> buildVisitMarkers(Id dailyLogId) {
        List<VisitMapWrapper> results = new List<VisitMapWrapper>();

        List<Visit__c> visits = [
            SELECT Id, Name, Visit_ID__c,
                   AccountName__c, Lead_Name__c, Visit_for__c,
                   Visit_Start__c, Visit_End__c, Visit_Purpose__c, Status__c,
                   Check_In_Location__Latitude__s, Check_In_Location__Longitude__s,
                   Check_Out_Location__Latitude__s, Check_Out_Location__Longitude__s
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
                w.visitNumber = idx;
                w.title = idx + '. ' + visitTarget;
                w.description = 'Visit: ' + v.Name +
                    '\nPurpose: ' + (v.Visit_Purpose__c != null ? v.Visit_Purpose__c : 'N/A') +
                    '\nCheck-In: ' + (v.Visit_Start__c != null ? v.Visit_Start__c.format() : 'N/A') +
                    '\nCheck-Out: ' + (v.Visit_End__c != null ? v.Visit_End__c.format() : 'N/A') +
                    '\nStatus: ' + (v.Status__c != null ? v.Status__c : 'N/A');
                w.latitude = v.Check_In_Location__Latitude__s;
                w.longitude = v.Check_In_Location__Longitude__s;
                w.icon = 'standard:location';
                w.customerName = visitTarget;
                w.checkInTime = v.Visit_Start__c != null ? v.Visit_Start__c.format() : '';
                w.checkOutTime = v.Visit_End__c != null ? v.Visit_End__c.format() : '';
                w.purpose = v.Visit_Purpose__c;
                w.status = v.Status__c;
                results.add(w);
            }

            idx++;
        }

        return results;
    }

    public class VisitMapWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public Integer visitNumber;
        @AuraEnabled public String title;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
        @AuraEnabled public String icon;
        @AuraEnabled public String customerName;
        @AuraEnabled public String checkInTime;
        @AuraEnabled public String checkOutTime;
        @AuraEnabled public String purpose;
        @AuraEnabled public String status;
        @AuraEnabled public String address;
    }
}
