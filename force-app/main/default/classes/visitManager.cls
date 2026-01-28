public with sharing class visitManager {
    
    /**************************************************************** 
* Class Name  : VisitManager
@Company  : Fingertip    @Created Date  : 22-12-2025    @lastModifiedDate - 22-12-2025
@description :action performed when visit creation and Edit ,  @author  : Nanma  @User By  : - visitcmp
* Change Log: 
* -----------------------------------------------------------------------------    
* Ver |   Author     |   Date        |   Description 
* ----------------------------------------------------------------------------- 
* 1.0 |   Nanma T V          |  22-12-2025 |   Initial version      
* -------------------------------------------------------------------
**************************************************************** */      
    
    /* @Method Name :saveFile  @autor:Nanma @description :save the file
*@param-1:record id *@param-2:filename *@param-3:filedata  @retun : none @Developers :Nanma  @lastModifiedDate - 22/12/25 */
    
    //  Saving Photo images 
    @AuraEnabled
    public static String saveFile(String parentId, String fileName, String base64Data) {
        return FileController.saveFile(parentId, fileName, base64Data,'');
    } 
    // outlet screen data 
    @AuraEnabled
    public static data getAllVisitData(string recordId){
        
        data dt = new data();
        List<Order> ordList = [SELECT Id FROM Order WHERE Visit__c = :recordId];
        
        if (!ordList.isEmpty()) {
            // Extract Order__c Ids
            List<Id> orderIds = new List<Id>();
            for (Order ord : ordList) {
                orderIds.add(ord.Id);
            }
            
            // Fetch related Order_Item__c records
            /*   dt.orList = [SELECT Id, Name, Product__c, Product__r.Name, Product_Category__c, Product_Category__r.Name,
Total_Amount__c, Account__r.Name, Visit__c, Visit__r.Name, Daily_log__r.Name, Quantity__c
FROM OrderItem 
WHERE Order IN :orderIds];*/
        }
        
        dt.VisitPhoto = LightningFileUploadHandler.getFiles(recordId);
        /* dt.Stock = [select Id,name,Product__c,Product__r.Name,Product_Category__c,Product_Category__r.Name,
Quantity__c, Unit_Price__c from Dealer_Stock__c where Visit__c =:recordId ];
*/
        //    dt.paymentFollowUp = getPaymentDestails(recordId).paymentFollowUp;
        
        
        visit__c vs = [select id,Daily_Log__c ,Visit_for__c,Account__c,Lead__c
                       from visit__c where id=:recordID];//Status__c,Lead__c,Account__c,
        string ids;
        List<Visit__c> allVisit = new List<Visit__c>();
        
        if(vs.Visit_for__c == 'Customer'){
            ids = vs.Account__c;
            allVisit = [select id,Account__c,Status__c from Visit__c where Account__c =:ids ];//and Actual_Start_Time__c != null];
            system.debug('visita: '+allVisit.size());
        }
        else if(vs.Visit_for__c == 'Lead'  ){
            ids = vs.Lead__c;
            allVisit = [select id,Status__c,Lead__c from Visit__c where Lead__c =:ids ];//and Actual_Start_Time__c != null];            
        }
        
        //       List<Invoice__c> inv = new List<Invoice__c>();
        //     List<Sale__c> sales = new List<Sale__c>();
        List<Order> allOrders = new List<Order>();
        Decimal totalOrderAmt = 0, totalSalesAmt = 0, totalSumOutStanding = 0;
        
        if(ids != null){
            system.debug('invoicesss '+vs.Visit_for__c);
            if(vs.Visit_for__c == 'Lead' ){
                //           dt.outletTask = [Select id,name,Description__c,Task_Status__c from Outlet_Task__c where Lead__c=:ids];
            }else{
                //              dt.outletTask = [Select id,name,Description__c,Task_Status__c from Outlet_Task__c where Account__c=:ids];
                //            inv = [Select id, name,Grand_Total__c from Invoice__c where Store__c =: ids];
                //          sales = [Select id, Total_Amount__c from Sale__c where Account__c =: ids];
                //          system.debug('invoicesss '+inv);
            } 
            
            if ([SELECT Id FROM Account  WHERE Id = :ids LIMIT 1].size() > 0) {
                allOrders.addAll([SELECT Id, TotalAmount FROM Order WHERE  AccountId= :ids]);
            } else if ([SELECT Id FROM Lead WHERE Id = :ids LIMIT 1].size() > 0) {
                //    allOrders.addAll([SELECT Id, TotalAmount FROM Order WHERE Lead__c = :ids]);
            }
        }
        
        dt.totalOrderAmt = totalOrderAmt;
        dt.totalSalesAmt = totalSalesAmt;
        dt.AllVisit = (!allVisit.isEmpty()) ? allVisit.size() : 0;
        return dt;
    }
    
    // Daily log data calling from visit cmponent 
    @AuraEnabled
    public static data getDailyLog(){
        data db = new data();
        List<Daily_Log__c> dailylogs = [SELECT Id,Day_started_time__c,Clock_In_Location__Longitude__s,Clock_In_Location__Latitude__s,Clock_Out_Location__Longitude__s
                                              ,Clock_Out_Location__Latitude__s,Day_ended_Time__c,Vehicle_Used__c ,Odometer_Starting_Kms__c from  Daily_Log__c  WHERE Day_started_time__c = TODAY AND
                                              OwnerId =:UserInfo.getUserId()  ORDER BY createddate desc limit 1]; 
        
        if(dailyLogs.size() != 0){
            db.dailyLog = dailylogs[0];
        }
        return db;
    }
    
    
    // Getting all the data for the visit popup 
    @AuraEnabled
    public static data getVisitCreateData(){
        
        data db = new data();
        db.lead = [SELECT Id,Name,phone,MobilePhone FROM LEAD where Status!='Qualified' and Status!='Closed Won' and isConverted=false];//WHERE  Lead_Status__c != 'Converted' and  Approval_Status__c != 'Submitted'
        db.Customer = [SELECT Id,Name,Customer_Code__c,phone from account where Status__c != 'Inactive'];
  return db;
    }
    //visit cmp not using
    @AuraEnabled
    public static data getData( ){
        data dta = new data();
        List<visitData> visdata = new List<visitData>();
        
        // Set the startDate and endDate based on dateValue
        List<Visit__c> vs = [SELECT id, Name, createdDate, Visit_End__c, Visit_Start__c,
                             Visit_for__c,Visit_Type__c,Visit_Date__c, Account__c, Account__r.name , Daily_Log__r.Name, Daily_Log__c,Status__c,
                             PostPoned_Start_Time__c, Missed_PostPone_Reason__c,  Lead__c, Lead__r.Name,Check_In_Location__Longitude__s, Check_In_Location__Latitude__s,
                             Comments__c, Planned_Start_Time__c, Account__r.Customer_Code__c, Check_Out_Location__Longitude__s,Check_Out_Location__Latitude__s
                             FROM Visit__c  WHERE OwnerId = :userinfo.getUserId() AND   Visit_Date__c =today   ORDER BY status__c asc, createddate desc  ];//  AND  Approval_StatusFor__c ='Approved'
        
        
        for(Visit__c vis : vs){
            String formattedVisitDate = vis.Visit_Date__c != null ? DateTime.newInstance(vis.Visit_Date__c.year(), vis.Visit_Date__c.month(), vis.Visit_Date__c.day()).format('dd/MM/yyyy') : 
            DateTime.newInstance(vis.Planned_Start_Time__c.year(), vis.Planned_Start_Time__c.month(), vis.Planned_Start_Time__c.day()).format('dd/MM/yyyy') ;
            String formattedActualStartDateTime = vis.Visit_Start__c != null 
                ? DateTime.newInstance(vis.Visit_Start__c.year(), vis.Visit_Start__c.month(), vis.Visit_Start__c.day(),
                                       vis.Visit_Start__c.hour(), vis.Visit_Start__c.minute(),0)
                .format('dd/MM/yyyy HH:mm:')   : '';
            String formattedActualEndDateTime = vis.Visit_End__c != null 
                ? DateTime.newInstance(vis.Visit_End__c.year(), vis.Visit_End__c.month(), vis.Visit_End__c.day(),
                                       vis.Visit_End__c.hour(), vis.Visit_End__c.minute(),0)
                .format('dd/MM/yyyy HH:mm')   : '';
               String formattedPlannedTime =  DateTime.newInstance(vis.Planned_Start_Time__c.year(), vis.Planned_Start_Time__c.month(), vis.Planned_Start_Time__c.day(),
                                       vis.Planned_Start_Time__c.hour(), vis.Planned_Start_Time__c.minute(),0).format('dd/MM/yyyy HH:mm');
            
            visitData ad = new visitData();
            ad.id = vis.Id;
            ad.actualStartDateTimeString = formattedActualStartDateTime;
            ad.actualEndtDateTimeString = formattedActualEndDateTime;
            ad.Name = vis.Name; 
            if(vis.Account__c != null){
                ad.acccountId=vis.Account__c;
                ad.accountName = vis.Account__r.Name;
            } else if(vis.Lead__c != null){
                ad.accountName = vis.Lead__r.Name;
                ad.acccountId=vis.Lead__c;
            }
            
            ad.appAccountId=vis.Account__r.Customer_Code__c;
            ad.dailyLogName =vis.Daily_log__r.Name;
            ad.dailyLogId=vis.Daily_log__c;
            ad.formattedPlannedTime =formattedPlannedTime;
            ad.plannedStartTime=vis.Planned_Start_Time__c;
            ad.actualStartTime=vis.Visit_Start__c;
            ad.actualEndTime=vis.Visit_End__c;
            ad.comments=vis.Comments__c;
            ad.typeofVisit=vis.Visit_Type__c;
            ad.missedReason = vis.Missed_PostPone_Reason__c;
            ad.status=vis.Status__c;
            ad.checkinlatti = vis.Check_In_Location__Latitude__s;
            ad.checkinlongi = vis.Check_In_Location__Longitude__s;
            ad.createdDate = vis.createdDate;
            ad.lastVisitComment='';
            ad.lastvisitorder=0;
            ad.VisitDate = vis.Visit_Date__c;
            ad.formattedVisitDate = formattedVisitDate;
            ad.ClockInLatitude = vis.Check_In_Location__Latitude__s;
            ad.ClockinLongitude = vis.Check_In_Location__Longitude__s;
            ad.ClockoutLatitude = vis.Check_out_Location__Latitude__s;
            ad.ClockoutLongitude = vis.Check_out_Location__Latitude__s;
            ad.visitTypes = vis.Visit_for__c;
            visdata.add(ad);
        }
        system.debug('visdata '+visdata);
        dta.visit = visdata;
        List<Daily_Log__c> clockinClockout = [SELECT Id,OwnerId,Day_ended_Time__c from  Daily_Log__c  WHERE
                                              Day_started_time__c = TODAY AND OwnerId =:UserInfo.getUserId()  ORDER BY createddate desc limit 1]; 
        dta.isDayStarted = !clockinClockout.isEmpty() ? true : false;
        return dta;
    }

    
    @AuraEnabled
    public static data getDataRecordById(string ids,string objName){
        data dta = new data();
        if (objName == 'getOrderDetails'){
            date todays = Date.today();
        }
        return dta;
    }
    

    
    //Task
    @AuraEnabled
    public static data getPaymentDestails(string ids){       
        system.debug(ids);
        data dta = new data();
        return dta;
    }
    
    //Month product data
    @AuraEnabled
    public static data getOrderProductivity(date toDate, date fromDate) {
        data dta = new data();
        return dta;
    }
    
    
    public static List<categoryData> setOrder(List<Product2> products) {
        Map<Id, List<productData>> proLine = new Map<Id, List<productData>>();
        Map<Id, String> categoryNames = new Map<Id, String>(); // To store category names
        Map<Id, String> salesId = new Map<Id, String>();
        Map<id,map<id,String>> focusSell = new Map<Id, map<id,String>>();
        
        Integer index1 = 0;
        Integer index2 = 0;
        
        for (Product2 pro : products) {
            // Format the creation date
            String formattedProdDate = DateTime.newInstance(pro.CreatedDate.year(), pro.CreatedDate.month(), pro.CreatedDate.day()).format('dd/MM/yyyy');
            
            // Create a new productData object
            productData p = new productData();
            p.id = pro.Id;
            p.name = pro.Name;       
            p.createdDate = formattedProdDate;
            p.value = 0;
            p.index2 = index2;
            index2++;
        }
        
        // Convert map to list
        List<categoryData> categoryList = new List<categoryData>();
        for (Id categoryId : proLine.keySet()) {
            
            categoryData category = new categoryData();
            if (focusSell.containsKey(categoryId) && !focusSell.get(categoryId).isEmpty()) {
                Map<Id, String> innerMap = focusSell.get(categoryId);
                Id firstKey = innerMap.keySet().iterator().next();
            }
            index1++;
        }
        
        return categoryList;
    }
    
  
  
    //Get Visit data
    @AuraEnabled
    public static data getVisitData(string currentBeatId){
        data dta = new data();
        
        string currentUserId = UserInfo.getUserId();
        User us = [select Id,Name from User where Id =:currentUserId];
        List<Daily_Log__c> dailyLog = [SELECT Id,Name,Day_ended_Time__c,Vehicle_Used__c
                                       from  Daily_Log__c  WHERE Day_started_Time__c = TODAY
                                       AND OwnerId =:currentUserId  ORDER BY createddate desc limit 1]; 
        
        List<visitData> visdata = new List<visitData>();
        map<String,String> beatItemVisitMap = new map<String,String>();
        boolean isPrimaryCustomerVisitExisted = false;
        boolean isSubstockiesBeatExisted = false;
        if(string.isNotBlank(currentBeatId))
        {
            //Getting the existing Visits Data
            List<Visit__c> vs = [SELECT id, Name, createdDate,  Visit_End__c, Visit_Start__c,
                                 Missed_PostPone_Reason__c,  Visit_Date__c,
                                 Visit_for__c, Account__c,Daily_Log__r.Name, Daily_Log__c,
                                 Visit_Type__c,
                                 Lead__c, Lead__r.Name, Check_In_Location__c,
                                 Check_Out_Location__c,Comments__c, Planned_Start_Time__c,
                                 Account__r.Customer_Code__c, Account__r.Name,Check_In_Location__Latitude__s,Check_In_Location__Longitude__s,
                                 Check_Out_Location__Latitude__s,Check_Out_Location__Longitude__s,Status__c
                                 FROM Visit__c WHERE OwnerId = :userinfo.getUserId()
                                 AND Visit_Date__c = TODAY 
                                 ORDER BY status__c asc, createddate desc 
                                ];//Vehicle_Used__c,Miss_visit__c, PostPoned__c,
            for(Visit__c vis : vs){
                String formattedVisitDate = vis.Visit_Date__c != null ? DateTime.newInstance(vis.Visit_Date__c.year(), vis.Visit_Date__c.month(), vis.Visit_Date__c.day()).format('dd/MM/yyyy') : 
                DateTime.newInstance(vis.Planned_Start_Time__c.year(), vis.Planned_Start_Time__c.month(), vis.Planned_Start_Time__c.day()).format('dd/MM/yyyy') ;
                String formattedActualStartDateTime = vis.Visit_Start__c != null 
                    ? DateTime.newInstance(vis.Visit_Start__c.year(), vis.Visit_Start__c.month(), vis.Visit_Start__c.day(),
                                           vis.Visit_Start__c.hour(), vis.Visit_Start__c.minute(),0).format('dd/MM/yyyy HH:mm:') : '';
                String formattedActualEndDateTime = vis.Visit_End__c != null 
                    ? DateTime.newInstance(vis.Visit_End__c.year(), vis.Visit_End__c.month(), vis.Visit_End__c.day(),
                                           vis.Visit_End__c.hour(), vis.Visit_End__c.minute(),0).format('dd/MM/yyyy HH:mm') : '';
                visitData ad = new visitData();
                ad.id = vis.Id;
                //  ad.approvalStatus = vis.Approval_Status__c;
                ad.actualStartDateTimeString = formattedActualStartDateTime;
                ad.actualEndtDateTimeString = formattedActualEndDateTime;
                ad.Name = vis.Name;
                //     ad.salesAppId = vis.Sales_App_ID__c;
                if(vis.Account__c != null){
                    ad.acccountId=vis.Account__c;
                    ad.accountName = vis.Account__r.Name;
                }
                ad.appAccountId=vis.Account__r.Customer_Code__c;
                ad.dailyLogName =vis.Daily_log__r.Name;
                ad.dailyLogId=vis.Daily_log__c;
                ad.plannedStartTime=vis.Planned_Start_Time__c;
                ad.actualStartTime=vis.Visit_Start__c;
                ad.actualEndTime=vis.Visit_End__c;
                ad.comments=vis.Comments__c;
                ad.typeofVisit=vis.Visit_Type__c;
                ad.missedReason = vis.Missed_PostPone_Reason__c;
                ad.status=vis.Status__c;
                ad.checkinlatti = vis.Check_In_Location__Latitude__s; 
                ad.checkinlongi = vis.Check_In_Location__Longitude__s;
                ad.createdDate = vis.createdDate;
                ad.lastVisitComment='';
                ad.lastvisitorder=0;
                ad.VisitDate = vis.Visit_Date__c;
                ad.formattedVisitDate = formattedVisitDate;
                ad.ClockInLatitude = vis.Check_In_Location__Latitude__s;
                ad.ClockinLongitude = vis.Check_In_Location__Longitude__s;
                ad.ClockoutLatitude = vis.Check_Out_Location__Latitude__s;
                ad.ClockoutLongitude = vis.Check_Out_Location__Longitude__s;system.debug('visitfor: '+vis.Visit_for__c);
                ad.visitTypes = vis.Visit_for__c;
                visdata.add(ad);
            }
            Set<Id> allAccountIds = new Set<Id>();
            
            
            List<Account> accessibleAccounts = [SELECT Id FROM Account  WHERE Id IN :allAccountIds];
            if(!accessibleAccounts.isEmpty())
            {
                Set<Id> accessibleAccountIds = new Set<Id>();
                for (Account acc : accessibleAccounts) {
                    accessibleAccountIds.add(acc.Id);
                }
                String formattedVisitDate = DateTime.newInstance( Date.today().year(), Date.today().month(),  Date.today().day()).format('dd/MM/yyyy'); 
            }
        }
        dta.visit = visdata;
        dta.isDayStarted = !dailyLog.isEmpty() && dailyLog[0].Day_ended_time__c == null; 
        return dta;
    }
    
    
    
    //camera   my visit
    @AuraEnabled  
    public static List<ContentDocument> getFiles(String recordId){ 
        if(recordId != null)
        {
            System.debug('recordId'+recordId);
            Id linkedEntityId = recordId;
            Set<Id> linkedEntityIds = new Set<Id>(); 
            linkedEntityIds.add(recordId);  
            List<ContentDocumentLink> contentDocumentLinks = [SELECT Id, ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId In: linkedEntityIds];
            
            Set<Id> documentIds = new Set<Id>(); 
            
            for(ContentDocumentLink cdl:contentDocumentLinks){  
                documentIds.add(cdl.ContentDocumentId);  
            }    
            return [SELECT Id, Title, FileType FROM ContentDocument WHERE Id IN :documentIds];      
        }
        return null;     
        
    } 
  //   myvisit
    @AuraEnabled  
    public static void deleteFile(String contentDocumentId){ 
        delete [SELECT Id from ContentDocument WHERE Id = :contentDocumentId];       
    }
    
    
    public class data {
        @AuraEnabled public List<VisitDataSummary> SummaryvisitData { get; set; }
        public data() {
            
            SummaryvisitData = new List<VisitDataSummary>();
        }
        @AuraEnabled
        public Decimal totalOrderAmt{get; set;}
        @AuraEnabled
        public Decimal totalSalesAmt{get; set;}
        @AuraEnabled
        public Integer AllVisit{get; set;}
        @AuraEnabled
        public boolean isDayStarted{get; set;}
        @AuraEnabled
        public List<ContentDocument> VisitPhoto{get; set;}
        
        @AuraEnabled
        public List<Map<String, String>> productCatDropdown{get; set;}
        @AuraEnabled
        public List<Map<String, String>> formattedSalesData{get; set;}
        
        @AuraEnabled
        public Daily_Log__c dailyLog{get; set;}
        @AuraEnabled
        public  List<Lead> lead {get; set;}
        @AuraEnabled
        public  List<Account> Customer {get; set;}
        @auraEnabled
        public List<visitData> visit;
        @AuraEnabled public integer visCount;
        @AuraEnabled public Decimal TotalAmount;
        @AuraEnabled public Decimal totalKm;
        @AuraEnabled public Decimal productiveData;
        
    }
    public class VisitDataSummary {
        @AuraEnabled public String visitId { get; set; }
        @AuraEnabled public String visitType { get; set; }
        @AuraEnabled public String ownerId { get; set; }
        @AuraEnabled public String visDate { get; set; }
        @AuraEnabled public Integer TotalOrd { get; set; }
        @AuraEnabled public String ExeName { get; set; }
    }
    public class visitData{
        @AuraEnabled public string Name;
        @AuraEnabled public date VisitDate;
        @AuraEnabled public String formattedVisitDate;
         @AuraEnabled public String formattedPlannedTime;
        @AuraEnabled public String actualEndtDateTimeString;
        @AuraEnabled public String actualStartDateTimeString;
        @AuraEnabled public String id;   
        @AuraEnabled public datetime createdDate;
        @AuraEnabled public String accountName;  
        @AuraEnabled public String acccountId;   
        @AuraEnabled public String appAccountId;
        @AuraEnabled public String dailyLogName;  
        @AuraEnabled public String dailyLogId;   
        @AuraEnabled public String dailylogAppId;
        @AuraEnabled public datetime plannedStartTime;   
        @AuraEnabled public datetime plannedEndTime; 
        @AuraEnabled public datetime actualStartTime;    
        @AuraEnabled public datetime actualEndTime;  
        @AuraEnabled public string salesAppId;
        @AuraEnabled public String comments; 
        @AuraEnabled public String missedReason;
        @AuraEnabled public String appVisitPlanId;
        @AuraEnabled public String visitPlanId;
        @AuraEnabled public String visitPlanName;
        @AuraEnabled public String typeofVisit;  
        @AuraEnabled public String status;   
        @AuraEnabled public Decimal checkinlatti;
        @AuraEnabled public Decimal checkinlongi;
        @AuraEnabled public Decimal outstanding; 
        @AuraEnabled public String lastVisitComment; 
        @AuraEnabled public double ClockInLatitude;
        @AuraEnabled public double ClockinLongitude;
        @AuraEnabled public double ClockoutLatitude;
        @AuraEnabled public double ClockoutLongitude;
        @AuraEnabled public string visitTypes;
        @AuraEnabled public string approvalStatus;
        
        @AuraEnabled public Integer lastvisitorder;
        
    }
    public class productData{
        @AuraEnabled public String id;   
        @AuraEnabled public String name; 
        @AuraEnabled public String category;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal taxPercent;
        @AuraEnabled public String taxClass;
        @AuraEnabled public string createdDate;
        @AuraEnabled public integer value;
        @AuraEnabled public integer index2;
        @AuraEnabled public String salesId;
    }
    
    
    // Validation: prevent creating a new Planned visit for a customer
    // when there is another visit for the same customer that is not completed.
    @AuraEnabled
    public static void validatePlannedVisitForCustomer(String visitFor, Id accountId, Id leadId) {
        
        Id customerId;
        
        // Determine which ID to validate
        if (visitFor == 'Customer' && accountId != null) {
            customerId = accountId;
        } else if (visitFor == 'Lead' && leadId != null) {
            customerId = leadId;
        } else {
            return; // Nothing to validate
        }
        
        List<Visit__c> existing = new List<Visit__c>();
        
        // Query open visits based on type
        if (visitFor == 'Customer') {
            existing = [ SELECT Id, Status__c  FROM Visit__c WHERE Account__c = :customerId  AND Status__c != 'Completed' AND Status__c != 'Missed'  LIMIT 1  ];
        } else if (visitFor == 'Lead') {
            existing = [ SELECT Id, Status__c FROM Visit__c WHERE Lead__c = :customerId AND Status__c != 'Completed' AND Status__c != 'Missed' LIMIT 1];
        }
        
        // Block if open visit already exists
        if (!existing.isEmpty()) {
            throw new AuraHandledException(
                'There is already an open visit for this customer. ' +
                'Please complete or close the existing visit before creating a new Planned visit.'
            );
        }
    }
    
}