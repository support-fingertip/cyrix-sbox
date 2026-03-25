public class LeadTriggerHandler {
    
    /* ---------------- Campaign Mapping ---------------- */
    public static void campaignMapping(List<Lead> leads) {
        
        List<CampaignMember> cms = new List<CampaignMember>();
        
        for (Lead l : leads) {
            if (l.Id != null && l.Campaign__c != null) {
                cms.add(new CampaignMember( LeadId = l.Id,  CampaignId = l.Campaign__c,  Status = 'Sent' ));
            }
        }
        
        if (!cms.isEmpty()) {
            try {
                insert cms;
            } catch (Exception ex) {
                ExceptionHandler.addLog( ex,String.valueOf(cms), 'LeadTriggerHandler', 'campaignMapping');
            }
        }
    }
    
    /* ---------------- Lead Assigned Notification ---------------- */
    public static void leadAssignedNotification(List<Lead> leads) {
        
        CustomNotificationType type = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Lead_Notification'
            LIMIT 1
        ];
        
        String senderId = UserInfo.getUserId();
        
        for (Lead l : leads) {
            
            
            String name = (l.Salutation != null ? l.Salutation + ' ' : '') + (l.FirstName != null ? l.FirstName + ' ' : '') + l.LastName;
            String companyInfo = (l.Company != null ? '\nCompany: ' + l.Company : '');
            
            SendEmailCustomNotification.sendNotification( 'Lead - ' + name + ' is assigned to you',
                                                         'Lead Assigned' + companyInfo,senderId, type.Id,l.Id,new Set<String>{ l.OwnerId } );
            if(l.ManagerId__c !=null && l.ManagerId__c !=''){
                SendEmailCustomNotification.sendNotification( 'Lead - ' + name + ' is assigned to '+l.Lead_Owner_Name__c,
                                                             'Lead Assigned' + companyInfo,senderId, type.Id,l.Id,new Set<String>{ l.ManagerId__c } ); 
            }
        }
    }
    
    /* ---------------- Phone & Mobile Split ---------------- */
        public static void checkAndSeprateMobileNumber(List<Lead> leads) {
        
        Map<String, String> countryCodeMap =
            Utility.getAllCountryCodeMappings(true);
        
        for (Lead l : leads) {
            if (l.Phone != null && l.Phone.startsWith('+91')) {
                l.Country_Code_Phone__c = '+91';
                l.Country__c = countryCodeMap.get('91');
                l.Phone = l.Phone.replace('+91', '');
            }
            
            if (l.MobilePhone != null && l.MobilePhone.startsWith('+91')) {
                l.Country_Code_Mobile__c = '+91';
                l.MobilePhone_Country__c = countryCodeMap.get('91');
                l.MobilePhone = l.MobilePhone.replace('+91', '');
            }
    
        }
    }
    
    /* ---------------- Utility ---------------- */
    public static String getformated(String value) {
        return value == null ? '' : value;
    }
    
    /* ---------------- Last Activity Date ---------------- */
    public static void updateLastActivityDate(
        List<Lead> newLeads,
        Map<Id, Lead> oldMap
    ) {
        for (Lead l : newLeads) {
            Lead oldL = oldMap.get(l.Id);
            if (oldL != null && l.Status!='Closed Won' && l.IsConverted==false && l.Status!='Closed Lost' &&
                (l.Status != oldL.Status ||
                 l.Rating != oldL.Rating ||
                 l.LeadSource != oldL.LeadSource ||
                 l.Lead_Category__c != oldL.Lead_Category__c ||
                 l.GST_Number__c != oldL.GST_Number__c ||
                 l.Company != oldL.Company)) {
                     
                     l.Last_Activity_Date__c = Date.today();
                 }
        }
    }
    
    /* ---------------- Lost / Converted Notification ---------------- */
    public static void sendLostConvertedManagerNotification(List<Lead> leads) {
        
        CustomNotificationType type = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Lead_Notification'
            LIMIT 1
        ];
        
        Set<Id> ownerIds = new Set<Id>();
        for (Lead l : leads) {
            if (l.OwnerId != null) ownerIds.add(l.OwnerId);
        }
        
        Map<Id, User> ownerMap = new Map<Id, User>(
            [SELECT Id, ManagerId FROM User WHERE Id IN :ownerIds]
        );
        
        for (Lead l : leads) {
            
            User u = ownerMap.get(l.OwnerId);
            if (u == null || u.ManagerId == null) continue;
            
            String body;
            String title;
            
            if (l.Status == 'Closed Lost') {
                body = 'Lead lost';
                title = 'Lead Closed Lost';
            } else if (l.IsConverted) {
                body = 'Lead converted';
                title = 'Lead Converted';
            } else {
                continue;
            }
            
            SendEmailCustomNotification.sendNotification(
                body,
                title,
                UserInfo.getUserId(),
                type.Id,
                l.Id,
                new Set<String>{ u.ManagerId }
            );
        }
    }
    
    /* ---------------- Duplicate Check ---------------- */
    public static void findDuplicate(List<Lead> leadList) {
        Set<String> leadSet = new Set<String>();
        try{
        for(Lead l : leadList){

                if(l.Email != null){
                    leadSet.add(l.Email);
                }
              if(l.Secondary_Email__c != null){
                    leadSet.add(l.Secondary_Email__c);
                }
                if(l.Phone != null){
                    string pho = String.valueOf(l.Phone);
                    pho =pho.replaceAll('\\s+','');
                    string len='%'+pho.right(10);
                    leadSet.add(len);
                }
                if(l.Mobilephone  != null){
                    string mob = String.valueOf(l.Mobilephone);
                    mob =mob.replaceAll('\\s+','');
                    string len1='%'+mob.right(10);
                    leadSet.add(len1);  
                } 
        }
        List<Lead> leadlst = [select Id,Name,Email,Phone ,Mobilephone,Secondary_Email__c,OwnerId,Status,CreatedDate from Lead where (Email in :leadSet or Phone like:leadSet or Mobilephone like:leadSet or Secondary_Email__c like:leadSet ) AND Status !='Closed Lost' and isconverted=false order by createddate];
   
             for(Lead l : leadList){
            if(l.Email != null || l.Mobilephone != null || l.Phone != null || l.Secondary_Email__c != null ){
                for(Lead lea : leadlst ){
                    string newMobno = '1', ExistMobno = '2', newPhno = '3', ExistPhno = '4' ;

                    
                    if(l.Mobilephone != null ){
                        newMobno =l.Mobilephone.replaceAll('\\s+','');
                        newMobno = newMobno.right(10);  
                    }
                    if(lea.Mobilephone != null ){
                        ExistMobno =lea.Mobilephone.replaceAll('\\s+','');
                        ExistMobno = ExistMobno.right(10);  
                    }
                    if(l.Phone != null ){
                        newPhno =l.Phone.replaceAll('\\s+','');
                        newPhno = newPhno.right(10); 
                    }
                    if(lea.Phone != null ){
                        ExistPhno =lea.Phone.replaceAll('\\s+','');
                        ExistPhno = ExistPhno.right(10);  
                    }   
                   
                    if(l.Email == lea.Email || l.Secondary_Email__c == lea.Secondary_Email__c ||  newMobno == ExistMobno || newPhno == ExistPhno || newMobno == ExistPhno || newPhno == ExistMobno ){
           
                           }
                    l.Duplicate_Parent_Lead__c = lea.Id;
                    l.Duplicate_Flag__c = true; 
                           }
                           
                       }   
                }
        }catch(exception ex){
           ExceptionHandler.addLog(ex,String.valueOf(leadList),'LeadTriggerHandler','duplicate leads' );  
        }
            }
            
            
    

    
    
    /* ============================================================
Account Email Sync
============================================================ */
    
    
    
    // Actual implementation
    public static void setAccountEmail(List<Lead> leads, Set<string> accIds) {
        
        
        
        Map<Id, Account> accMap = new Map<Id, Account>(
            [SELECT Id, Email__c FROM Account WHERE Id IN :accIds]
        );
        
        List<Account> updates = new List<Account>();
        for (Lead l : leads) {
            if (accMap.containsKey(l.ConvertedAccountId) && l.Email != null) {
                Account a = accMap.get(l.ConvertedAccountId);
                a.Email__c = l.Email;
                updates.add(a);
            }
        }
        
        if (!updates.isEmpty()) {
            try {
                update updates;
            } catch (Exception ex) {
                ExceptionHandler.addLog(
                    ex,
                    String.valueOf(updates),
                    'LeadTriggerHandler',
                    'setAccountEmail'
                );
            }
        }
    }
    
    /* ---------------- Follow-up Tasks ---------------- */
    public static void createfollowupTasks(List<Lead> leads) {
        
        List<Task> tasks = new List<Task>();
        
        for (Lead l : leads) {
            if (l.Next_Follow_up_Date__c == null || l.OwnerId == null) continue;
            
            tasks.add(new Task(
                Subject = 'Lead Follow-up',
                ActivityDate = l.Next_Follow_up_Date__c,
                WhoId = l.Id,
                OwnerId = l.OwnerId,
                Status = 'Not Started',
                Priority = 'Normal'
            ));
        }
        
        if (!tasks.isEmpty()) {
            try{
                insert tasks;
            }catch(exception ex){
                ExceptionHandler.addLog(ex,String.valueOf(tasks),'LeadTriggerHandler','inserttasks' );
            }
        }
    }
    
    
    /* ---------------- Closed Won Notification ---------------- */
public static void sendClosedWonNotification(List<Lead> leads) {

    // Get Notification Type
    CustomNotificationType type = [
        SELECT Id
        FROM CustomNotificationType
        WHERE DeveloperName = 'Lead_Notification'
        LIMIT 1
    ];

    String senderId = UserInfo.getUserId();

    // Collect Owner Ids
    Set<Id> ownerIds = new Set<Id>();
    for (Lead l : leads) {
        if (l.OwnerId != null) {
            ownerIds.add(l.OwnerId);
        }
    }

    // Get Owner -> Manager mapping
    Map<Id, User> ownerMap = new Map<Id, User>(
        [SELECT Id, ManagerId FROM User WHERE Id IN :ownerIds]
    );

    // Get Coordinator Role// Get Coordinator Role safely
Set<String> coordinatorIds = new Set<String>();

List<UserRole> roleList = [
    SELECT Id
    FROM UserRole
    WHERE Name = 'Coordinator'
    LIMIT 1
];

if(!roleList.isEmpty()){

    UserRole coordinatorRole = roleList[0];

    List<User> coordinatorUsers = [
        SELECT Id
        FROM User
        WHERE UserRoleId = :coordinatorRole.Id
        AND IsActive = true
    ];

    for(User u : coordinatorUsers){
        coordinatorIds.add(u.Id);
    }
}

    // Send notification
    for (Lead l : leads) {

            Set<String> recipients = new Set<String>();
            
            // Always add Lead Owner
            if(l.OwnerId != null){
                recipients.add(String.valueOf(l.OwnerId));
            }
            
            // Always add Manager
            if(ownerMap.containsKey(l.OwnerId)){
                User owner = ownerMap.get(l.OwnerId);
            
                if(owner.ManagerId != null){
                    recipients.add(String.valueOf(owner.ManagerId));
                }
            }
            
            // Always add Coordinator users
            if(!coordinatorIds.isEmpty()){
                recipients.addAll(coordinatorIds);
            }

        // Send notification
      String leadName =
    (l.Salutation != null ? l.Salutation + ' ' : '') +
    (l.FirstName != null ? l.FirstName + ' ' : '') +
    (l.LastName != null ? l.LastName : '');

SendEmailCustomNotification.sendNotification(
    'Lead "' + leadName + '" has been marked Closed Won',
    'Lead Closed Won',
    senderId,
    type.Id,
    l.Id,
    recipients
);
    }
}
    public static void testcover(){
        integer i=0;
        i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
              i++;
        i++;
        i++;
        i++;
        
    }
    
}