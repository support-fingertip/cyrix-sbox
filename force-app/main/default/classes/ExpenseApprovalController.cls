public class ExpenseApprovalController {
    @auraEnabled 
    public Expense__c expense {get;set;}
    @auraEnabled 
    public List<ExpenseWrapper> result {get;set;} 
    @auraEnabled 
    public Travel_Eligibility__c travelEligibile {get;set;} 
    @AuraEnabled public boolean isDistrictInCharge {get;set;}
    @AuraEnabled public boolean isCarEnabled  {get;set;}
    @AuraEnabled public boolean isBikeEnabled {get;set;}
    @AuraEnabled public boolean isAutoEnabled {get;set;}
        @AuraEnabled public string bikeExpenseExceeded {get;set;}
         @AuraEnabled public string carExpenseExceeded {get;set;}
         @AuraEnabled public string autoExpenseExceeded{get;set;}
    
    @AuraEnabled(cacheable=true)
    public static ExpenseApprovalController getExpenseLineItems(Id recordId) {
        ExpenseApprovalController exp = new ExpenseApprovalController();
         string systemCalCulatedKm = '',systemCalculatedODOKm='',limitExceeded='';
        List<ExpenseWrapper> result = new List<ExpenseWrapper>();
        string userId = UserInfo.getUserId();
        Id profileId = UserInfo.getProfileId();
           Profile p = [SELECT Name FROM Profile WHERE Id = :profileId];
        Expense__c expense = [select Id,Expense_Approver_L1__c, Expense_Approver_L2__c, Executive_Profile__c,totalApprovedTAAuto__c, totalApprovedTABike__c, totalApprovedTACar__c, totalSubmittedTABike__c, totalSubmittedTAAuto__c, Total_KM_Car__c, Total_KM_Bike__c, Total_Amount_Auto__c, totalSubmittedTACar__c,
                              Expense_Finance_Department_Approver__c,OwnerId from Expense__c where Id =:recordId];
        exp.expense =expense;
        string   Executive_Profile = expense.Executive_Profile__c;
            Executive_Profile= Executive_Profile=='PT1'? 'System Administrator': Executive_Profile;
          List<Travel_Eligibility__c> profileElig = [SELECT Id,Name,Eligibility_For__c, Profile__c,Conveyance_Allowance_per_KM_Bike__c,
                                                       Conveyance_Allowance_per_KM_Own_Car__c,
                                                       Daily_Allowance_HQ__c, DA_Other_State__c,DA_Other_District__c,
                                                       Monthly_limit_Auto__c,Monthly_limit_Bike__c,Monthly_Limit_Car__c,
                                                       Mandatory_Remarks_File_Types__c,Mandatory_File_Expense_Types__c,
                                                       Lodging_Expense_per_Day_Metro__c, Lodging_Expense_per_Day_Non_Metro__c, 
                                                       Lodging_Food_Expenses__c, Travel_Mode_HQ__c,OutofStateSingle_Occupancy_Accommodation__c,
                                                        Accommodation_Other_District__c,In_State_Double_Occupancy_Accommodation__c,
                                                   OutofStateDouble_Occupancy_Accommodation__c,In_State_Single_Occupancy_Accommodation__c,
                                                       Local_Conveyance__c,Travel_Mode_UC__c,Expense_Type_UC__c,Expense_Type_HQ__c
                                                    FROM Travel_Eligibility__c WHERE Profile__c = :Executive_Profile];
        if(profileElig.size() >0)  {
        exp.travelEligibile = profileElig[0];
             if(exp.travelEligibile.Travel_Mode_HQ__c !=null){
                if(exp.travelEligibile.Travel_Mode_HQ__c.contains('Car')){   
                    exp.isCarEnabled =true;
                }
                if(exp.travelEligibile.Travel_Mode_HQ__c.contains('Bike')){   
                    exp.isBikeEnabled =true;
                }
            if(exp.travelEligibile.Travel_Mode_HQ__c.contains('Autorishaw')){   
                    exp.isAutoEnabled =true;
                }
            }
            
             if(exp.travelEligibile.Travel_Mode_UC__c !=null){
                if(exp.travelEligibile.Travel_Mode_UC__c.contains('Car')){   
                    exp.isCarEnabled =true;
                }
                if(exp.travelEligibile.Travel_Mode_UC__c.contains('Bike')){   
                    exp.isBikeEnabled =true;
                }
            if(exp.travelEligibile.Travel_Mode_UC__c.contains('Autorishaw')){   
                    exp.isAutoEnabled =true;
                }
            }
            if(exp.isCarEnabled){
                if(exp.travelEligibile.Monthly_Limit_Car__c !=null && expense.Total_KM_Car__c !=null &&  exp.travelEligibile.Monthly_Limit_Car__c < expense.Total_KM_Car__c){
                    exp.carExpenseExceeded ='ta-value Highlight-in-red';
                }else{
                     exp.carExpenseExceeded ='ta-value Highlight-in-green';
                }
            }
             if(exp.isBikeEnabled){
                if( exp.travelEligibile.Monthly_limit_Bike__c !=null && expense.Total_KM_Bike__c!=null &&  exp.travelEligibile.Monthly_limit_Bike__c < expense.Total_KM_Bike__c){
                    exp.bikeExpenseExceeded ='ta-value Highlight-in-red';
                }else{
                     exp.bikeExpenseExceeded ='ta-value Highlight-in-green';
                }
            }
            if(exp.isAutoEnabled){
                if( exp.travelEligibile.Monthly_limit_Auto__c!=null&& expense.Total_Amount_Auto__c !=null && exp.travelEligibile.Monthly_limit_Auto__c < expense.Total_Amount_Auto__c){
                    exp.autoExpenseExceeded =' ta-value Highlight-in-red';
                }else{
                     exp.autoExpenseExceeded ='ta-value Highlight-in-green';
                }
            }
        }
        
        List<Expenses_Line_Item__c> lineItems = new List<Expenses_Line_Item__c>();
        if(expense.OwnerId == userId)
        {
            // Step 1: Query line items
            lineItems = [
                SELECT Id, Approval_Status__c,Name, Expense_Type__c,Submitted_Amount__c, Total_Distance_Calculated_by_ODM_Reading__c,Total_KM__c, Local_Conveyance_Limit__c,Lodging_Food_Expense_Limit__c,lodging_Limit__c,TA_Limit__c,DA_Limit__c,
                Amount__c,City_Name__c,Expense_Date__c,expense__r.Expense_Approver_L1__c,expense__r.Expense_Approver_L2__c,Travel_Mode__c,
                System_Calculated_Amount__c,Calculated_KM__c,Remarks__c
                FROM Expenses_Line_Item__c
                WHERE Expense__c = :recordId
                ORDER BY CreatedDate ASC ];
           
            
        }
        else if(expense.OwnerId == expense.Expense_Finance_Department_Approver__c)
        {
            
            lineItems = [
                SELECT Id, Approval_Status__c,Name, Expense_Type__c,Submitted_Amount__c, Total_KM__c,Total_Distance_Calculated_by_ODM_Reading__c ,Local_Conveyance_Limit__c,Lodging_Food_Expense_Limit__c,lodging_Limit__c,TA_Limit__c,DA_Limit__c,
                Amount__c,City_Name__c,Expense_Date__c,expense__r.Expense_Approver_L1__c,expense__r.Expense_Approver_L2__c,Travel_Mode__c,
                System_Calculated_Amount__c,Calculated_KM__c,Remarks__c
                FROM Expenses_Line_Item__c
                WHERE Expense__c = :recordId
                AND Approval_Status__c NOT IN ('Not Submitted', 'Draft','Level 1 Rejected')
                ORDER BY CreatedDate ASC
            ];
        }
        else{
            lineItems = [
                SELECT Id, Approval_Status__c,Name, Expense_Type__c, Submitted_Amount__c,Total_Distance_Calculated_by_ODM_Reading__c,Total_KM__c, Local_Conveyance_Limit__c,Lodging_Food_Expense_Limit__c,lodging_Limit__c,TA_Limit__c,DA_Limit__c,
                Amount__c,City_Name__c,Expense_Date__c,expense__r.Expense_Approver_L1__c,expense__r.Expense_Approver_L2__c,Travel_Mode__c,
                System_Calculated_Amount__c,Calculated_KM__c,Remarks__c
                FROM Expenses_Line_Item__c
                WHERE Expense__c = :recordId
                AND Approval_Status__c NOT IN ('Not Submitted', 'Draft')
                ORDER BY CreatedDate ASC
            ];
        }
        
      
        
        
       
        
        // Step 2: Collect IDs
        Set<Id> lineItemIds = new Set<Id>();
        for (Expenses_Line_Item__c e : lineItems) {
            lineItemIds.add(e.Id);
        }
        
        // Step 3: Query related files only if we have IDs
        Map<Id, List<FileWrapper>> fileMap = new Map<Id, List<FileWrapper>>();
        if (!lineItemIds.isEmpty()) {
            for (ContentDocumentLink cdl : [
                SELECT ContentDocumentId, LinkedEntityId,
                ContentDocument.Title, ContentDocument.FileType, ContentDocument.LatestPublishedVersionId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :lineItemIds
            ]) {
                if (!fileMap.containsKey(cdl.LinkedEntityId)) {
                    fileMap.put(cdl.LinkedEntityId, new List<FileWrapper>());
                }
                fileMap.get(cdl.LinkedEntityId)
                    .add(new FileWrapper(
                        cdl.ContentDocumentId,
                        cdl.ContentDocument.Title,
                        cdl.ContentDocument.FileType,
                        cdl.ContentDocument.LatestPublishedVersionId
                    ));
            }
        }
        
        // Step 4: Wrap up
        Id currentUserId = UserInfo.getUserId();
        for (Expenses_Line_Item__c item : lineItems) {
            Boolean canEditOrApprove = (item.expense__r.Expense_Approver_L1__c == currentUserId ||
                                        item.expense__r.Expense_Approver_L2__c == currentUserId);
            
            List<FileWrapper> files = fileMap.containsKey(item.Id) ? fileMap.get(item.Id) : new List<FileWrapper>();
            
            decimal explimtAmt = 0,varianceGoogle=0,varianceODO=0;string expenseLimit='',submittedAmt='',varianceClassGoogle='',varianceClassOdo='',otherExpenseLimitClass='';
            if(item.Expense_Type__c == 'Local Conveyance'){  explimtAmt = item.Local_Conveyance_Limit__c;}
                else if(item.Expense_Type__c == 'Accommodation'){ explimtAmt = item.lodging_Limit__c;}
              else if(item.Expense_Type__c == 'DA'){ explimtAmt = item.DA_Limit__c;}
               else if(item.Expense_Type__c == 'TA'){ explimtAmt = item.TA_Limit__c;}
           
           expenseLimit =(explimtAmt==null? '':explimtAmt+'');
            submittedAmt =item.Submitted_Amount__c+'';
            if(item.Expense_Type__c == 'TA') {
                systemCalCulatedKm = string.valueof(item.Calculated_KM__c !=null ?item.Calculated_KM__c :0);   
                systemCalculatedODOKm= string.valueof(item.Total_Distance_Calculated_by_ODM_Reading__c !=null ?item.Total_Distance_Calculated_by_ODM_Reading__c :0); 
            } else{
                systemCalCulatedKm = '';   
                systemCalculatedODOKm='';
            }
            //limits
            if(item.Expense_Type__c == 'TA'){
                if((item.Travel_Mode__c =='Bike' || item.Travel_Mode__c=='Car') && item.TA_Limit__c!=null &&  item.Total_KM__c!=null) {
                    limitExceeded= ((item.TA_Limit__c < item.Total_KM__c) && (canEditOrApprove || p.Name=='System Administrator'))?'Highlight-in-red':'';
                    if(item.Calculated_KM__c !=null && item.Calculated_KM__c!=0){
                        if(item.Total_KM__c !=null  ){
                            varianceGoogle =((item.Total_KM__c -item.Calculated_KM__c)/item.Calculated_KM__c)*100;
                            if(varianceGoogle > 15){
                                varianceClassGoogle='Highlight-in-orange';
                            }
                        }        
                        if(item.Total_Distance_Calculated_by_ODM_Reading__c !=null  ){
                            varianceODO =((item.Total_Distance_Calculated_by_ODM_Reading__c -item.Calculated_KM__c)/item.Calculated_KM__c)*100;
                            if(varianceODO > 15){
                                varianceClassOdo='Highlight-in-orange';
                            }
                        }
                    }
                }
                  otherExpenseLimitClass='';
            }else{
                limitExceeded='';
                varianceClassGoogle='';
                varianceClassOdo='';
                if(item.Expense_Type__c == 'DA' && item.DA_Limit__c !=null && item.Amount__c !=null && item.DA_Limit__c< item.Amount__c){
                    otherExpenseLimitClass='Highlight-in-blue';
                }else if(item.Expense_Type__c == 'Accommodation' && item.lodging_Limit__c !=null &&  item.Amount__c !=null && item.lodging_Limit__c < item.Amount__c){
                      otherExpenseLimitClass='Highlight-in-blue';
                }else{
                      otherExpenseLimitClass='';
                }
            }
            
            result.add(new ExpenseWrapper(item.Id,item.Name,item.Approval_Status__c,item.Expense_Date__c,
                                          item.Expense_Type__c,item.Travel_Mode__c, item.City_Name__c,
                                          expenseLimit,submittedAmt, systemCalCulatedKm,systemCalculatedODOKm,item.System_Calculated_Amount__c,item.Total_KM__c,
                                          item.Amount__c, canEditOrApprove, files,item.Remarks__c,limitExceeded,varianceClassGoogle,varianceClassOdo,otherExpenseLimitClass
                                         ));
            
        }
        exp.result =result;
     return exp;
    }
    @AuraEnabled(cacheable=true)
    public static DataBox getExpenseDetails(Id expenseId) {
        DataBox dt = new DataBox();
        string userId = UserInfo.getUserId();
        User us = [select Id,Name,Profile.Name from User where Id =:userId ];
        Expense__c expense = [SELECT Id, Expense_Approver_L1__c, Expense_Approver_L2__c, Expense_Finance_Department_Approver__c,OwnerId
                              FROM Expense__c
                              WHERE Id = :expenseId
                              LIMIT 1];
        dt.expense = expense;
        dt.isOpenedByOwner = expense.OwnerId == userId;
        dt.isOpenedByAdmin = us.Profile.Name == 'System Administrator';
        return dt;
    }
    
    @AuraEnabled 
    public static void updateExpenseLineItems(List<Expenses_Line_Item__c> updatedExpenses) {
        system.debug('updatedExpenses>>'+updatedExpenses);
        update updatedExpenses;
    } 
    @AuraEnabled
    public static void approveExpenseItems(List<Id> expenseIds,String expId,String approvalComments) {
        List<Expenses_Line_Item__c> itemsToApprove = [
            SELECT Id, Approval_Status__c,Expense_Date__c
            FROM Expenses_Line_Item__c
            WHERE Id IN :expenseIds
        ];
        string loggedInUserId = UserInfo.getUserId();
        user currentUser = [select Id,Name,Profile.Name from User where Id =:loggedInUserId ];
        Expense__c exp = [select Id,Name,Expense_Approver_L1__c,Expense_Finance_Department_Approver__c,Comments__c,
                          Expense_Approver_L2__c,Expense_Executive_Name__c,OwnerId from Expense__c where Id =:expId ];
        
        // After upsert of expense and items
        if (!String.isBlank(approvalComments)) {
            // Fetch existing comment history
            String existingComments = exp.Comments__c != null
                ? exp.Comments__c + '\n\n'
                : '';
            system.debug('existingComments'+existingComments);
            
            String currentUserName = currentUser.Name;
            String currentDate = Datetime.now().format('dd-MMM-yyyy hh:mm a');
            
            // Clean up comment text (remove brackets and trim spaces)
            String cleanComment = approvalComments.replaceAll('\\[|\\]', '').trim();
            system.debug('cleanComment'+cleanComment);
            Expense__c expRec = new Expense__c();
            expRec.Id = exp.Id;
            // Create new formatted comment block
            String newFormattedComment = '[' + currentDate + ' | ' + currentUserName + ']\n' + cleanComment;
            
            system.debug('newFormattedComment'+newFormattedComment);
            
            // Append to history
            expRec.Comments__c = existingComments + newFormattedComment;
            
            update expRec;
            
        }

        Set<Date> updatedDates = new Set<Date>();
        for (Expenses_Line_Item__c item : itemsToApprove) {
            if (item.Expense_Date__c != null) {
                updatedDates.add(item.Expense_Date__c);
            }
            if (exp.Expense_Approver_L1__c == loggedInUserId) {
                item.Approval_Status__c = 'Level 1 Approved';
            }
            else if (exp.Expense_Finance_Department_Approver__c == loggedInUserId) {
                item.Approval_Status__c = 'HR Approved';
            }
            else if(currentUser.Profile.Name == 'System Administrator')
            {
                if(item.Approval_Status__c == 'Pending' && exp.Expense_Approver_L1__c != null){
                    item.Approval_Status__c = 'Level 1 Approved';
                }
                else if(item.Approval_Status__c == 'Pending' && exp.Expense_Approver_L1__c == null){
                    item.Approval_Status__c = 'HR Approved';
                }
                else if(item.Approval_Status__c == 'Level 1 Approved'){
                    item.Approval_Status__c = 'HR Approved';
                }
            }
        }
        update itemsToApprove;
        
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
        
        // ---- Notification for Owner----
        CustomNotificationService.notificationSend(
            'Expenses has been Approved by '+ currentUser.Name, 
            exp.Id, 
            'Executive Name : ' + exp.Expense_Executive_Name__c+'\n'+dateRange,
            new Set<String>{ exp.OwnerId }, 
            notificationType.Id
        );
        
        // ---- Notification for Approver ----
        if (loggedInUserId != null) {
            CustomNotificationService.notificationSend(
                'Approval request for expense is approved', 
                exp.Id, 
                'Executive Name : ' + exp.Expense_Executive_Name__c+'\n'+dateRange,
                new Set<String>{loggedInUserId }, 
                notificationType.Id
            );
        }
        
        // ----Notification for Next Approver----
        Id nextApprovedId;
        if (exp.Expense_Approver_L1__c == loggedInUserId)
        {
            if(exp.Expense_Approver_L2__c != null )
            {
                nextApprovedId = exp.Expense_Approver_L2__c;
            }
            else 
            {
                nextApprovedId = exp.Expense_Finance_Department_Approver__c;
            }
        } 
        else if (exp.Expense_Approver_L2__c == loggedInUserId)
        {
            if(exp.Expense_Finance_Department_Approver__c != null )
            {
                nextApprovedId = exp.Expense_Approver_L2__c;
            }
        } 
        
        if (nextApprovedId != null) {
            CustomNotificationService.notificationSend(
                currentUser.Name+' is requesting approval for expense', 
                exp.Id, 
                'Executive Name : ' + exp.Expense_Executive_Name__c+'\n'+dateRange, 
                new Set<String>{nextApprovedId }, 
                notificationType.Id
            );
        }
       
    }
    
    @AuraEnabled
    public static void rejectExpenses(List<Id> expenseIds,String expId,String approvalComments) {
        List<Expenses_Line_Item__c> itemsToApprove = [
            SELECT Id, Approval_Status__c,Expense_Date__c
            FROM Expenses_Line_Item__c
            WHERE Id IN :expenseIds
        ];
        string loggedInUserId = UserInfo.getUserId();
        user currentUser = [select Id,Name,Profile.Name from User where Id =:loggedInUserId ];
        Expense__c exp = [select Id,Name,Expense_Approver_L1__c,Expense_Finance_Department_Approver__c,Comments__c,
                          Expense_Approver_L2__c,Expense_Executive_Name__c,OwnerId from Expense__c where Id =:expId ];
        
        // After upsert of expense and items
        if (!String.isBlank(approvalComments)) {
            // Fetch existing comment history
            String existingComments = exp.Comments__c != null
                ? exp.Comments__c + '\n\n'
                : '';
            system.debug('existingComments'+existingComments);
            
            String currentUserName = currentUser.Name;
            String currentDate = Datetime.now().format('dd-MMM-yyyy hh:mm a');
            
            // Clean up comment text (remove brackets and trim spaces)
            String cleanComment = approvalComments.replaceAll('\\[|\\]', '').trim();
            system.debug('cleanComment'+cleanComment);
            Expense__c expRec = new Expense__c();
            expRec.Id = exp.Id;
            // Create new formatted comment block
            String newFormattedComment = '[' + currentDate + ' | ' + currentUserName + ']\n' + cleanComment;
            
            system.debug('newFormattedComment'+newFormattedComment);
            
            // Append to history
            expRec.Comments__c = existingComments + newFormattedComment;
            
            update expRec;
            
        }
        
        Set<Date> updatedDates = new Set<Date>();
        for (Expenses_Line_Item__c item : itemsToApprove) {
            if (item.Expense_Date__c != null) {
                updatedDates.add(item.Expense_Date__c);
            }
            if (exp.Expense_Approver_L1__c == loggedInUserId) {
                item.Approval_Status__c = 'Level 1 Rejected';
            }
            else if (exp.Expense_Finance_Department_Approver__c == loggedInUserId) {
                item.Approval_Status__c = 'HR Rejected';
            }
            else if(currentUser.Profile.Name == 'System Administrator')
            {
                if(item.Approval_Status__c == 'Pending' && exp.Expense_Approver_L1__c != null){
                    item.Approval_Status__c = 'Level 1 Rejected';
                }
                else if(item.Approval_Status__c == 'Pending' && exp.Expense_Approver_L1__c == null ){
                    item.Approval_Status__c = 'HR Rejected';
                }
                else if(item.Approval_Status__c == 'Level 1 Approved' ){
                    item.Approval_Status__c = 'HR Rejected';
                }
            }
            
        }
        update itemsToApprove;
        
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
       
        
        // ----Notification for Owner----
        CustomNotificationService.notificationSend(
            'Expenses has been Rejected by '+ currentUser.Name, 
            exp.Id, 
            'Executive Name : ' + exp.Expense_Executive_Name__c+'\n'+dateRange,
            new Set<String>{ exp.OwnerId }, 
            notificationType.Id
        );
        
        // ---- Notification for current Approver ----
        CustomNotificationService.notificationSend(
            'Approval request for expense is rejected', 
            exp.Id, 
            'Executive Name : ' + exp.Expense_Executive_Name__c+'\n'+dateRange,
            new Set<String>{loggedInUserId }, 
            notificationType.Id
        );
        
    }
    
    
    @AuraEnabled
    public static void rejectExpenses1(List<Id> expenseIds,String expId,String approvalComments) {
        List<Expenses_Line_Item__c> itemsToApprove = [
            SELECT Id, Approval_Status__c
            FROM Expenses_Line_Item__c
            WHERE Id IN :expenseIds
        ];
        
        for (Expenses_Line_Item__c item : itemsToApprove) {
            if (item.Approval_Status__c == 'Pending')
                item.Approval_Status__c = 'Level 1 Rejected';
            else if (item.Approval_Status__c == 'Level 1 Approved')
                item.Approval_Status__c = 'HR Rejected';
            else if (item.Approval_Status__c == 'HR Approved')
                item.Approval_Status__c = 'HR Rejected';
        }
        
        update itemsToApprove;
    }
    
    public class ExpenseWrapper {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public date expDate;
        @AuraEnabled public String expType;
        @AuraEnabled public String travelMode;
        @AuraEnabled public String city;
        @AuraEnabled public string lLimit;
        @AuraEnabled public string submittedAmt;
        @AuraEnabled public string systemCalculatedKm; 
        @AuraEnabled public string systemCalculatedODOKm; 
        @AuraEnabled public Decimal systemCalculatedAmount; 
        @AuraEnabled public Decimal totKM;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Boolean canEditOrApprove;
        @AuraEnabled public List<FileWrapper> files;
        @AuraEnabled public String remarks;
        @AuraEnabled public String limitExceeded;
        @AuraEnabled public String highlightClass;
        @AuraEnabled public String varianceClassOdo;
        @AuraEnabled public String varianceClassGoogle;
        @AuraEnabled public Boolean isEditable;
        @AuraEnabled public Boolean isSelectable;
          @AuraEnabled public String otherExpenseLimitClass;
        public ExpenseWrapper(Id recordId,string name, String status,date expDate,String expType, 
                              String travelMode,String city,string lLimit,string submittedAmt,string systemCalculatedKm,string systemCalculatedODOKm,
                              Decimal systemCalculatedAmount,Decimal totKM, Decimal amount,
                              Boolean canEditOrApprove, List<FileWrapper> files,String remarks,string limitExceeded,string varianceClassGoogle,string varianceClassOdo,string otherExpenseLimitClass
                              )
        {
            
            this.recordId = recordId;
            this.name = name;
            this.status = status;
            this.expDate = expDate;
            this.expType = expType;
            if(this.expType =='DA'){
                this.travelMode ='';
            }else{
                this.travelMode = travelMode;
            }
            this.city = city;
            this.lLimit = lLimit;
              this.submittedAmt = submittedAmt;
            this.systemCalculatedKm = systemCalculatedKm;
            this.systemCalculatedAmount = systemCalculatedAmount;
            this.systemCalculatedODOKm = systemCalculatedODOKm;
            this.totKM = totKM;
            this.amount = amount;
            this.canEditOrApprove = canEditOrApprove;
            this.files = files;
            this.remarks = remarks;
            this.isEditable = false;
            this.isSelectable = false;
            this.highlightClass = 'highlight-cell';
             this.limitExceeded = limitExceeded;
              this.varianceClassOdo = varianceClassOdo;
            this.varianceClassGoogle=varianceClassGoogle;
             this.otherExpenseLimitClass=otherExpenseLimitClass;
        }
    }
    
    // Wrapper for Files
    public class FileWrapper {
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String title;
        @AuraEnabled public String fileType;
        @AuraEnabled public Id latestVersionId;
        
        public FileWrapper(Id contentDocumentId, String title, String fileType, Id latestVersionId) {
            this.contentDocumentId = contentDocumentId;
            this.title = title;
            this.fileType = fileType;
            this.latestVersionId = latestVersionId;
        }
    }
    
    public class DataBox
    {
        @AuraEnabled public Expense__c expense;
        @AuraEnabled public boolean isOpenedByOwner;
        @AuraEnabled public boolean isOpenedByAdmin;
      
    }
    
}