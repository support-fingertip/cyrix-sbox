<<<<<<< HEAD
public with sharing class Account360ViewController {

    @AuraEnabled(cacheable=true)
    public static AccountData getAccountDetails(String accountId) {
        AccountData result = new AccountData();

        // Account details
        List<Account> accounts = [
            SELECT Id, Name, Phone, Customer_Code__c, Status__c, Customer_Type__c,
                   Owner.Name, BillingStreet, BillingCity, BillingState, BillingPostalCode,
                   BillingCountry, CreatedDate
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        if (accounts.isEmpty()) {
            throw new AuraHandledException('Account not found.');
        }

        Account acc = accounts[0];
        result.account = acc;
        result.ownerName = acc.Owner.Name;

        // Visit summary
        List<Visit__c> allVisits = [
            SELECT Id, Name, Status__c, Visit_Date__c, Visit_Start__c, Visit_End__c,
                   Visit_Type__c, Comments__c, Owner.Name, Visit_for__c
            FROM Visit__c
            WHERE Account__c = :accountId
            ORDER BY Visit_Date__c DESC
        ];
        result.totalVisits = allVisits.size();
        result.completedVisits = 0;
        result.plannedVisits = 0;
        result.inProgressVisits = 0;
        result.missedVisits = 0;

        List<VisitInfo> visitInfoList = new List<VisitInfo>();
        for (Visit__c v : allVisits) {
            if (v.Status__c == 'Completed') result.completedVisits++;
            else if (v.Status__c == 'Planned') result.plannedVisits++;
            else if (v.Status__c == 'In Progress') result.inProgressVisits++;
            else if (v.Status__c == 'Missed') result.missedVisits++;

            VisitInfo vi = new VisitInfo();
            vi.id = v.Id;
            vi.name = v.Name;
            vi.status = v.Status__c;
            vi.visitDate = v.Visit_Date__c;
            vi.formattedVisitDate = v.Visit_Date__c != null
                ? DateTime.newInstance(v.Visit_Date__c.year(), v.Visit_Date__c.month(), v.Visit_Date__c.day()).format('dd/MM/yyyy')
                : '';
            vi.visitType = v.Visit_Type__c;
            vi.comments = v.Comments__c;
            vi.ownerName = v.Owner.Name;
            vi.status = v.Status__c;
            visitInfoList.add(vi);
        }
        result.visits = visitInfoList;
        result.recentVisits = visitInfoList.size() > 5 ? new List<VisitInfo>() : visitInfoList;
        if (visitInfoList.size() > 5) {
            for (Integer i = 0; i < 5; i++) {
                result.recentVisits.add(visitInfoList[i]);
            }
        }

        // Order summary
        List<Order> allOrders = [
            SELECT Id, OrderNumber, TotalAmount, Status, CreatedDate, EffectiveDate
            FROM Order
            WHERE AccountId = :accountId
            ORDER BY CreatedDate DESC
        ];
        result.totalOrders = allOrders.size();
        Decimal orderTotal = 0;
        List<OrderInfo> orderInfoList = new List<OrderInfo>();
        for (Order o : allOrders) {
            Decimal amt = o.TotalAmount != null ? o.TotalAmount : 0;
            orderTotal += amt;

            OrderInfo oi = new OrderInfo();
            oi.id = o.Id;
            oi.orderNumber = o.OrderNumber;
            oi.totalAmount = amt;
            oi.status = o.Status;
            oi.formattedDate = o.EffectiveDate != null
                ? DateTime.newInstance(o.EffectiveDate.year(), o.EffectiveDate.month(), o.EffectiveDate.day()).format('dd/MM/yyyy')
                : '';
            orderInfoList.add(oi);
        }
        result.totalOrderAmount = orderTotal;
        result.orders = orderInfoList;
        result.recentOrders = orderInfoList.size() > 5 ? new List<OrderInfo>() : orderInfoList;
        if (orderInfoList.size() > 5) {
            for (Integer i = 0; i < 5; i++) {
                result.recentOrders.add(orderInfoList[i]);
            }
        }

        // Contact information
        result.contacts = [
            SELECT Id, Name, Email, Phone, Title, Department
            FROM Contact
            WHERE AccountId = :accountId
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];

        return result;
    }

    // Wrapper classes
    public class AccountData {
        @AuraEnabled public Account account { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public Integer totalVisits { get; set; }
        @AuraEnabled public Integer completedVisits { get; set; }
        @AuraEnabled public Integer plannedVisits { get; set; }
        @AuraEnabled public Integer inProgressVisits { get; set; }
        @AuraEnabled public Integer missedVisits { get; set; }
        @AuraEnabled public List<VisitInfo> visits { get; set; }
        @AuraEnabled public List<VisitInfo> recentVisits { get; set; }
        @AuraEnabled public Integer totalOrders { get; set; }
        @AuraEnabled public Decimal totalOrderAmount { get; set; }
        @AuraEnabled public List<OrderInfo> orders { get; set; }
        @AuraEnabled public List<OrderInfo> recentOrders { get; set; }
        @AuraEnabled public List<Contact> contacts { get; set; }
    }

    public class VisitInfo {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Date visitDate { get; set; }
        @AuraEnabled public String formattedVisitDate { get; set; }
        @AuraEnabled public String visitType { get; set; }
        @AuraEnabled public String comments { get; set; }
        @AuraEnabled public String ownerName { get; set; }
    }

    public class OrderInfo {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String orderNumber { get; set; }
        @AuraEnabled public Decimal totalAmount { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String formattedDate { get; set; }
    }
=======
public with sharing class Account360ViewController {

    @AuraEnabled(cacheable=true)
    public static AccountData getAccountDetails(String accountId) {
        AccountData result = new AccountData();

        // Account details
        List<Account> accounts = [
            SELECT Id, Name, Phone, Customer_Code__c, Status__c, Customer_Type__c,
                   Owner.Name, BillingStreet, BillingCity, BillingState, BillingPostalCode,
                   BillingCountry, CreatedDate
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        if (accounts.isEmpty()) {
            throw new AuraHandledException('Account not found.');
        }

        Account acc = accounts[0];
        result.account = acc;
        result.ownerName = acc.Owner.Name;

        // Visit summary
        List<Visit__c> allVisits = [
            SELECT Id, Name, Status__c, Visit_Date__c, Visit_Start__c, Visit_End__c,
                   Visit_Type__c, Comments__c, Owner.Name, Visit_for__c
            FROM Visit__c
            WHERE Account__c = :accountId
            ORDER BY Visit_Date__c DESC
        ];
        result.totalVisits = allVisits.size();
        result.completedVisits = 0;
        result.plannedVisits = 0;
        result.inProgressVisits = 0;
        result.missedVisits = 0;

        List<VisitInfo> visitInfoList = new List<VisitInfo>();
        for (Visit__c v : allVisits) {
            if (v.Status__c == 'Completed') result.completedVisits++;
            else if (v.Status__c == 'Planned') result.plannedVisits++;
            else if (v.Status__c == 'In Progress') result.inProgressVisits++;
            else if (v.Status__c == 'Missed') result.missedVisits++;

            VisitInfo vi = new VisitInfo();
            vi.id = v.Id;
            vi.name = v.Name;
            vi.status = v.Status__c;
            vi.visitDate = v.Visit_Date__c;
            vi.formattedVisitDate = v.Visit_Date__c != null
                ? DateTime.newInstance(v.Visit_Date__c.year(), v.Visit_Date__c.month(), v.Visit_Date__c.day()).format('dd/MM/yyyy')
                : '';
            vi.visitType = v.Visit_Type__c;
            vi.comments = v.Comments__c;
            vi.ownerName = v.Owner.Name;
            vi.status = v.Status__c;
            visitInfoList.add(vi);
        }
        result.visits = visitInfoList;
        result.recentVisits = visitInfoList.size() > 5 ? new List<VisitInfo>() : visitInfoList;
        if (visitInfoList.size() > 5) {
            for (Integer i = 0; i < 5; i++) {
                result.recentVisits.add(visitInfoList[i]);
            }
        }

        // Order summary
        List<Order> allOrders = [
            SELECT Id, OrderNumber, TotalAmount, Status, CreatedDate, EffectiveDate
            FROM Order
            WHERE AccountId = :accountId
            ORDER BY CreatedDate DESC
        ];
        result.totalOrders = allOrders.size();
        Decimal orderTotal = 0;
        List<OrderInfo> orderInfoList = new List<OrderInfo>();
        for (Order o : allOrders) {
            Decimal amt = o.TotalAmount != null ? o.TotalAmount : 0;
            orderTotal += amt;

            OrderInfo oi = new OrderInfo();
            oi.id = o.Id;
            oi.orderNumber = o.OrderNumber;
            oi.totalAmount = amt;
            oi.status = o.Status;
            oi.formattedDate = o.EffectiveDate != null
                ? DateTime.newInstance(o.EffectiveDate.year(), o.EffectiveDate.month(), o.EffectiveDate.day()).format('dd/MM/yyyy')
                : '';
            orderInfoList.add(oi);
        }
        result.totalOrderAmount = orderTotal;
        result.orders = orderInfoList;
        result.recentOrders = orderInfoList.size() > 5 ? new List<OrderInfo>() : orderInfoList;
        if (orderInfoList.size() > 5) {
            for (Integer i = 0; i < 5; i++) {
                result.recentOrders.add(orderInfoList[i]);
            }
        }

        // Contact information
        result.contacts = [
            SELECT Id, Name, Email, Phone, Title, Department
            FROM Contact
            WHERE AccountId = :accountId
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];

        return result;
    }

    // Wrapper classes
    public class AccountData {
        @AuraEnabled public Account account { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public Integer totalVisits { get; set; }
        @AuraEnabled public Integer completedVisits { get; set; }
        @AuraEnabled public Integer plannedVisits { get; set; }
        @AuraEnabled public Integer inProgressVisits { get; set; }
        @AuraEnabled public Integer missedVisits { get; set; }
        @AuraEnabled public List<VisitInfo> visits { get; set; }
        @AuraEnabled public List<VisitInfo> recentVisits { get; set; }
        @AuraEnabled public Integer totalOrders { get; set; }
        @AuraEnabled public Decimal totalOrderAmount { get; set; }
        @AuraEnabled public List<OrderInfo> orders { get; set; }
        @AuraEnabled public List<OrderInfo> recentOrders { get; set; }
        @AuraEnabled public List<Contact> contacts { get; set; }
    }

    public class VisitInfo {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Date visitDate { get; set; }
        @AuraEnabled public String formattedVisitDate { get; set; }
        @AuraEnabled public String visitType { get; set; }
        @AuraEnabled public String comments { get; set; }
        @AuraEnabled public String ownerName { get; set; }
    }

    public class OrderInfo {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String orderNumber { get; set; }
        @AuraEnabled public Decimal totalAmount { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String formattedDate { get; set; }
    }
>>>>>>> c43a986f5230c7fd929f316660d9e2e33c0dc9f6
}