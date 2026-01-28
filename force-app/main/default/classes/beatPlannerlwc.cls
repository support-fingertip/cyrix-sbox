@RestResource(urlMapping='/apis/*')
global with sharing class beatPlannerlwc {
  
     
    //  Saving Photo images 
    @AuraEnabled
    global static String saveFile(String parentId, String fileName, String base64Data) {
        return FileController.saveFile(parentId, fileName, base64Data,'');
    } 
    // outlet screen data 
    @AuraEnabled
    global static data getAllVisitData(string recordId){
        
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
        
  /*      if(!sales.isEmpty()){
            for(Sale__c sl: sales){
                Decimal sum = (sl.Total_Amount__c != null) ? sl.Total_Amount__c : 0;
                totalSalesAmt = totalSalesAmt + sum;
            }
        }*/
 /*       if(!allOrders.isEmpty()){
            for(Order o:allOrders){
                Decimal sum = (o.Grand_Total__c != null) ? o.Grand_Total__c : 0;
                totalOrderAmt = totalOrderAmt + sum;
            }
        }*/
    /*    if(!inv.isEmpty()){
            for(Invoice__c Invoice:inv){
                Decimal sum = (invoice.Grand_Total__c != null) ? invoice.Grand_Total__c : 0;
                totalSumOutStanding = totalSumOutStanding + sum;
            }
        }*/
 /*       dt.Competition = [SELECT id,name,Product_Category__c,Product_Category__r.Name, Product__r.Name,Product__c,Display_boards__c,
                          Competitor_Name__c,Product_Category_Text__c,Product_Text__c,Special_offer_going_on__c
                          from Competition__c where visit__c =: recordid];*/
 //       dt.totalOutStanding = totalSumOutStanding;
        dt.totalOrderAmt = totalOrderAmt;
        dt.totalSalesAmt = totalSalesAmt;
        dt.AllVisit = (!allVisit.isEmpty()) ? allVisit.size() : 0;
        return dt;
    }
    
   // Daily log data 
    @AuraEnabled
    global static data getDailyLog(){
        data db = new data();
        List<Daily_Log__c> clockinClockout = [SELECT Id,Day_started_time__c,Clock_In_Location__Longitude__s,Clock_In_Location__Latitude__s,Clock_Out_Location__Longitude__s
,Clock_Out_Location__Latitude__s,Day_ended_Time__c,Vehicle_Used__c ,Odometer_Starting_Kms__c from  Daily_Log__c  WHERE Day_started_time__c = TODAY AND
                                               OwnerId =:UserInfo.getUserId()  ORDER BY createddate desc limit 1]; 
   
        if(clockinClockout.size() != 0){
            db.dailyLog = clockinClockout[0];
        }
        return db;
    }
     
    // Getting all the data for the visit popup 
    @AuraEnabled
    global static data getVisitCreateData(){
        
        data db = new data();
   //     db.Dealer = [SELECT Id,Name,City__c,Customer_Type__c,Customer_Preference__c,Customer_Code__c from account WHERE Customer_Type__c = 'Dealer'];
     //   db.Distributor = [SELECT Id,City__c,Name,Customer_Type__c,Customer_Preference__c,Customer_Code__c,State__c from account WHERE  Customer_Type__c = 'Distributor' ]; 
       // db.ModrenTrade= [SELECT Id,City__c,Name,Customer_Type__c,Customer_Preference__c,Customer_Code__c,State__c from account WHERE  Customer_Type__c = 'Modern Trade' ]; 
        db.lead = [SELECT Id,Name,phone,MobilePhone FROM LEAD where Status!='Closed Lost' and Status!='Closed Won' and isConverted=false];//WHERE  Lead_Status__c != 'Converted' and  Approval_Status__c != 'Submitted'
         db.Customer = [SELECT Id,Name,Customer_Code__c,phone from account where Status__c!='Inactive'];
       
        
        return db;
    }
 
    @AuraEnabled
    global static data getData(Integer isoffSet, Integer isLimit,string objName, Date fromDate, Date toDate){
        data dta = new data();
   if (objName == 'BeatPlan'){
            return getBeatPlanData(fromDate,toDate);
        }
        else if (objName == 'Product'){
            return getProductData();
        }
        return dta;
    }
      //Product
    @AuraEnabled
    global static data getProductData() {
        data dt = new data();
        
        // Fetch products separately
        List<Product2> products = [
            SELECT Id, Name FROM Product2 ORDER by Name asc];
        //, Product_Category_Name__c, List_Price__c, Tax_Percent__c, CreatedDate, Product_Category1__r.Selling_Category__c,
            //Product_Category1__r.Selling_Category__r.Name,
            //Product_Category1__c, Product_Category1__r.Name, CGST__c, Discount__c, Tax_Class__c,Selling_Category__c,Selling_Category__r.Name
            
        // Process and structure the daupsertOrderta
   //     dt.productCategories = setOrder(products);
        
 /*       List<Product_Category__c> proCat = [
            SELECT Id, Name ,Selling_Category__c,Selling_Category__r.Name
            FROM Product_Category__c 
            WHERE Id IN (SELECT Product_Category1__c FROM Product__c) 
            ORDER BY Name ASC
        ];*/
        List<Map<String, String>> formattedSalesData = new List<Map<String, String>>();
        Map<String, String> allOptionsales = new Map<String, String>();
        allOptionsales.put('label', 'All');
        allOptionsales.put('value', 'All');
        formattedSalesData.add(allOptionsales);
 //       List<Selling_Category__c> sales = [select id, name from Selling_Category__c];
  /*      for(Selling_Category__c sl:sales){
            Map<String, String> dataMap = new Map<String, String>();
            dataMap.put('label', sl.Name);
            dataMap.put('value', sl.Id);
            formattedSalesData.add(dataMap);
        }*/
        List<Map<String, String>> formattedData = new List<Map<String, String>>();
        Map<String, String> allOption = new Map<String, String>();
        allOption.put('label', 'All');
        allOption.put('value', 'All');
        formattedData.add(allOption);
      /*  for (Product_Category__c pc : proCat) {
            Map<String, String> dataMap = new Map<String, String>();
            dataMap.put('label', pc.Name);
            dataMap.put('value', pc.Id);
            formattedData.add(dataMap);
        }*/
        dt.productCatDropdown = formattedData;
        dt.formattedSalesData = formattedSalesData;
        System.debug('Product Categories: ' + dt.productCategories);
        
        return dt;
    }
    
       
    @AuraEnabled
    global static data getDataRecordById(string ids,string objName){
        data dta = new data();
        if (objName == 'getOrderDetails'){
            date todays = Date.today();
        //    return getOrderDestails(ids);
        }
        else if(objName == 'getPaymentDetails'){
        //    return getPaymentDestails(ids);
        }
        return dta;
    }
    
    //Order
    @AuraEnabled
    global static data getOrderDestails(string ids){
        
        data dta = new data();
     /*   List<order__c> ord = [SELECT id,name,Grand_Total__c,Visit__c from order__c where Visit__c =: ids];
        map<Id,List<Order_Item__c>> mapOrd = new map<Id,List<Order_Item__c>>();
        for(order__c ords:ord){
            
            if(mapOrd.containsKey(ords.Id)){
                
            }else{
                List<Order_Item__c> ordItms = [select id,name,Product__c,Product__r.Name,Quantity__c,Unit_Price__c,Tax_Amount__c,Tax_Percent__c,
                                               Total_Amount__c,Grant_Total__c from Order_Item__c where Order__c=:ords.Id ];
                mapOrd.put(ords.Id,ordItms);
            }
        }
        */
        return dta;
    }
    
    //Task
    @AuraEnabled
    global static data getPaymentDestails(string ids){
        
        system.debug(ids);
        data dta = new data();
/*        List<Payment_follow_up__c> payment = [SELECT id,name,Account__c,Account__r.Name,Expected_Amount__c,Visit__c,Comments__c,Expected_Payment_Date__c
                                              from Payment_follow_up__c where Visit__c =: ids];
        List<paymentFollowUpData> pData = new List<paymentFollowUpData>();
        
        for(Payment_follow_up__c pay:payment){
            string formattedDate;
            if (pay.Expected_Payment_Date__c != null) {
                Date myDate = pay.Expected_Payment_Date__c;
                formattedDate = myDate.format();
            } 
            paymentFollowUpData p = new paymentFollowUpData();
            p.Name = pay.Name;
            p.accName = pay.Account__r.Name;
            p.expectedAmount = pay.Expected_Amount__c;
            p.id = pay.Id;
            p.accId = pay.Account__c;
            p.expctedDate = formattedDate;
            p.comments = pay.Comments__c;
            pData.add(p);
        }
        dta.paymentFollowUp = pData;*/
        return dta;
    }
    
    //Month product data
    @AuraEnabled
    global static data getOrderProductivity(date toDate, date fromDate) {
        
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
  //          p.category = pro.Product_Category_Name__c; // Individual product category name
    //        p.unitPrice = pro.List_Price__c;
      //      p.taxPercent = pro.Tax_Percent__c;
       //     p.taxClass = pro.Tax_Class__c;
            p.createdDate = formattedProdDate;
            p.value = 0;
            p.index2 = index2;
    //        p.salesId = pro.Selling_Category__c;
            index2++;
 
        }
        
        // Convert map to list
        List<categoryData> categoryList = new List<categoryData>();
        for (Id categoryId : proLine.keySet()) {
            
            categoryData category = new categoryData();
   //         category.categoryId = categoryId;
 //           category.index1 = index1;
            
            if (focusSell.containsKey(categoryId) && !focusSell.get(categoryId).isEmpty()) {
                Map<Id, String> innerMap = focusSell.get(categoryId);
                Id firstKey = innerMap.keySet().iterator().next();
 //               category.focusSellId = firstKey;
   //             category.focusSellName = innerMap.get(firstKey);
            }else{
 //               category.focusSellId = 'null';
   //             category.focusSellName = 'null';
            }
            
  //          category.salesId = salesId.get(categoryId);
    //        category.categoryName = categoryNames.get(categoryId);
      //      category.products = proLine.get(categoryId);
        //    categoryList.add(category);
            index1++;
        }
        
        return categoryList;
    }
    
    @AuraEnabled
    global static data searchProducts(string srchString){
        data dt = new data();
        List<Product2> products = new List<Product2>();
        Map<Id, Product2> uniqueProducts = new Map<Id, Product2>();
        if (String.isBlank(srchString)) {
            
            // Fetch products separately
            products  = [
                SELECT Id, Name,CreatedDate FROM Product2
            ];//
        }else{ 
            List<List<SObject>> productSrch = [ 
                FIND :srchString 
                IN ALL FIELDS 
                RETURNING Product2 (
                    Id, Name
                )//, Product_Category_Name__c, List_Price__c, Tax_Percent__c, CreatedDate, 
                  //  Product_Category1__c, Product_Category1__r.Name, CGST__c, Discount__c, Tax_Class__c
                    //WHERE Product_Category1__c != NULL
            ];
            if (!productSrch.isEmpty() && !productSrch[0].isEmpty()) {
                for (SObject result : productSrch[0]) {
                    Product2 product = (Product2) result;
                    uniqueProducts.put(product.Id, product); // Add unique products to the map
                }
            }
            products = uniqueProducts.values();
            // system.debug('srh:'+productSrch[0]);
        }
        
        // Process and structure the data
        dt.productCategories = setOrder(products);
        
        // System.debug('Product Categories: ' + dt.productCategories);
        
        return dt;
    }
    
    //Beat data
    @AuraEnabled
    global static data getBeatPlanData(Date fromDate, Date toDate){
        
        data dta = new data();
        List<visitData> visdata = new List<visitData>();
        // Initialize start and end dates
        Date startDate = fromDate;
        Date endDate = toDate;
        
        // Set the startDate and endDate based on dateValue
        List<Visit__c> vs = [SELECT id, Name, createdDate, Visit_End__c, Visit_Start__c,
                             Visit_for__c,Visit_Type__c,Visit_Date__c, Account__c, Account__r.name , Daily_Log__r.Name, Daily_Log__c,Status__c,
                             PostPoned_Start_Time__c, Missed_PostPone_Reason__c,
                            Lead__c, Lead__r.Name,Check_In_Location__Longitude__s, Check_In_Location__Latitude__s,
                             Comments__c, Planned_Start_Time__c, Account__r.Customer_Code__c,
                             Check_Out_Location__Longitude__s,Check_Out_Location__Latitude__s
                             FROM Visit__c 
                             WHERE OwnerId = :userinfo.getUserId()
                             AND   Visit_Date__c >= :startDate 
                             AND Visit_Date__c <= :endDate 
                             ORDER BY status__c asc, createddate desc 
                            ];//  AND  Approval_StatusFor__c ='Approved'
        
        
        for(Visit__c vis : vs){
            String formattedVisitDate = vis.Visit_Date__c != null ? DateTime.newInstance(vis.Visit_Date__c.year(), vis.Visit_Date__c.month(), vis.Visit_Date__c.day()).format('dd/MM/yyyy') : 
            DateTime.newInstance(vis.Planned_Start_Time__c.year(), vis.Planned_Start_Time__c.month(), vis.Planned_Start_Time__c.day()).format('dd/MM/yyyy') ;
            String formattedActualStartDateTime = vis.Visit_Start__c != null 
                ? DateTime.newInstance(vis.Visit_Start__c.year(), vis.Visit_Start__c.month(), vis.Visit_Start__c.day(),
                                       vis.Visit_Start__c.hour(), vis.Visit_Start__c.minute(),0)
                .format('dd/MM/yyyy HH:mm:') 
                : '';
            String formattedActualEndDateTime = vis.Visit_End__c != null 
                ? DateTime.newInstance(vis.Visit_End__c.year(), vis.Visit_End__c.month(), vis.Visit_End__c.day(),
                                       vis.Visit_End__c.hour(), vis.Visit_End__c.minute(),0)
                .format('dd/MM/yyyy HH:mm') 
                : '';
             String formattedPlannedTime =  DateTime.newInstance(vis.Planned_Start_Time__c.year(), vis.Planned_Start_Time__c.month(), vis.Planned_Start_Time__c.day(),
                                       vis.Planned_Start_Time__c.hour(), vis.Planned_Start_Time__c.minute(),0).format('dd/MM/yyyy HH:mm');
            visitData ad = new visitData();
            ad.id = vis.Id;
           // ad.approvalStatus;
            ad.actualStartDateTimeString = formattedActualStartDateTime;
            ad.actualEndtDateTimeString = formattedActualEndDateTime;
            ad.Name = vis.Name;
        //    ad.salesAppId = vis.Sales_App_ID__c;
        //    system.debug('vis.Dealer__c '+vis.Dealer__c);
            if(vis.Account__c != null){
                ad.acccountId=vis.Account__c;
                ad.accountName = vis.Account__r.Name;
            }
           
            else if(vis.Lead__c != null){
                ad.accountName = vis.Lead__r.Name;
                ad.acccountId=vis.Lead__c;
            }
            
            ad.appAccountId=vis.Account__r.Customer_Code__c;
            ad.dailyLogName =vis.Daily_log__r.Name;
            ad.dailyLogId=vis.Daily_log__c;
                      ad.formattedPlannedTime =formattedPlannedTime;
      //      ad.dailylogAppId=vis.Daily_log__r.Sales_App_id__c;
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
        
        List<Map<String, String>> formattedData = new List<Map<String, String>>();
        Map<String, String> allOption = new Map<String, String>();
        allOption.put('label', 'All');
        allOption.put('value', 'All');
        formattedData.add(allOption);

        dta.routeDropdown = formattedData;
        List<Daily_Log__c> clockinClockout = [SELECT Id,OwnerId,Day_ended_Time__c from  Daily_Log__c  WHERE
                                              Day_started_time__c = TODAY AND OwnerId =:UserInfo.getUserId()  ORDER BY createddate desc limit 1]; 
        dta.isDayStarted = !clockinClockout.isEmpty() ? true : false;
        return dta;
    }
    
    
     //Get Visit data
    @AuraEnabled
    global static data getVisitData(string currentBeatId){
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
                                 Account__r.Customer_Code__c,Account__r.Name,Status__c,Check_In_Location__Latitude__s,Check_In_Location__Longitude__s,Check_Out_Location__Latitude__s,Check_Out_Location__Longitude__s
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
               String formattedPlannedTime =  DateTime.newInstance(vis.Planned_Start_Time__c.year(), vis.Planned_Start_Time__c.month(), vis.Planned_Start_Time__c.day(),
                                       vis.Planned_Start_Time__c.hour(), vis.Planned_Start_Time__c.minute(),0).format('dd/MM/yyyy HH:mm');
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
                          ad.formattedPlannedTime =formattedPlannedTime;
                ad.dailyLogId=vis.Daily_log__c;
             //   ad.dailylogAppId=vis.Daily_log__r.Sales_App_id__c;
                ad.plannedStartTime=vis.Planned_Start_Time__c;
          //      ad.plannedEndTime=vis.Planned_End_Time__c;
                ad.actualStartTime=vis.Visit_Start__c;
                ad.actualEndTime=vis.Visit_End__c;
                ad.comments=vis.Comments__c;
                ad.typeofVisit=vis.Visit_Type__c;
                ad.missedReason = vis.Missed_PostPone_Reason__c;
                ad.status=vis.Status__c;
           //     ad.appVisitPlanId=vis.App_visitPlan_Id__c;
        //        ad.visitPlanId=vis.Beat__c;
          //      ad.visitPlanName=vis.Beat__r.Name;
            //    ad.outstanding=vis.Account1__r.Outstanding__c;
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
             /*   if(vis.Account__r.GeoLocation__c != null){
                    ad.customerLocationLattitude = vis.Account1__r.GeoLocation__c.getLatitude();
                    ad.customerLocationLongitude = vis.Account1__r.GeoLocation__c.getLongitude();
                }*/
                ad.ClockoutLongitude = vis.Check_Out_Location__Longitude__s;system.debug('visitfor: '+vis.Visit_for__c);
                ad.visitTypes = vis.Visit_for__c;
            //    ad.beatItemId =vis.Beat_Item__c;  
              //  ad.pjpItemId = vis.PJP_Item__c;
            //    ad.inLocation = vis.Location_Type__c == 'In Location' ? true : false;
                visdata.add(ad);
              
              /*  if(vis.Visit_for__c == 'Primary Customer' )
                {
                    isPrimaryCustomerVisitExisted = true;
                }
              */
            }
            Set<Id> allAccountIds = new Set<Id>();
            
      
            
            List<Account> accessibleAccounts = [SELECT Id FROM Account  WHERE Id IN :allAccountIds];
            //AND((Customer_Type__c = 'Primary Customer' AND Customer_Status__c = 'Active')Or (Customer_Type__c ='Secondary Customer' AND Customer_Status__c = 'Active'))
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
    
    
    
  //camera  
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
       @AuraEnabled  
    public static void deleteFile(String contentDocumentId){ 
        delete [SELECT Id from ContentDocument WHERE Id = :contentDocumentId];       
    }
 
      global class data {
        
     //   @AuraEnabled public List<outstanding> outData { get; set; }
       // @AuraEnabled public List<Orders> ordData { get; set; }
        @AuraEnabled public List<VisitDataSummary> SummaryvisitData { get; set; }
  //      @AuraEnabled public List<salesSummery> sales { get; set; }
        
        public data() {
          //  outData = new List<outstanding>();
            //ordData = new List<Orders>();
            SummaryvisitData = new List<VisitDataSummary>();
          //  sales = new List<salesSummery>();
        }
    //    @AuraEnabled
      //  public Decimal totalOutStanding{get; set;}
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
  //      @AuraEnabled
    //    public List<Dealer_Stock__c> Stock{get; set;}
      //  @AuraEnabled
        //public List<Competition__c> Competition{get; set;}
     //   @AuraEnabled
       // public List<Outlet_Task__c> outletTask{get; set;}
        
        @AuraEnabled
        public List<Map<String, String>> productCatDropdown{get; set;}
        @AuraEnabled
        public List<Map<String, String>> formattedSalesData{get; set;}
 //       @AuraEnabled
   //     public List<Order_Item__c> orList{get; set;}
        @AuraEnabled
        public Daily_Log__c dailyLog{get; set;}
        @AuraEnabled
        public  List<Account> Dealer {get; set;}
        @AuraEnabled
        public  List<Account> Distributor {get; set;}
        @AuraEnabled
        public  List<Account> ModrenTrade {get; set;}
        @AuraEnabled
        public  List<Lead> lead {get; set;}
          @AuraEnabled
        public  List<Account> Customer {get; set;}
 //       @AuraEnabled
   //     public kpiData kpi;
     //   @AuraEnabled
       // public List<expenseData> expense;
    //    @AuraEnabled
      //  public List<visitPlanData> visitPlan;
        @auraEnabled
        public List<visitData> visit;
        @AuraEnabled
        public List<Map<String, String>> routeDropdown{get; set;}
        @AuraEnabled 
        public List<categoryData> productCategories; 
        @AuraEnabled public integer visCount;
        @AuraEnabled public Decimal TotalAmount;
        @AuraEnabled public Decimal totalKm;
        @AuraEnabled public Decimal productiveData;
   //     @AuraEnabled
     //   public List<productive> productive;
       // @AuraEnabled
        //Public List<paymentFollowUpData> paymentFollowUp;
    }
        global class VisitDataSummary {
        @AuraEnabled public String visitId { get; set; }
        @AuraEnabled public String visitType { get; set; }
        @AuraEnabled public String ownerId { get; set; }
        @AuraEnabled public String visDate { get; set; }
        @AuraEnabled public Integer TotalOrd { get; set; }
        @AuraEnabled public String ExeName { get; set; }
    }
     global class visitData{
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
       global class productData{
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
    global static void validatePlannedVisitForCustomer(String visitFor, Id accountId, Id leadId) {

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
            existing = [
                SELECT Id, Status__c
                FROM Visit__c
                WHERE Account__c = :customerId
                AND Status__c != 'Completed'
                AND Status__c != 'Missed'
                LIMIT 1
            ];
        } else if (visitFor == 'Lead') {
            existing = [
                SELECT Id, Status__c
                FROM Visit__c
                WHERE Lead__c = :customerId
                AND Status__c != 'Completed'
                AND Status__c != 'Missed'
                LIMIT 1
            ];
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