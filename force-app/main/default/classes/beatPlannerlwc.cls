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
        db.lead = [SELECT Id,Name,phone,MobilePhone FROM LEAD where Status!='Qualified' and Status!='Closed Won'];//WHERE  Lead_Status__c != 'Converted' and  Approval_Status__c != 'Submitted'
         db.Customer = [SELECT Id,Name,Customer_Code__c,phone from account];
       
        
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
    /*    List<productive> proList = new List<productive>();
        
        // Date startOfMonth = Date.today().toStartOfMonth();
        // Date endOfMonth = startOfMonth.addMonths(1).addDays(-1);
        Date startOfMonth = toDate;
        Date endOfMonth = fromDate;
        // Fetch Visits for the current user within the month
        List<Visit__c> vs = [SELECT Id, Visit_Date__c 
                             FROM Visit__c 
                             WHERE OwnerId = :userinfo.getUserId()
                             AND Visit_Date__c >= :startOfMonth 
                             AND Visit_Date__c <= :endOfMonth 
                             ORDER BY Visit_Date__c DESC];
        
        Set<Id> visitIds = new Set<Id>();
        Map<Date, Set<Id>> visitDateMap = new Map<Date, Set<Id>>(); // Map to store visit ids by date
        
        for (Visit__c visit : vs) {
            visitIds.add(visit.Id);
            if (!visitDateMap.containsKey(visit.Visit_Date__c)) {
                visitDateMap.put(visit.Visit_Date__c, new Set<Id>());
            }
            visitDateMap.get(visit.Visit_Date__c).add(visit.Id);
        }
        
        // Fetch Order Items associated with these visits
        List<Order_Item__c> ord = [SELECT Id, Quantity__c, Order__r.Visit__c, Order__r.Visit__r.Visit_Date__c 
                                   FROM Order_Item__c 
                                   WHERE Order__r.Visit__c IN :visitIds];
        
        Map<Date, Decimal> dailyTSL = new Map<Date, Decimal>();
        Map<Date, Integer> dailyProductiveCalls = new Map<Date, Integer>();
        
        // Calculate TSL and productive calls for each date
        for (Order_Item__c ordItem : ord) {
            Date visDate = ordItem.Order__r.Visit__r.Visit_Date__c;
            
            // Update the TSL for each day
            if (dailyTSL.containsKey(visDate)) {
                dailyTSL.put(visDate, dailyTSL.get(visDate) + ordItem.Quantity__c);
            } else {
                dailyTSL.put(visDate, ordItem.Quantity__c);
            }
            
            // Mark as productive call if there are orders for that visit date
            if (dailyProductiveCalls.containsKey(visDate)) {
                dailyProductiveCalls.put(visDate, dailyProductiveCalls.get(visDate) + 1);
            } else {
                dailyProductiveCalls.put(visDate, 1);
            }
        }
        
        // Iterate over each date in the month and calculate TSL, LPPC, and productiveCalls for each day
        for (Date day = startOfMonth; day <= endOfMonth; day = day.addDays(1)) {
            productive pro = new productive();
            
            String formattedDate = DateTime.newInstance(day.year(), day.month(), day.day()).format('dd/MM/yyyy');
            pro.formattedDate = formattedDate;
            
            // TSL for the day
            Decimal TSL = dailyTSL.containsKey(day) ? dailyTSL.get(day) : 0;
            pro.TSL = TSL.setScale(2, RoundingMode.HALF_UP);
            
            // Productive Calls (number of distinct orders/visits with orders)
            Integer productiveCalls = dailyProductiveCalls.containsKey(day) ? dailyProductiveCalls.get(day) : 0;
            pro.productiveCalls = productiveCalls;
            
            // LPPC (Lines Per Productive Call)
            decimal pdCalls= productiveCalls > 0 ? TSL / productiveCalls : 0;
            pro.LPPC = pdCalls.setScale(2, RoundingMode.HALF_UP);
            // Add the productive object to the list
            proList.add(pro);
        }
        
        if(!vs.isEmpty()){
            integer visCount = vs.size();
            dta.visCount = visCount;
            //Daily_Log__c dly = [SLECT ];
            List<Expense__c> ex = [SELECT Id, Total_Amount__c,Total_Km__c FROM Expense__c WHERE CreatedDate = THIS_MONTH LIMIT 1];
            
            // Check if the list is not empty to avoid accessing an element that doesn't exist
            if (!ex.isEmpty()) {
                dta.TotalAmount = ex[0].Total_Amount__c;
                dta.totalKm = ex[0].Total_Km__c.setScale(2, RoundingMode.HALF_UP);
            } else {
                dta.TotalAmount = 0;
                dta.totalKm = 0;
            }
            dta.productiveData = proList[0].productiveCalls;
            system.debug(dta.visCount);
            system.debug(dta.TotalAmount);
            system.debug(dta.totalKm);
            system.debug(visCount);
        }
        // Assign the list of productive data to the data object
        dta.productive = proList;
        system.debug(dta.productive);*/
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
            
//            Id sellingCategoryId = (pro.Product_Category1__r != null) ? pro.Product_Category1__r.Selling_Category__c : null;
  //          String sellingCategoryName = (pro.Product_Category1__r != null && pro.Product_Category1__r.Selling_Category__r != null) ?
    //            pro.Product_Category1__r.Selling_Category__r.Name : null;
            
            // Efficiently store products under their categories
    /*        if (!proLine.containsKey(pro.Product_Category1__c)) {
                proLine.put(pro.Product_Category1__c, new List<productData>());
                categoryNames.put(pro.Product_Category1__c, pro.Product_Category1__r.Name);
                salesId.put(pro.Product_Category1__c, pro.Selling_Category__c);
                if (!focusSell.containsKey(pro.Product_Category1__c)) {
                    focusSell.put(pro.Product_Category1__c, new Map<Id, String>());
                }
            }
            if (sellingCategoryId != null && sellingCategoryName != null) {
                focusSell.get(pro.Product_Category1__c).put(sellingCategoryId, sellingCategoryName);
            }*/
      //      proLine.get(pro.Product_Category1__c).add(p);
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
                SELECT Id, Name FROM Product2
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
                                 Account__r.Customer_Code__c
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
            
       /*     //Get the current beat and it's Primary customer and substockiest
            list<Child_beat__c> currentBeat = [select Id,Primary_Customer__c,Sub_Stockist__c,Primary_Customer__r.Name,
                                               Primary_Customer__r.Customer_Type__c,Primary_Customer__r.Outstanding__c,
                                               Primary_Customer__r.GeoLocation__c,Sub_Stockist__r.Name,Sub_Stockist__r.Customer_Type__c,
                                               Sub_Stockist__r.Outstanding__c,Sub_Stockist__r.GeoLocation__c
                                               from Child_beat__c where Id =:currentBeatId];
            
            if(currentBeat[0].Sub_Stockist__c != null){
                allAccountIds.add(currentBeat[0].Sub_Stockist__c);
            }
            if(currentBeat[0].Primary_Customer__c != null){
                allAccountIds.add(currentBeat[0].Primary_Customer__c);
            }  
            
            //Getting the customer data from beat Items
            list<Junction_Beat__c> beatItems = [select Id,Name,Account__c,Account__r.Name,Account__r.accountId__c,Account__r.Customer_Type__c,
                                                Account__r.GeoLocation__c,
                                                Account__r.Outstanding__c,Child_Beat__r.Sub_Stockist__c,Child_Beat__r.Sub_Stockist__r.Name,
                                                Child_Beat__r.Sub_Stockist__r.Customer_Type__c,Child_Beat__r.Sub_Stockist__r.GeoLocation__c,
                                                Child_Beat__r.Sub_Stockist__r.Outstanding__c,
                                                Child_Beat__r.Primary_Customer__c,Child_Beat__r.Primary_Customer__r.Name,
                                                Child_Beat__r.Primary_Customer__r.Customer_Type__c,
                                                Child_Beat__r.Primary_Customer__r.GeoLocation__c,
                                                Child_Beat__r.Primary_Customer__r.Outstanding__c from Junction_Beat__c where 
                                                Child_beat__c =: currentBeatId and Active__c = true
                                                order by Order_Number__c ASC]; 
            
            if(!beatItems.isEmpty())
            {
                // Step 1: Get all Account Ids from beatItems
                for (Junction_Beat__c bItem : beatItems) {
                    if (bItem.Account__c != null) {
                        allAccountIds.add(bItem.Account__c);
                    }
                }
            }   */
            
            List<Account> accessibleAccounts = [SELECT Id FROM Account  WHERE Id IN :allAccountIds];
            //AND((Customer_Type__c = 'Primary Customer' AND Customer_Status__c = 'Active')Or (Customer_Type__c ='Secondary Customer' AND Customer_Status__c = 'Active'))
            if(!accessibleAccounts.isEmpty())
            {
                Set<Id> accessibleAccountIds = new Set<Id>();
                for (Account acc : accessibleAccounts) {
                    accessibleAccountIds.add(acc.Id);
                }
                String formattedVisitDate = DateTime.newInstance( Date.today().year(), Date.today().month(),  Date.today().day()).format('dd/MM/yyyy'); 
                
                // -----------------------
                //Primary Customer of this Beat
                // -----------------------
           /*     if(!currentBeat.isEmpty() && currentBeat[0].Primary_Customer__c != null && !isPrimaryCustomerVisitExisted && !us.Is_SSA_DSM__c && accessibleAccountIds.contains(currentBeat[0].Primary_Customer__c)){
                    system.debug('Enteredd---------------------------');
                    visitData ad = new visitData();
                    ad.id = null;
                    ad.pjpItemId = dailyLog[0].PJP_Item__c;
                    ad.approvalStatus = 'Approved';
                    if(beatItems[0].Account__c != null){
                        ad.acccountId= currentBeat[0].Primary_Customer__c;
                        ad.accountName = currentBeat[0].Primary_Customer__r.Name;
                        ad.typeofVisit= currentBeat[0].Primary_Customer__r.Customer_Type__c;
                        ad.visitTypes = currentBeat[0].Primary_Customer__r.Customer_Type__c;
                    }
                    if(!dailyLog.isEmpty())
                    {
                        ad.dailyLogName =dailyLog[0].Name;
                        ad.dailyLogId=dailyLog[0].Id;   
                    }
                    ad.plannedStartTime= Date.today();
                    ad.status='Planned';
                    ad.visitPlanId=currentBeatId;
                    ad.outstanding= currentBeat[0].Primary_Customer__r.Outstanding__c;
                    ad.createdDate =  Date.today();
                    ad.lastvisitorder = 0;
                    ad.VisitDate =  Date.today();
                    ad.formattedVisitDate = formattedVisitDate; 
                    if(currentBeat[0].Primary_Customer__r.GeoLocation__c != null){
                        ad.customerLocationLattitude = currentBeat[0].Primary_Customer__r.GeoLocation__c.getLatitude();
                        ad.customerLocationLongitude = currentBeat[0].Primary_Customer__r.GeoLocation__c.getLongitude();
                    }
                    
                    visdata.add(ad);
                }
                */
                // -----------------------
                //Sub stockiest of this Beat
                // -----------------------
            /*    if( !currentBeat.isEmpty() &&  currentBeat[0].Sub_Stockist__c != null && !isSubstockiesBeatExisted &&
                   accessibleAccountIds.contains(currentBeat[0].Sub_Stockist__c)){
                       visitData ad = new visitData();
                       ad.id = null;
                       ad.pjpItemId = dailyLog[0].PJP_Item__c;
                       ad.approvalStatus = 'Approved';
                       if(beatItems[0].Account__c != null){
                           ad.acccountId= currentBeat[0].Sub_Stockist__c;
                           ad.accountName = currentBeat[0].Sub_Stockist__r.Name;
                           ad.typeofVisit= currentBeat[0].Sub_Stockist__r.Customer_Type__c;
                           ad.visitTypes = currentBeat[0].Sub_Stockist__r.Customer_Type__c;
                       }
                       if(!dailyLog.isEmpty())
                       {
                           ad.dailyLogName =dailyLog[0].Name;
                           ad.dailyLogId=dailyLog[0].Id;   
                       }
                       ad.plannedStartTime= Date.today();
                       ad.status='Planned';
                       ad.visitPlanId=currentBeatId;
                       ad.outstanding= currentBeat[0].Sub_Stockist__r.Outstanding__c;
                       ad.createdDate =  Date.today();
                       ad.lastvisitorder = 0;
                       ad.VisitDate =  Date.today();
                       ad.formattedVisitDate = formattedVisitDate; 
                       if(currentBeat[0].Sub_Stockist__r.GeoLocation__c != null){
                           ad.customerLocationLattitude = currentBeat[0].Sub_Stockist__r.GeoLocation__c.getLatitude();
                           ad.customerLocationLongitude = currentBeat[0].Sub_Stockist__r.GeoLocation__c.getLongitude();
                       }
                       
                       visdata.add(ad);
                   }
               */ 
                // -----------------------
                //Beat Items
                // -----------------------
           /*     if(!beatItems.isEmpty())
                {
                    for(Junction_Beat__c bItem :beatItems)
                    {
                        if(!beatItemVisitMap.containskey(bItem.Id) && bItem.Account__c != null && accessibleAccountIds.contains(bItem.Account__c))
                        {
                            visitData ad = new visitData();
                            ad.id = null;
                            ad.beatItemId = bItem.Id;
                            ad.pjpItemId = dailyLog[0].PJP_Item__c;
                            ad.approvalStatus = 'Approved';
                            if(bItem.Account__c != null){
                                ad.acccountId=bItem.Account__c;
                                ad.accountName = bItem.Account__r.Name;
                                ad.typeofVisit=bItem.Account__r.Customer_Type__c;
                                ad.visitTypes = bItem.Account__r.Customer_Type__c;
                            }
                            if(!dailyLog.isEmpty())
                            {
                                ad.dailyLogName =dailyLog[0].Name;
                                ad.dailyLogId=dailyLog[0].Id;   
                            }
                            ad.plannedStartTime= Date.today();
                            ad.status='Planned';
                            ad.visitPlanId=currentBeatId;
                            ad.outstanding=bItem.Account__r.Outstanding__c;
                            ad.createdDate =  Date.today();
                            ad.lastvisitorder = 0;
                            ad.VisitDate =  Date.today();
                            ad.formattedVisitDate = formattedVisitDate; 
                            if(bItem.Account__r.GeoLocation__c != null){
                                ad.customerLocationLattitude = bItem.Account__r.GeoLocation__c.getLatitude();
                                ad.customerLocationLongitude = bItem.Account__r.GeoLocation__c.getLongitude();
                            }
                            
                            visdata.add(ad);
                            
                        }
                    }
                }*/
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
  /*    @AuraEnabled
    public static void updateDocument(List<String> idList, string uniqueId){
        system.debug('uniqueId'+uniqueId);
        list<ContentVersion> versionlist = [SELECT Id, Title,Description FROM ContentVersion WHERE ContentDocumentId IN :idList ORDER BY CreatedDate];
        if(uniqueId != null && uniqueId != '')
        {
            for(integer i=0;i<versionlist.size();i++){
                versionlist[i].Description = uniqueId;
            }
            update versionlist;
        }
    }
     //Expense line item wise data
 /*   @AuraEnabled
    global static data getExpenseLineData(Integer offset, Integer islimit) {
        
        data dta = new data();
        List<expenseData> expenseData = new List<expenseData>();
        
        List<Expenses_line_item__c> lineData = [SELECT Id, Name, Expense__c,Type__c,  Description__c,Allowance_Type__c, Amount__c,Calculated_KM__c,
                                                Colleague_Name_2__c,Created_date__c,Daily_log_km_travelled__c,Expense_Date__c,Area_Name__c,
                                                Expense_Type__c,City__c,Mode_of_transport_Private__c,Mode_of_transport_Public__c
                                                FROM Expenses_line_item__c WHERE CreatedDate = THIS_MONTH AND createdByID =:userinfo.getUserId()
                                                LIMIT 1
                                               ];
        for(Expenses_line_item__c exp:lineData){
            
            List<cls_expenseItems> itemsList = new List<cls_expenseItems>();
            cls_expenseItems ot = new cls_expenseItems();
            expenseData dt = new expenseData();
            Expense__c ex =[SELECT Id, Name, Expense_Date__c, CreatedDate,  Approval_Status__c,Amount__c,Creation_Date__c,DA_Amount__c,
                            Total_Amount__c,LineItem_Count__c,Total_DA_amount__c,Total_Expense_Amount__c,Total_Km__c,Total_other_amount__c,Total_TA_amount__c,
                            Comments__c, CreatedById, OwnerId, Owner.Name,Total_Amount_TA__c,Total_Amount_DA__c
                            FROM Expense__c
                            WHERE id=:exp.Expense__c
                            ORDER BY CreatedDate DESC ];
            if(ex != null){
                
                dt.Id = ex.Id;
                dt.expenseName = ex.Name;
                dt.expenseDate = ex.Expense_Date__c;
                //dt.modeOfTransport = ex.Mode_of_transport__c;
                dt.comments = ex.Comments__c;
                dt.createdBy = ex.CreatedById;
                dt.createdDate = ex.CreatedDate;
                dt.executiveName = ex.Owner.Name;
                dt.executiveId = ex.OwnerId;
                dt.TAAMount = ex.Total_Amount_TA__c;
                dt.totalOtherAmount = ex.Total_other_amount__c;
                dt.totalKm = ex.Total_Km__c;
                dt.DtAmount = ex.Total_Amount_DA__c;
                dt.lineItemCount = ex.LineItem_Count__c;
                dt.TotalAmount = ex.Total_Amount__c;
            }
            String formattedExpenseDate = exp.Expense_Date__c != null ? DateTime.newInstance(exp.Expense_Date__c.year(), exp.Expense_Date__c.month(), exp.Expense_Date__c.day()).format('dd/MM/yyyy') : '';
            ot.ExpenseDate = formattedExpenseDate;
            ot.type = exp.Type__c;
            ot.amount = exp.Amount__c;
            ot.description = exp.Description__c;
            ot.ExpIDs = exp.Id;
            ot.allowanceType = exp.Allowance_Type__c;
            ot.FromCity = exp.City__c;
            ot.ToCity = exp.Area_Name__c;
            ot.expenseType = exp.Expense_Type__c;
            itemsList.add(ot);
            dt.expenseItems = itemsList;
            expenseData.add(dt);
        }
        system.debug('expenseData '+expenseData);
        dta.expense = expenseData;
        system.debug('dta '+dta);
        return dta;
    }
    
    //Expense data
    @AuraEnabled
    global static data getExpenseData(Integer offset, Integer islimit) {
        
        // Wrapper class to hold data for Expenses and KPIs
        data dataWrapper = new data();
        
        // List
        List<ExpenseData> expenseDataList = new List<ExpenseData>();
        Map<Id, List<Expense_Line_Item__c>> expenseLineItemsMap = new Map<Id, List<Expense_Line_Item__c>>();
        
        // Query for Expenses with relevant fields and related Expense Line Items
        List<Expense__c> expenses = [
            SELECT Id, Name, Expense_Date__c, CreatedDate,  Approval_Status__c,Amount__c,Creation_Date__c,DA_Amount__c,
            Total_Amount__c,LineItem_Count__c,Total_DA_amount__c,Total_Expense_Amount__c,Total_Km__c,Total_other_amount__c,Total_TA_amount__c,
            Comments__c, CreatedById, OwnerId, Owner.Name,Total_Amount_DA__c,Total_Amount_TA__c,
            
            (SELECT Id, Name, Expense__c,Type__c,  Description__c,Allowance_Type__c, Amount__c,Calculated_KM__c,
             Colleague_Name_2__c,Created_date__c,Daily_log_km_travelled__c,Expense_Date__c,Area_Name__c,
             Expense_Type__c,City__c,Mode_of_transport_Private__c,Mode_of_transport_Public__c FROM Expenses_line_items__r)
            FROM Expense__c
            WHERE CreatedDate = THIS_MONTH AND  OwnerId =:userinfo.getUserId()
            LIMIT 1
        ];
        system.debug('expenses '+expenses);
        list<id> expIDs = new List<id>();
        // Iterate through each Expense and populate the wrapper object
        for (Expense__c expense : expenses) {
            ExpenseData expenseData = new ExpenseData();
            expenseData.Id = expense.Id;
            expenseData.expenseName = expense.Name;
            expenseData.expenseDate = expense.Expense_Date__c;
            //expenseData.modeOfTransport = ex.Mode_of_transport__c;
            expenseData.comments = expense.Comments__c;
            expenseData.createdBy = expense.CreatedById;
            expenseData.createdDate = expense.CreatedDate;
            expenseData.executiveName = expense.Owner.Name;
            expenseData.executiveId = expense.OwnerId;
            expenseData.TAAMount = expense.Total_Amount_TA__c;
            expenseData.totalOtherAmount = expense.Total_other_amount__c;
            expenseData.totalKm = expense.Total_Km__c;
            expenseData.DtAmount = expense.Total_Amount_DA__c;
            expenseData.lineItemCount = expense.LineItem_Count__c;
            expenseData.TotalAmount = expense.Total_Amount__c;
            
            // If there are related Expense Line Items, map them to the expense
            if(expense.Expenses_Line_Items__r != null){
                List<cls_expenseItems> itemsList = new List<cls_expenseItems>();
                for(Expenses_Line_Item__c oi : expense.Expenses_Line_Items__r){
                    String formattedExpenseDate = oi.Expense_Date__c != null ? DateTime.newInstance(oi.Expense_Date__c.year(), oi.Expense_Date__c.month(), oi.Expense_Date__c.day()).format('dd/MM/yyyy') : '';
                    cls_expenseItems ot = new cls_expenseItems();
                    ot.type = oi.Type__c;
                    ot.ExpenseDate = formattedExpenseDate;
                    ot.amount = oi.Amount__c;
                    ot.allowanceType = oi.Allowance_Type__c;
                    ot.FromCity = oi.City__c;
                    ot.ToCity = oi.Area_Name__c;
                    ot.expenseType = oi.Expense_Type__c;
                    ot.description = oi.Description__c;
                    itemsList.add(ot);
                    
                }
                expenseData.expenseItems = itemsList;
            }
            
            // Add the expense data to the list
            expenseDataList.add(expenseData);
        }
        system.debug('expenseDataList' +expenseDataList); 
        dataWrapper.expense = expenseDataList;
        system.debug('dataWrapper'+dataWrapper);
        // Return the wrapper object
        return dataWrapper; 
    }
    
    
    //Target Data
    @AuraEnabled
    global static data getTargetData(Integer isoffSet, Integer isLimit) {
       
        data dta = new data();
        kpiData kData = new kpiData();
        List<String> colHeadList = new List<String>();
        system.debug('ggg'+isoffSet+isLimit);
        // Fetch Targets with offset and limit
        List<Target__c> tarList = [SELECT Id, Name, Achieved_Percentage__c, Executive__c, Executive__r.Name, Account__c,Actual__c,Target__c,
                                   Period__c,Period__r.Name
                                   FROM Target__c  
                                   WHERE CreatedDate = THIS_MONTH AND  OwnerId =:userinfo.getUserId()  
                                   ORDER BY Achieved_Percentage__c DESC NULLS LAST 
                                   Limit 5000];//CreatedDate = THIS_MONTH AND Executive__c != null
        
        System.debug(tarList + ' tarList');
        
        Date currentDate = Date.today();
        DateTime currentDateTime = DateTime.newInstance(currentDate.year(), currentDate.month(), currentDate.day());
        String formattedDate = currentDateTime.format('MMM yyyy');
        List<String> topsellers = new List<String>();
        
        for (Target__c tar : tarList) {
            topsellers.add(tar.Executive__r.Name);
        }
        
        kData.names = topsellers;
        List<cls_kpi_sections> listSection = new List<cls_kpi_sections>();
        cls_kpi_sections sec = new cls_kpi_sections();
        
        sec.sectionHeader = 'KPI for - ' + formattedDate;
        colHeadList.add('Type');
        colHeadList.add('Target');
        colHeadList.add('Actual');
        
        sec.columnHeaders = colHeadList;
        
        List<cls_rows> rowList = new List<cls_rows>();
        
        cls_rows r = new cls_rows();
        r.rowName = 'Dealer Visit';
        r.targetValue = 10000;
        r.actualValue = 20000;
        rowList.add(r);
        
        cls_rows r1 = new cls_rows();
        r1.rowName = 'Distributor Visit';
        r1.targetValue = 50000;
        r1.actualValue = 70000;
        rowList.add(r1);
        
        sec.rows = rowList;
        listSection.add(sec);
        
        kData.sections = listSection;
        dta.kpi = kData; // Assign kpi data to the main data object
        
        List<kpi_target> targlist = new List<kpi_target>();
        
        List<kpi_graph_target> graphlist = new List<kpi_graph_target>();
        integer ctr = 1;
        if (!tarList.isEmpty()) {
            // Get all the Target__c Ids from tarList
            Set<Id> targetIds = new Set<Id>();
            for (Target__c tr : tarList) {
                targetIds.add(tr.Id);
                kpi_graph_target graph = new kpi_graph_target();
                graph.xAxis = tr.Period__r.Name;
                graph.actual = tr.Actual__c;
                graph.target = tr.Target__c;
                graphlist.add(graph);
            }
            
            // Query all Target_Item__c records that match the Target__c Ids in the tarList
            List<Target_Item__c> allTargetItems = [SELECT Id, Target__c, Target_Value__c, Actual_Value__c,Name, Self_Target__c,//Owner.Name,
                                                   Target_Logic__c, Target_Logic__r.Name, Achieved_Percentage__c 
                                                   FROM Target_Item__c 
                                                   WHERE Target__c IN :targetIds
                                                   ORDER BY Target_Logic__r.Name LIMIT 5000];//:isLimit OFFSET :isoffSet];
            System.debug(allTargetItems + ' allTargetItems');
            // Process Target_Item__c records
            for (Target_Item__c item : allTargetItems) {
                kpi_target t = new kpi_target();
                t.kpiName = 'KPI' + ctr;
                t.targetName = item.Target_Logic__r.Name;
                t.Name = item.Name;
                // t.ownerName = item.Owner.Name;
                t.target = item.Self_Target__c;
                t.actual = item.Actual_Value__c == null ? 0 : item.Actual_Value__c;
                t.achivedPer = item.Achieved_Percentage__c;
                targlist.add(t);
                ctr++;
            }
        }
        System.debug(targlist + ' targlist');
        // If you need to do something with targlist, you can assign it to dta or kData here
        kData.targlist = targlist; // Assuming you want to add this to kData
        kData.graphlist = graphlist;
        // dta.kpi = kData;
        return dta; // Return the populated data object
    }
    
    //Task Data 
    @AuraEnabled
    global static list<taskData> getTaskData(String objectId) 
    {
        Id recordId = objectId; // Example ID
        Schema.SObjectType objType = recordId.getSObjectType();
        String objectName = objType.getDescribe().getName();
        System.debug('Object Name: ' + objectName);
        list<taskData> taskDataList = new list<taskData>();
        list<Outlet_Task__c> lstTask = new list<Outlet_Task__c>();
        if(objectName =='Account')
        {
            lstTask = [Select Id,Name,Lead__c,Account__c,Task_Status__c,Description__c from Outlet_Task__c where Account__c =:objectId ];
        }
        else
        {
            lstTask = [Select Id,Name,Lead__c,Account__c,Task_Status__c,Description__c from Outlet_Task__c where Lead__c =:objectId ];
        }
        for(Outlet_Task__c ts: lstTask)
        {
            taskData td = new taskData();
            td.id = ts.Id;
            td.name = ts.Name;
            td.status = ts.Task_Status__c;
            td.checked = ts.Task_Status__c  == 'Completed' ? true : false;
            td.classtoggle = ts.Task_Status__c  == 'Completed' ? 'toggle' : '';
            td.description = ts.Description__c;
            td.icon = 'action:approval';
            taskDataList.add(td);
        }
        return taskDataList;
        
    }
    
    @AuraEnabled
    public static void updateTask(String taskId,String Status) 
    {
        Task ts = new Task();
        ts.Id = taskId;
        ts.Status = Status;
        update ts;
    }
    
    @AuraEnabled
    public static list<taskData> deleteTask(String taskId, String objectId,String objectName) 
    {
        Task ts = [select id from Task where id =:taskId ];
        
        if(ts != null)
        {
            delete ts;
        }
        return getTaskData(objectId);
    }
    @AuraEnabled
    public static list<taskData> saveTask(String taskId, String taskName, Date taskDate, String taskStatus, String description, String objectId,String objectName) {
        system.debug('taskDate'+taskDate);
        Task ts = new Task();
        if(taskId != null && taskId != '')
        {
            ts.Id = taskId ;
        }
        ts.WhatId = objectId;
        ts.Subject = taskName;
        ts.ActivityDate = taskDate;
        ts.Status = taskStatus;
        ts.Description = description;
        upsert ts;
        
        return getTaskData(objectId);
    }
    
    //Competion Data
    @AuraEnabled
    public static CompetitionData getCompetions(String recordId, string visitId) 
    {
        CompetitionData  cd = new CompetitionData();
        cd.competitionList = [select Id,Name, Competitor__c,Competitor_Name__c,Account__c,Product__c,Product_Text__c,Product_Category__c,
                              Product_Category_Text__c,Display_boards__c,Special_offer_going_on__c,Special_offer_details__c,
                              Visit__c,Visit_for__c from Competition__c where Visit__c=: visitId and Visit__c != null order by createdDate];
        cd.productCategoryList = [select Id,Name from Product_Category__c where Active__c = true];
        cd.productList = [select Id,Name,Product_Category1__c from Product__c where Is_Active__c = true];
        cd.competitorList = [select Id,Name from Competitor__c];
        return cd;
    }
    @AuraEnabled
    public static list<Competition__c> saveCompetition(Competition__c cmp, string visitId) 
    {
        if(cmp.Competitor__c == null || String.isEmpty(cmp.Competitor__c))
        {
            Competitor__c competitor = new Competitor__c();
            competitor.Name = cmp.Competitor_Name__c;
            insert competitor;
            cmp.Competitor__c= competitor.Id;
        }
        upsert cmp;
        List<Competition__c> competitonList = [SELECT  Product_Category__c,  Product__c, Special_offer_details__c, Special_offer_going_on__c, Visit__c,
                                               Visit_for__c, Account__c,  Competitor_Name__c, Competitor__c, Display_boards__c,Product_Text__c,Product_Category_Text__c,
                                               Id,Name FROM Competition__c where Visit__c =:visitId and Visit__c != null order by createdDate  ];
        return competitonList;
        
    }
    
    //Payment Follow Up Data
    @AuraEnabled
    public static list<Payment_follow_up__c> getPaymentFollowup(String recordId, string visitId) 
    {
        list<Payment_follow_up__c>  py = new list<Payment_follow_up__c>();
        py = [select Id,Name, Expected_Amount__c,Expected_Payment_Date__c,Account__c,Comments__c,
              Visit__c,Visit_for__c from Payment_follow_up__c where Visit__c=: visitId and Visit__c != null order by createdDate ];
        return py;
    }
    @AuraEnabled
    public static Payment_follow_up__c savePaymentFollowup(Payment_follow_up__c paymentFollowup) {
        try {
            upsert paymentFollowup; 
            return [select Id,Name, Expected_Amount__c,Expected_Payment_Date__c,Account__c,Comments__c,
                    Visit__c,Visit_for__c from Payment_follow_up__c where id =:paymentFollowup.Id];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // business summary for outlet screen 
    @AuraEnabled
    global static data businessSummary(){
        data dt = new data();
        
        return dt;
    }
    
    @AuraEnabled
    public static Map<String, data> getSummeryData(String ids, String objName) {
        Map<String, data> groupedData = new Map<String, data>();
        string recordIs;
        Visit__c vs = [Select id,name,Account1__c, Dealer__c, Distributor__c, Visit_for__c from Visit__c where id =: ids];
        if(vs.Account1__c != null)
            recordIs = vs.Account1__c;
        else if(vs.Account1__c != null)
            recordIs = vs.Account1__c;
        else if(vs.Account1__c != null)
            recordIs = vs.Account1__c;
        
        if(recordIs == null)
            return null;
        
        if (objName == 'outstanding') {
            List<invoice__c> invList = [SELECT Id, Name, Invoice_Date__c, Total_Amount__c 
                                        FROM invoice__c WHERE Store__c = :recordIs LIMIT 10000];
            
            for (invoice__c inv : invList) {
                if (inv.Invoice_Date__c != null) {
                    String formattedDate = DateTime.newInstance(inv.Invoice_Date__c.year(), inv.Invoice_Date__c.month(), inv.Invoice_Date__c.day()).format('dd/MM/yyyy');
                    
                    // Fetch or create data instance for this date
                    if (!groupedData.containsKey(formattedDate)) {
                        groupedData.put(formattedDate, new data());
                    }
                    
                    outstanding outRecord = new outstanding();
                    outRecord.invoiceId = inv.Id;
                    outRecord.invNo = inv.Name;
                    outRecord.invDate = formattedDate;
                    outRecord.invAmt = inv.Total_Amount__c;
                    
                    groupedData.get(formattedDate).outData.add(outRecord);
                }
            }
        } 
        
        else if (objName == 'order') {
            List<Order__c> ordList = [SELECT Id, Name, Account__c, Order_Date__c, Grand_Total__c 
                                      FROM Order__c WHERE Account__c = :recordIs LIMIT 10000];
            
            for (Order__c ord : ordList) {
                if (ord.Order_Date__c != null) {
                    String formattedDate = DateTime.newInstance(ord.Order_Date__c.year(), ord.Order_Date__c.month(), ord.Order_Date__c.day()).format('dd/MM/yyyy');
                    
                    if (!groupedData.containsKey(formattedDate)) {
                        groupedData.put(formattedDate, new data());
                    }
                    
                    Orders od = new Orders();
                    od.OrdNo = ord.Name;
                    od.OrdDate = formattedDate;
                    od.OrdAmt = ord.Grand_Total__c;
                    
                    groupedData.get(formattedDate).ordData.add(od);
                }
            }
        } 
        else if (objName == 'visit') {
            // Fetch all visits related to the given record
            List<Visit__C> visList = [SELECT Id, Account1__c, Dealer__c, Distributor__c, Visit_for__c, OwnerId, Actual_Start_Time__c,createdBy.Name
                                      FROM Visit__c 
                                      WHERE (Account1__c = :recordIs OR Dealer__c = :recordIs OR Distributor__c = :recordIs) and Actual_Start_Time__c != null];
           
            // Fetch all orders related to the given record
            List<Order__c> ordList = [SELECT Id, Name, Account__c, Order_Date__c, Grand_Total__c,createdBy.Name 
                                      FROM Order__c 
                                      WHERE Account__c = :recordIs AND Order_Date__c != NULL LIMIT 10000];
            
            for (Visit__C vis : visList) {
                if (vis.Actual_Start_Time__c != null) {
                    String formattedDate = vis.Actual_Start_Time__c.format('dd/MM/yyyy');
                    
                    // Filter orders that match this visit date
                    Integer orderCount = 0;
                    for (Order__c ord : ordList) {
                        String formattedOrdDate = DateTime.newInstance(ord.Order_Date__c.year(), ord.Order_Date__c.month(), ord.Order_Date__c.day()).format('dd/MM/yyyy');
                        if (formattedOrdDate == formattedDate) {
                            orderCount++;
                        }
                    }
                    
                    if (!groupedData.containsKey(formattedDate)) {
                        groupedData.put(formattedDate, new data());
                    }
                    
                    VisitDataSummary vData = new VisitDataSummary();
                    vData.visitId = vis.Id;
                    vData.visDate = formattedDate;
                    vData.ExeName = vis.createdBy.Name;
                    vData.visitType = vis.Visit_for__c;
                    vData.ownerId = vis.OwnerId;
                    vData.TotalOrd = orderCount; // Assign the counted orders for this visit date
                    
                    groupedData.get(formattedDate).SummaryvisitData.add(vData);
                }
            }
        }
        
        else if(objName == 'sales'){
            List<Sale__c> saleList = [Select id, name,Invoice__c,Invoice__r.Name,Account__c,Total_Amount__c,Invoice__r.Invoice_Date__c, 
                                      Invoice__r.Total_Amount__c 
                                      from Sale__c where Account__c =: recordIs];
            for(Sale__c sl:saleList){
                if(sl.Invoice__r.Invoice_Date__c != null){
                    String formattedDate = DateTime.newInstance(sl.Invoice__r.Invoice_Date__c.year(), sl.Invoice__r.Invoice_Date__c.month(), sl.Invoice__r.Invoice_Date__c.day()).format('dd/MM/yyyy');
                    if (!groupedData.containsKey(formattedDate)) {
                        groupedData.put(formattedDate, new data());
                    }
                    salesSummery sale = new salesSummery();
                    sale.SalesId = sl.Id;
                    sale.salesInvoice = sl.Invoice__r.Name;
                    sale.salesDate = formattedDate;
                    sale.Amount = sl.Invoice__r.Total_Amount__c;
                    
                    groupedData.get(formattedDate).sales.add(sale);
                }
            } 
        }
        
        return groupedData;
    }
    
  
  global class salesSummery{
        @AuraEnabled
        public String salesDate { get; set; }
        @AuraEnabled
        public String SalesId { get; set; }
        @AuraEnabled
        public String salesInvoice { get; set; }
        @AuraEnabled
        public Decimal Amount { get; set; }
    }
    global class Orders{
        @AuraEnabled
        public String OrdNo { get; set; }
        @AuraEnabled
        public String OrdDate { get; set; }       
        @AuraEnabled
        public Decimal OrdAmt { get; set; }
    }
    global class CompetitionData {
        @AuraEnabled
        public list<Competition__c> competitionList { get; set; }
        @AuraEnabled
        public list<Product_Category__c> productCategoryList { get; set; }
        @AuraEnabled
        public list<Product__c> productList { get; set; }
        @AuraEnabled
        public list<Competitor__c> competitorList { get; set; }
    }
    global class taskData {
        @AuraEnabled
        public String id { get; set; }
        @AuraEnabled
        public String name { get; set; }
        @AuraEnabled
        public String status { get; set; }
        @AuraEnabled
        public Boolean checked { get; set; }
        @AuraEnabled
        public String icon { get; set; }
        @AuraEnabled
        public String classtoggle { get; set; }
        @AuraEnabled
        public String description { get; set; }
    }
    global class outstanding{
        @AuraEnabled
        public String invoiceId { get; set; }
        @AuraEnabled
        public String invoiceItemId { get; set; }
        @AuraEnabled
        public String invDate { get; set; }
        @AuraEnabled
        public String invNo { get; set; }
        @AuraEnabled
        public Decimal invAmt { get; set; }
    }
    global class paymentFollowUpData{
        @AuraEnabled public String Name;
        @AuraEnabled public String accName ;
        @AuraEnabled public decimal expectedAmount;
        @AuraEnabled public String id;
        @AuraEnabled public String comments;
        @AuraEnabled public String expctedDate;
        @AuraEnabled public String accId;
    }
    
    global class productive{
        @AuraEnabled public Decimal TSL;
        @AuraEnabled public Decimal LPPC;
        @AuraEnabled public Decimal productiveCalls;
        @AuraEnabled public String formattedDate;
        
    }
    global class categoryData {
        @AuraEnabled  public Id categoryId; // Category ID
        @AuraEnabled public String categoryName;
        @AuraEnabled public String salesId;
        @AuraEnabled public integer index1;
        @AuraEnabled public String focusSellId; // Selling Category ID
        @AuraEnabled public String focusSellName;
        @AuraEnabled public List<productData> products; // List of products in this category
    }
    global class visitData{
        @AuraEnabled public string Name;
        @AuraEnabled public date VisitDate;
        @AuraEnabled public String formattedVisitDate;
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
        //@AuraEnabled public cls_geoLocation geoLocation;
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
        // @AuraEnabled public cls_checkoutLocation checkoutLocation;
        @AuraEnabled public String lastVisitComment; 
        @AuraEnabled public double ClockInLatitude;
        @AuraEnabled public double ClockinLongitude;
        @AuraEnabled public double ClockoutLatitude;
        @AuraEnabled public double ClockoutLongitude;
        @AuraEnabled public string visitTypes;
        @AuraEnabled public string approvalStatus;
        
        @AuraEnabled public Integer lastvisitorder;
        // @AuraEnabled public cls_files[] visitFiles;
        //@AuraEnabled public cls_visit_invoices[] visit_invoices;
        //@AuraEnabled public cls_visit_orders[] visit_orders;
        //@AuraEnabled public cls_visit_orderItems[] visit_orderItems;
    }
  global class visitPlanData{
        @AuraEnabled public String appVisitPlanid;
        @AuraEnabled public String id;
        @AuraEnabled public datetime createdDate;
        @AuraEnabled public String month;
        @AuraEnabled public String year;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public String name;
        @AuraEnabled public String frequency;
        @AuraEnabled public String executiveId;
        @AuraEnabled public String executiveName;
        @AuraEnabled public visitPlan_visits[] visits;
    }
    global class visitPlan_visits {
        @AuraEnabled public datetime selectedDate;   
        @AuraEnabled public String visitPlanId;
        @AuraEnabled public String salesAppId;
        @AuraEnabled public String visitType;
        @AuraEnabled public String accountId;
        @AuraEnabled public String accountName;
        
    }
    global class expenseData{
        
        @AuraEnabled public decimal TAAMount;
        @AuraEnabled public decimal totalOtherAmount;
        @AuraEnabled public decimal totalKm;
        @AuraEnabled public decimal DtAmount;
        @AuraEnabled public decimal lineItemCount;
        @AuraEnabled public decimal TotalAmount;
        @AuraEnabled public String id;
        @AuraEnabled public Datetime expenseDate; 
        @AuraEnabled public String expenseName;
        @AuraEnabled public String executiveName; 
        @AuraEnabled public String executiveId;
        @AuraEnabled public String appExpId;
        @AuraEnabled public String approvalStatus;
        @AuraEnabled public String modeoftransport;
        @AuraEnabled public String comments;
        @AuraEnabled public String createdBy;
        @AuraEnabled public datetime createdDate;
        @AuraEnabled public cls_expenseItems[] expenseItems;
    }
    global class cls_expenseItems {
        @AuraEnabled public String allowanceType;
        @AuraEnabled public String ExpenseDate;
        @AuraEnabled public String FromCity;
        @AuraEnabled public String ToCity;
        @AuraEnabled public String expenseType;
        @AuraEnabled public String type;
        @AuraEnabled public String appExpItemId;
        @AuraEnabled public Decimal amount;  
        @AuraEnabled public String description;  
        @AuraEnabled public String ExpIDs; 
    }
    global class kpiData {
        
        @AuraEnabled
        public String pageHeader = 'Best Performer of the month';
        @AuraEnabled
        public List<String> names;
        @AuraEnabled
        public List<cls_kpi_sections> sections;
        @AuraEnabled
        public List<kpi_graph_target> graphlist;
        @AuraEnabled
        public List<kpi_target> targlist; // Add this if you want to return targets
    }
    global class kpi_graph_target {
        @AuraEnabled
        public decimal target;
        @AuraEnabled
        public decimal actual;
        @AuraEnabled
        public String xAxis;
    }
    global class cls_kpi_sections {
        @AuraEnabled
        public String sectionHeader;
        @AuraEnabled
        public List<String> columnHeaders;
        @AuraEnabled
        public List<cls_rows> rows;
    }
    global class cls_rows {
        @AuraEnabled
        public String rowName;
        @AuraEnabled
        public Decimal targetValue;
        @AuraEnabled
        public Decimal actualValue;
    }
    global class kpi_target {
        @AuraEnabled
        public String targetName;
        @AuraEnabled
        public Decimal target;
        @AuraEnabled
        public Decimal actual;
        @AuraEnabled
        public String Name;
        @AuraEnabled
        public String ownerName;
        @AuraEnabled
        public string kpiName;
        @AuraEnabled
        public decimal achivedPer;
    }*/
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