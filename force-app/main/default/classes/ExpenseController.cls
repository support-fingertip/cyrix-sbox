public with sharing class ExpenseController {
    @TestVisible
    public static Boolean skipHeavyLogic = false;
    
    
/**************************************************************** 
* Class Name  : ExpenseData  @Company  : Fingertip    @Created Date  : 22/10/2025   
@description : newexpense LWC  @Used By  : - Expense New/Edit Button 
* Change Log: 
* ----------------------------------------------------------------------------- 
* Ver |   Author      |   Date        |   Description 
* ----------------------------------------------------------------------------- 
* 1.0 |   Roopesh  |  22/10/2025 |   Initial version      
* -------------------------------------------------------------------
**************************************************************** */
    public class ExpenseData{
        @AuraEnabled public User LoggedInUser;
        @AuraEnabled public User selectedUser;
        @AuraEnabled public Expense__c expense;
        @AuraEnabled public List<Expenses_Line_Item__c> lineItems;
        @AuraEnabled public List<Daily_Log__c> days;
        @AuraEnabled public Travel_Eligibility__c eligibilities;
        @AuraEnabled public List<String> travelTypes;
        @AuraEnabled public List<String> travelModes;
        @AuraEnabled public List<String> expenseTypes;
        @AuraEnabled public List<String> foodTypes;
        @AuraEnabled public List<String> approvalStatus;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public boolean isCurrentUserApprover;
        @AuraEnabled public Id approverId;
        @AuraEnabled public boolean isDistrictInCharge;
        @AuraEnabled public String expenseId;
        @AuraEnabled public String expenseCommnents;
        @AuraEnabled public boolean isCarEnabled  {get;set;}
    @AuraEnabled public boolean isBikeEnabled {get;set;}
    @AuraEnabled public boolean isAutoEnabled {get;set;}
    }
    
    
    
    
    @AuraEnabled(cacheable=false) 
    
    public static ExpenseData getExpenses(String recordId){
        
        string userId = UserInfo.getUserId();
        User userRec = [ SELECT Id, Name, Profile.Name,Expense_Start_Date__c, Expense_End_Date__c,Expense_Back_Day_Entry_Limit__c FROM User WHERE Id = :userId  ];    
        String Executive_Band;
        String Executive_Profile = userRec.Profile.Name;
        String ExectiveId = userRec.Id;

        //======================================
        //Expense Start Date and End Date setting
        //========================================
        Date today = Date.today();
        Integer startDay = 1;
        Integer endDay   = Date.daysInMonth(today.year(), today.month());
        Date startDate = Date.newInstance(today.year(), today.month(), startDay);  // 1st of month
        Date endDate   = Date.newInstance(today.year(), today.month(), endDay);    // last of month

        ExpenseData data = new ExpenseData();
        data.startDate = startDate;
        data.endDate = endDate;
        data.travelModes = getPicklistValues('Expenses_Line_Item__c','Travel_Mode__c');
        data.expenseTypes = getPicklistValues('Expenses_Line_Item__c','Expense_Type__c');
        data.travelTypes = getPicklistValues('Expenses_Line_Item__c','Travel_Type__c');
        data.foodTypes = getPicklistValues('Expenses_Line_Item__c','Food_Type__c');
        data.approvalStatus = getPicklistValues('Expenses_Line_Item__c','Approval_Status__c');
        data.LoggedInUser = userRec;
        system.debug('recordId'+recordId);

        
        Expense__c exp;
   //expense record Id is available then fetch expense record
        if (recordId != null) {
            List<Expense__c> expList = [ SELECT Id, Name, Start_Date__c, End_Date__c, Employee__c, OwnerId, Comments__c, Approval_Status__c, Expense_Approver_L1__c,Executive_Name__c,Expense_Approver_L2__c,Executive_Profile__c,Total_Amount_Auto__c,Total_KM_Bike__c,Total_KM_Car__c  FROM Expense__c WHERE Id = :recordId LIMIT 1 ];
            if (!expList.isEmpty()) {
                exp = expList[0];
                ExectiveId = exp.OwnerId;
                data.startDate = exp.Start_Date__c;
                data.endDate = exp.End_Date__c;
                startDate= exp.Start_Date__c;
               endDate =exp.End_Date__c;
            }
        }
        
        // 2. If not found, check by OwnerId + Start/End date
        if (exp == null) {
            List<Expense__c> expList = [ SELECT Id, Name, Start_Date__c, End_Date__c, Employee__c, OwnerId, Comments__c, Approval_Status__c, Expense_Approver_L1__c,Executive_Name__c,Expense_Approver_L2__c,Executive_Profile__c,Total_Amount_Auto__c,Total_KM_Bike__c,Total_KM_Car__c FROM Expense__c  WHERE OwnerId = :userId AND Start_Date__c = :startDate AND End_Date__c= :endDate LIMIT 1];
            if (!expList.isEmpty()) {  exp = expList[0]; }
        }
        
        // 3. If expense found â†’ fetch line items
        if (exp != null) {
            Executive_Profile = exp.Executive_Profile__c;
            data.lineItems = [
                SELECT Id, Name, Travel_Type__c, Expense_Type__c, Daily_Log__c, Amount__c, Expense__c, Expense_Date__c,City_Name__c,
                Remarks__c, Total_KM__c,Working_Hours__c,Calculated_KM__c,Food_Type__c,lodging_Limit__c,TA_Limit__c,DA_Limit__c,
                Local_Conveyance_Limit__c,localId__c,Approval_Status__c,Travel_Mode__c,System_Calculated_Amount__c, Lodging_Food_Expense_Limit__c,Is_Updated__c
                FROM Expenses_Line_Item__c WHERE Expense__c = :exp.Id  ORDER BY Expense_Date__c ASC ];
            data.expense = exp;
        }
     
        // daily logs in between startdate and enddate
        list<Daily_Log__c> logs = [SELECT Id,Name,Date__c,Travel_Type__c,Total_KM_Travelled__c,Mode_of_transport__c FROM Daily_Log__c WHERE OwnerId=:ExectiveId AND 
                     (Date__c >=:startDate AND Date__c <=:endDate) order by Date__c asc]; 
        for(Daily_Log__c l:logs){
            if(l.Total_KM_Travelled__c !=null){
                l.KMs_Travelled__c =(l.Total_KM_Travelled__c).setScale(0, RoundingMode.HALF_UP);
            }
        }
        
        data.days= logs;
       
        //Travel Eligibliy
        Travel_Eligibility__c travelEligibility;

       Executive_Profile= Executive_Profile=='PT1'? 'System Administrator': Executive_Profile;
            List<Travel_Eligibility__c> profileElig = [SELECT Id,Name,Eligibility_For__c, Profile__c,Conveyance_Allowance_per_KM_Bike__c,
                                                       Conveyance_Allowance_per_KM_Own_Car__c,
                                                       Daily_Allowance_HQ__c, DA_Other_State__c,DA_Other_District__c,
                                                       Monthly_limit_Auto__c,Monthly_limit_Bike__c,Monthly_Limit_Car__c,
                                                       Mandatory_Remarks_File_Types__c,Mandatory_File_Expense_Types__c,
                                                       Lodging_Expense_per_Day_Metro__c, Lodging_Expense_per_Day_Non_Metro__c, 
                                                       Lodging_Food_Expenses__c, Travel_Mode_HQ__c,
                                                       Local_Conveyance__c,Travel_Mode_UC__c,Expense_Type_UC__c,Expense_Type_HQ__c
                                                       FROM Travel_Eligibility__c WHERE Profile__c = :Executive_Profile];
        system.debug('Executive_Profile>>'+Executive_Profile);   
        if (!profileElig.isEmpty()) {
                travelEligibility = profileElig[0];
             if(travelEligibility.Travel_Mode_HQ__c !=null){
                if(travelEligibility.Travel_Mode_HQ__c.contains('Car')){   
                    data.isCarEnabled =true;
                }
                if(travelEligibility.Travel_Mode_HQ__c.contains('Bike')){   
                    data.isBikeEnabled =true;
                }
            if(travelEligibility.Travel_Mode_HQ__c.contains('Autorishaw')){   
                    data.isAutoEnabled =true;
                }
            }
            
             if(travelEligibility.Travel_Mode_UC__c !=null){
                if(travelEligibility.Travel_Mode_UC__c.contains('Car')){   
                    data.isCarEnabled =true;
                }
                if(travelEligibility.Travel_Mode_UC__c.contains('Bike')){   
                    data.isBikeEnabled =true;
                }
            if(travelEligibility.Travel_Mode_UC__c.contains('Autorishaw')){   
                    data.isAutoEnabled =true;
                }
            }
            }
        data.eligibilities = travelEligibility;
        return data;
    }
    
    public static List<String> getPicklistValues(String objectName, String fieldName) {
        List<String> picklistValues = new List<String>();
        
        // Describe the object
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
        
        // Describe the field
        Schema.DescribeFieldResult fieldDescribe = objDescribe.fields.getMap().get(fieldName).getDescribe();
        
        // Get picklist values
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            picklistValues.add(entry.getLabel());
        }
        return picklistValues;
    }
    
    @AuraEnabled(cacheable=false)
    public static Map<String, Boolean> validateFiles(List<Map<String, String>> itemsToCheck) {
        Map<String, Boolean> results = new Map<String, Boolean>(); // key = uniqueKey, value = hasFile?
        
        if (itemsToCheck == null || itemsToCheck.isEmpty()) {
            return results;
        }
        
        // Collect Ids and localIds separately
        Set<Id> docIds = new Set<Id>();
        Set<String> localIds = new Set<String>();
        
        for (Map<String, String> item : itemsToCheck) {
            if (item.containsKey('Id') && String.isNotBlank(item.get('Id'))) {
                docIds.add(item.get('Id'));
            } else if (item.containsKey('localId__c') && String.isNotBlank(item.get('localId__c'))) {
                localIds.add(item.get('localId__c'));
            }
        }
        
        // Query by Id
        Set<Id> foundDocIds = new Set<Id>();
        if (!docIds.isEmpty()) {      
            for(ContentDocumentLink doc:  [SELECT Id, LinkedEntityId, ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN:docIds]) {  
                foundDocIds.add(doc.LinkedEntityId);
            } 
        }
        
        // Query by localId__c (stored in Description)
        Set<String> foundLocalIds = new Set<String>();
        if (!localIds.isEmpty()) {
         
            for (ContentVersion ver : [
                SELECT Description FROM ContentVersion WHERE Description IN :localIds
            ]) {
                foundLocalIds.add(ver.Description);
            }
        }
        
        // Prepare results
        for (Map<String, String> item : itemsToCheck) {
            String uniqueKey = item.get('uniqueKey'); // you send this from LWC
            Boolean hasFile = false;
            
            if (item.containsKey('Id') && foundDocIds.contains(item.get('Id'))) {
                hasFile = true;
            }
            if (item.containsKey('localId__c') && foundLocalIds.contains(item.get('localId__c'))) {
                hasFile = true;
            }
            
            results.put(uniqueKey, hasFile);
        }
        
        return results;
    }
    
    @AuraEnabled
    public static ExpenseData saveExpense(Expense__c expense , list<Expenses_Line_Item__c> expenseItems,List<string> delitems, boolean submitforApproval,boolean approveRecord,boolean rejectRecord,String approvalComments)
    {
        list<Expenses_line_item__c> expenseItemsToUpsert = new list<Expenses_line_item__c>();
        Set<Id> expenseIdsToDelete = new Set<Id>();
        if(delitems.size()>0){
            
            if (delitems != null && !delitems.isEmpty()) {
                for (String idStr : delitems) {
                    if (String.isNotBlank(idStr)) {
                        expenseIdsToDelete.add((Id) idStr);
                    }
                }
            }
            list<Expenses_line_item__c> DelExpLineItem = [select Id,Name from Expenses_line_item__c where id =: delitems];
            delete DelExpLineItem;
        }
        if(expense !=null ){
            if(expense.Id == null){
                User usr = [
                    SELECT Name,managerId 
                    FROM User 
                    WHERE Id = :UserInfo.getUserId() 
                    LIMIT 1
                ];
               expense.Expense_Approver_L1__c=usr.managerId; 
                Date startDate = expense.Start_Date__c;
                Date endDate   = expense.End_Date__c;
                
                // Extract day, month, year parts
                String startDay   = String.valueOf(startDate.day());
                String startMonth = getMonthName(startDate.month());
                String startYear  = String.valueOf(startDate.year());
                
                String endDay     = String.valueOf(endDate.day());
                String endMonth   = getMonthName(endDate.month());
                String endYear    = String.valueOf(endDate.year());
                
                // Build label depending on year change
                String datePart = startDay + ' ' + startMonth + ' ' + startYear + ' To ' + endDay + ' ' + endMonth + ' ' + endYear;

                // Final Name
                expense.Name = datePart + ' / ' + usr.Name;
            }
            // STEP 1: Set required parent field
            // FIRST: Map child type â†’ parent allowed picklist value
            if (!expenseItems.isEmpty()) {
                String childType = expenseItems[0].Expense_Type__c;
            
                // Mapping TA/DA to actual picklist values
                if (childType == 'TA') {
                    expense.Expense_Type__c = 'Travel';
                } else if (childType == 'DA') {
                    expense.Expense_Type__c = 'Daily Allowance';
                } else {
                    expense.Expense_Type__c = childType;  
                    // fallback for other cases if same value exists in parent picklist
                }
            }
            
            // SECOND: Save parent record (MUST be after mapping)
            upsert expense;
             
            // STEP 3 + 4: Now process child line items
            Set<Date> updatedDates = new Set<Date>();
            
            for (Expenses_line_item__c itm : expenseItems) {
            
                if (itm.Is_Updated__c == true && itm.Expense_Date__c != null) {
                    updatedDates.add(itm.Expense_Date__c);
                }
            
                if (String.isEmpty(itm.Id)) {
            
                    // NEW CHILD RECORD
                    Expenses_line_item__c exp = new Expenses_line_item__c();
                    exp.localId__c = itm.localId__c;
                    exp.Expense_Date__c = itm.Expense_Date__c;
                    exp.Expense_Type__c = itm.Expense_Type__c;
                    exp.Travel_Type__c = itm.Travel_Type__c;
                    exp.Travel_Mode__c = itm.Travel_Mode__c;
                    exp.Daily_Log__c = itm.Daily_Log__c;
                    exp.Working_Hours__c = itm.Working_Hours__c;
                    exp.Total_KM__c = itm.Total_KM__c;
                    exp.Amount__c = itm.Amount__c;
                    exp.Remarks__c = itm.Remarks__c;
                    exp.Calculated_KM__c = itm.Calculated_KM__c;
                    exp.Food_Type__c = itm.Food_Type__c;
                    exp.lodging_Limit__c = itm.lodging_Limit__c;
                       exp.TA_Limit__c = itm.TA_Limit__c;
                       exp.DA_Limit__c = itm.DA_Limit__c;
                    exp.Local_Conveyance_Limit__c = itm.Local_Conveyance_Limit__c;
                    exp.System_Calculated_Amount__c = itm.System_Calculated_Amount__c;
            
                    if (submitforApproval && itm.Approval_Status__c == 'Pending') {
                        exp.Approval_Status__c = 'Pending';
                    } else {
                        exp.Approval_Status__c = itm.Approval_Status__c;
                    }
            
                    // LINK CHILD â†’ PARENT
                    exp.Expense__c = expense.Id;
            
                    expenseItemsToUpsert.add(exp);
            
                } else {
            
                    // EXISTING CHILD UPDATE
                    if (!expenseIdsToDelete.contains(itm.Id)) {
            
                        Expenses_line_item__c exp = new Expenses_line_item__c();
                        exp.Id = itm.Id;
                        exp.localId__c = itm.localId__c;
                        exp.Expense_Date__c = itm.Expense_Date__c;
                        exp.Expense_Type__c = itm.Expense_Type__c;
                        exp.Travel_Type__c = itm.Travel_Type__c;
                        exp.Travel_Mode__c = itm.Travel_Mode__c;
                        exp.Daily_Log__c = itm.Daily_Log__c;
                        exp.Working_Hours__c = itm.Working_Hours__c;
                        exp.TA_Limit__c = itm.TA_Limit__c;
                        exp.Total_KM__c = itm.Total_KM__c;
                        exp.DA_Limit__c = itm.DA_Limit__c;
                        exp.Amount__c = itm.Amount__c;
                        exp.Remarks__c = itm.Remarks__c;
                        exp.Calculated_KM__c = itm.Calculated_KM__c;
                        exp.Food_Type__c = itm.Food_Type__c;
                        exp.lodging_Limit__c = itm.lodging_Limit__c;
                        exp.Local_Conveyance_Limit__c = itm.Local_Conveyance_Limit__c;
                        exp.System_Calculated_Amount__c = itm.System_Calculated_Amount__c;
            
                        if (itm.Is_Updated__c == true)
                            exp.Approval_Status__c = itm.Approval_Status__c;
            
                        expenseItemsToUpsert.add(exp);
                    }
                }
            }
            
            // STEP 4: Save all child rows
            upsert expenseItemsToUpsert;

           
            ExpenseData data = new ExpenseData();
            //When Submitted
            if(expense.Id != null)
            {
                string currentUserId = UserInfo.getUserId();
                user currentUser = [select Id,Name from User where Id =:currentUserId ];
                list<Expense__c> expenseRecord = [select Id,Name,Expense_Approver_L1__c,Expense_Executive_Name__c,
                                                  OwnerId,Comments__c
                                                   from Expense__c where Id =:expense.Id ];
                //,Expense_Finance_Department_Approver__c,Expense_Approver_L2__c
                
                // After upsert of expense and items
                if (!String.isBlank(approvalComments)) {
                    // Fetch existing comment history
                    String existingComments = expenseRecord[0].Comments__c != null
                        ? expenseRecord[0].Comments__c + '\n\n'
                        : '';
                    system.debug('existingComments'+existingComments);
                    
                    String currentUserName = currentUser.Name;
                    String currentDate = Datetime.now().format('dd-MMM-yyyy hh:mm a');
                    
                    // Clean up comment text (remove brackets and trim spaces)
                    String cleanComment = approvalComments.replaceAll('\\[|\\]', '').trim();
                    system.debug('cleanComment'+cleanComment);
                    
                    // Create new formatted comment block
                    String newFormattedComment = '[' + currentDate + ' | ' + currentUserName + ']\n' + cleanComment;
                    
                    system.debug('newFormattedComment'+newFormattedComment);
                    
                    // Append to history
                    expenseRecord[0].Comments__c = existingComments + newFormattedComment;
                    
                    update expenseRecord[0];
                    
                }

                data.expenseCommnents = expenseRecord[0].Comments__c;

                if (!updatedDates.isEmpty() && !expenseRecord.isEmpty() ) {
                    expense__c expRec =  expenseRecord[0];
                    // Find min and max date
                    Date minDate = null;
                    Date maxDate = null;
                    for (Date d : updatedDates) {
                        if (minDate == null || d < minDate) minDate = d;
                        if (maxDate == null || d > maxDate) maxDate = d;
                    }
                    String dateRange = 'Date Range : ' +
                        minDate.format() + ' to ' + maxDate.format();
                    CustomNotificationType notificationType = [
                        SELECT Id 
                        FROM CustomNotificationType 
                        WHERE DeveloperName = 'Expense_Approval_Notification' 
                        LIMIT 1
                    ];
                    if(submitforApproval == true)
                    {
                        List<Expenses_line_item__c> toUpdate = new List<Expenses_line_item__c>();
                        for (Expenses_line_item__c e : expenseItemsToUpsert) {
                            if (e.Approval_Status__c == 'Pending') {
                                e.Approval_Status__c = 'Pending';
                                toUpdate.add(e);
                            }
                        }
                        if (!toUpdate.isEmpty()) {
                            update toUpdate; // This will trigger Field History Tracking
                        }
                        // ---- Notification for Current User ----
                        CustomNotificationService.notificationSend(
                            'Expenses has been Submitted for Approval', 
                            expRec.Id, 
                            'Executive Name : ' + expRec.Expense_Executive_Name__c+'\n'+dateRange, 
                            new Set<String>{expRec.OwnerId }, 
                            notificationType.Id
                        );

                        
                        // ---- Notification for Approver ----
                        Id approverId;
                        if (expRec.Expense_Approver_L1__c != null)
                        {
                            approverId = expRec.Expense_Approver_L1__c;
                        } 
                     
                        
                        if (approverId != null) {
                            CustomNotificationService.notificationSend(
                                currentUser.Name+' is requesting approval for expense', 
                                expRec.Id, 
                                'Executive Name : ' + expRec.Expense_Executive_Name__c+'\n'+dateRange, 
                                new Set<String>{approverId }, 
                                notificationType.Id
                            );
                        }
                    }
                    //when approved or rejected
                    if ((approveRecord == true || rejectRecord == true)) {
                        
                        data.lineItems = [
                            SELECT Id, Name, Travel_Mode__c, Travel_Type__c, Expense_Type__c,
                            Daily_Log__c, Amount__c, Expense__c, Expense_Date__c,City_Name__c,
                            Remarks__c, Total_KM__c,Working_Hours__c,Calculated_KM__c,Food_Type__c,lodging_Limit__c,
                            Local_Conveyance_Limit__c,localId__c,Approval_Status__c,System_Calculated_Amount__c,
                            Lodging_Food_Expense_Limit__c
                            FROM Expenses_Line_Item__c 
                            WHERE Expense__c = :expense.Id
                            ORDER BY Expense_Date__c ASC
                        ];
                        //City__c,Day__c
                        if(approveRecord == true)
                        {
                            // ---- Notification for Owner----
                            CustomNotificationService.notificationSend(
                                'Expenses has been Approved by '+ currentUser.Name, 
                                expRec.Id, 
                                'Executive Name : ' + expRec.Expense_Executive_Name__c+'\n'+dateRange,
                                new Set<String>{ expRec.OwnerId }, 
                                notificationType.Id
                            );
                            
                            // ---- Notification for Approver ----
                            if (currentUserId != null) {
                                CustomNotificationService.notificationSend(
                                    'Approval request for expense is approved', 
                                    expRec.Id, 
                                     'Executive Name : ' + expRec.Expense_Executive_Name__c+'\n'+dateRange,
                                    new Set<String>{currentUserId }, 
                                    notificationType.Id
                                );
                            }
                            
                        }
                        
                        if(rejectRecord == true)
                        {
                            // ---- Notification for Owner----
                            CustomNotificationService.notificationSend(
                                'Expenses has been Rejected by '+ currentUser.Name, 
                                expRec.Id, 
                                'Executive Name : ' + expRec.Expense_Executive_Name__c+'\n'+dateRange,
                                new Set<String>{ expRec.OwnerId }, 
                                notificationType.Id
                            );
                            
                            // ---- Notification for Approver ----
                            CustomNotificationService.notificationSend(
                                'Approval request for expense is rejected', 
                                expRec.Id, 
                                'Executive Name : ' + expRec.Expense_Executive_Name__c+'\n'+dateRange,
                                new Set<String>{currentUserId }, 
                                notificationType.Id
                            );
                            
                        }  
                    } 
                }    
            }
       
            data.expenseId = expense.Id;
            
            return data;
        }
        else{
            return null;
        }
    }
    
    public static String getMonthName(Integer monthNumber) {
        String monthName = '';
        switch on monthNumber {
            when 1{
                monthName = 'JAN';
            }
            when 2{
                monthName = 'FEB';
            }
            when 3{
                monthName = 'MARCH';
            }
            when 4{
                monthName = 'APRIL';
            }
            when 5{
                monthName = 'MAY';
            }
            when 6{
                monthName = 'JUNE';
            }
            when 7{
                monthName = 'JULY';
            }
            when 8{
                monthName = 'AUG';
            }
            when 9{
                monthName = 'SEPT';
            }
            when 10{
                monthName = 'OCT';
            }
            when 11{
                monthName = 'NOV';
            }
            when 12{
                monthName = 'DEC';
            }
        }
        return monthName;
    }  
    
}