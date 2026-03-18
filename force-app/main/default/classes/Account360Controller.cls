public with sharing class Account360Controller {

    @AuraEnabled(cacheable=true)
    public static Account360Data getAccount360Data(Id accountId) {
        Account360Data result = new Account360Data();

        // Account details
        List<Account> accounts = [
            SELECT Id, Name, Phone, Customer_Code__c, Customer_Type__c,
                   Status__c, Customer_Preference__c, City__c, State__c,
                   Industry, Website, CreatedDate
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        if (!accounts.isEmpty()) {
            result.account = accounts[0];
        }

        // Visit history
        List<Visit__c> visits = [
            SELECT Id, Name, Status__c, Visit_Date__c, Visit_Type__c,
                   Visit_Start__c, Visit_End__c, Comments__c,
                   Visit_for__c, Owner.Name, Planned_Start_Time__c,
                   Check_In_Location__Latitude__s, Check_In_Location__Longitude__s,
                   Check_Out_Location__Latitude__s, Check_Out_Location__Longitude__s
            FROM Visit__c
            WHERE Account__c = :accountId
            ORDER BY Visit_Date__c DESC NULLS LAST
            LIMIT 50
        ];
        result.visits = visits;

        // Visit metrics
        result.totalVisits = visits.size();
        Integer completedCount = 0;
        Integer inProgressCount = 0;
        Integer plannedCount = 0;
        Integer missedCount = 0;
        for (Visit__c v : visits) {
            if (v.Status__c == 'Completed') completedCount++;
            else if (v.Status__c == 'In Progress') inProgressCount++;
            else if (v.Status__c == 'Planned') plannedCount++;
            else if (v.Status__c == 'Missed') missedCount++;
        }
        result.completedVisits = completedCount;
        result.inProgressVisits = inProgressCount;
        result.plannedVisits = plannedCount;
        result.missedVisits = missedCount;

        // Orders
        List<Order> orders = [
            SELECT Id, OrderNumber, TotalAmount, Status, CreatedDate, EffectiveDate
            FROM Order
            WHERE AccountId = :accountId
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];
        result.orders = orders;

        Decimal orderTotal = 0;
        for (Order o : orders) {
            if (o.TotalAmount != null) {
                orderTotal += o.TotalAmount;
            }
        }
        result.totalOrders = orders.size();
        result.totalOrderAmount = orderTotal;

        // Contacts
        List<Contact> contacts = [
            SELECT Id, Name, Email, Phone, Title, Department
            FROM Contact
            WHERE AccountId = :accountId
            ORDER BY Name ASC
            LIMIT 20
        ];
        result.contacts = contacts;

        // Open Activities (Tasks)
        List<Task> tasks = [
            SELECT Id, Subject, Status, Priority, ActivityDate, Owner.Name
            FROM Task
            WHERE AccountId = :accountId
            AND IsClosed = false
            ORDER BY ActivityDate ASC
            LIMIT 10
        ];
        result.openTasks = tasks;

        // Recent Notes/Attachments count
        List<ContentDocumentLink> docLinks = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :accountId
            LIMIT 100
        ];
        result.attachmentCount = docLinks.size();

        return result;
    }

    public class Account360Data {
        @AuraEnabled public Account account { get; set; }
        @AuraEnabled public List<Visit__c> visits { get; set; }
        @AuraEnabled public List<Order> orders { get; set; }
        @AuraEnabled public List<Contact> contacts { get; set; }
        @AuraEnabled public List<Task> openTasks { get; set; }
        @AuraEnabled public Integer totalVisits { get; set; }
        @AuraEnabled public Integer completedVisits { get; set; }
        @AuraEnabled public Integer inProgressVisits { get; set; }
        @AuraEnabled public Integer plannedVisits { get; set; }
        @AuraEnabled public Integer missedVisits { get; set; }
        @AuraEnabled public Integer totalOrders { get; set; }
        @AuraEnabled public Decimal totalOrderAmount { get; set; }
        @AuraEnabled public Integer attachmentCount { get; set; }
    }
}
