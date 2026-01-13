/****************************************************************
* Class Name   : WebsiteAPIController
* Company      : Fingertipplus
* Created Date : 07-11-2025
* @description : This class is used for Integration with website for Capturing the Lead into Salesforce 
* @author      : Mayuri Patel

* Change Log:
* -----------------------------------------------------------------------------
* Ver | Author 			| 	  Date 		| Description
* -----------------------------------------------------------------------------
* 1.0 | Mayuri Patel 	| 07-11-2025 	| Initial version
* 2.0 | Nanma	        | 18-11-2025 	| Initial version
* -----------------------------------------------------------------------------
**************************************************************/
@RestResource(urlMapping='/WebsiteLead/*')
global without sharing class WebsiteAPIController {
    @HttpPost
    global static void createLead() {
        Integer maxSize = 32000;
        
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestBody = req.requestBody.toString(); // Get the JSON body
        String key = RestContext.request.params.get('key');
        String webFormName = RestContext.request.params.get('webFormName');
        Log__c log = new Log__c();
        string fileuploadStatus='';
         string fileId='';
        if(requestBody.length() > maxSize ){
            log.Request__c = requestBody.substring(0, maxSize);
        }else{
            log.Request__c = requestBody;
        }
        if(Label.API_Key == key && label.Enable_WebToLeadAPI =='TRUE'){
   
            try {
                leadWrapper leaddData = (leadWrapper) JSON.deserialize(requestBody, leadWrapper.class); // Deserialize the JSON body into the callWrapper class
                // Create a new Lead using the deserialized data
                log.Object__c ='WebsiteAPIController '+webFormName;
                Lead ld = new Lead();
                ld.LastName = leaddData.name;
                ld.Phone = leaddData.phone;
                ld.Email = leaddData.email;
                ld.LeadSource='Web To Lead	';
                ld.Web_Form_Name__c =webFormName;
                if(webFormName =='pay-now' ||webFormName =='medical-equipment-maintenance' || webFormName =='buyback' || webFormName =='medical-device-repair' || webFormName =='medical-equipment-calibration-services' || webFormName =='hospital-equipment-maintenance' || webFormName =='medical-equipment-servicing' || webFormName =='career'|| webFormName =='TradeIndia'){
                    ld.Address__c = leaddData.address;
                    ld.Location__c = leaddData.city;
                    ld.Pin_Code__c =leaddData.pinCode;
                    ld.webLead_country__c =leaddData.country;
                }
                
                if(webFormName =='cyrix-aurum-schedule-a -demo'|| webFormName =='cyrix-aurum-contact-our-team' || webFormName =='cyrix-aurum-request-a-quote'){
                    ld.Designation__c= leaddData.designation;
                    ld.Company =leaddData.hospital; 
                    ld.Location__c = leaddData.location;
                    ld.Purchase__c = leaddData.purchaseOption;
                    ld.Preferred_Time__c= leaddData.preferredTime;
                    ld.Preferred_Mode_of_Contact__c= leaddData.prefModeofContact;
                    if(webFormName =='cyrix-aurum-schedule-a -demo'){
                        ld.ARURM_Request_Type__c='Schedule a Demo';
                    }else if(webFormName =='cyrix-aurum-contact-our-team'){
                          ld.ARURM_Request_Type__c='Contact Our Team';
                    }else{
                          ld.ARURM_Request_Type__c='Request a Quote';
                    }
                }
                
                if(webFormName =='medical-equipment-maintenance' || webFormName =='buyback' || webFormName =='medical-device-repair' || webFormName =='medical-equipment-calibration-services' ||webFormName =='hospital-equipment-maintenance' || webFormName =='medical-equipment-servicing'){
                    ld.Company =leaddData.institution; 
                    ld.Preferred_Date__c =string.valueof(leaddData.preferredDate);
                    ld.Preferred_Time__c =string.valueof(leaddData.preferredTime);
                }
                
                if(webFormName =='pay-now'){
                    ld.Registration_Fees__c = leaddData.registrationFees;
                    ld.Total_Payment__c = leaddData.totalPayment;
                    ld.Message__c =leaddData.message;
                    ld.course_Interested__c =leaddData.courseInterested;
                    ld.Course_Center__c =leaddData.courseCenter;
                    ld.Payment_Id__c=leaddData.paymentId;
                    ld.Order_Id__c=leaddData.orderId;
                }else if(webFormName =='medical-equipment-maintenance' || webFormName =='hospital-equipment-maintenance'){
                    ld.Number_of_Hospital_Beds__c =leaddData.noofHospitalBeds;
                }else if(webFormName =='buyback'){
                    ld.Equipment_Details__c =leaddData.equipment;
                    ld.Software_available__c=leaddData.softwareAvailable;
                    ld.Make__c =leaddData.make;
                    ld.Year_of_Installation__c=leaddData.yearofInstallation;
                    ld.Installation_location__c=leaddData.instalationLocation;
                    ld.When_would_you_like_to_sell__c=leaddData.whenWouldyouLiketoSell;
                    ld.BuyBack_Visit_Call__c=leaddData.visitorCall;
                    ld.Features__c=leaddData.features;
                }else if(webFormName =='cyrix-aurum-schedule-a -demo'){
                   
                    ld.Equipment_of_Interest__c= leaddData.equipofInterest;
                    ld.Is_this_demo_for__c= leaddData.isThisDemofor;
                    ld.Anticipated_Purchase_Timeline__c= leaddData.anticipPurchTimeline;
                    ld.Preferred_Demo_Format__c= leaddData.preferredDemoFormat;
                }else if(webFormName =='cyrix-aurum-request-a-quote') {
                    ld.ARURM_Product__c = leaddData.product;  
                    ld.Price_Range_Budget__c = leaddData.priceRangeBudget;
                      ld.ARURM_Message__c = leaddData.message; 
                } else if(webFormName =='medical-device-repair'){
                    ld.Product_Name__c = leaddData.productName;
                    ld.Year_of_Manufacture_Age__c= leaddData.yearofMfaorAge;
                    ld.Requested_Service_Type__c= leaddData.visitorCall;
                    ld.Complaint__c= leaddData.complaint;
                }else if(webFormName =='medical-equipment-calibration-services'){
                    ld.Requested_Service_Type__c= leaddData.visitorCall;
                    //  ld.Service_Engineer_Visit_Call__c= leaddData.visitorCall;
                    ld.Number_of_Equipment_to_Calibrate__c =leaddData.noofEquipmenttoCalibrate;
                }else if(webFormName =='medical-equipment-servicing'){
                    ld.Hospital_Details__c =leaddData.hospitalDetails;
                }else if(webFormName =='biomedical-equipment-training-program'){
                    ld.Qualification__c =leaddData.qualification;
                    ld.course_Interested__c =leaddData.courseInterested;
                    ld.Request_Counselling__c =leaddData.requestCounselling;
                } if(webFormName =='career'){
                    ld.Webform_State__c =leaddData.state;
                    ld.Job_Name__c =leaddData.jobName;
                    ld.Sub_Source__c =leaddData.source;
                    ld.CYRIX_Former_Employee__c =leaddData.iscyrixFormerEmployee;
                    ld.Resume_Link_Social_Media__c =leaddData.resumeLink;
                }else if(webFormName =='cyrix-converge-2025'){
                    ld.Designation__c= leaddData.designation;
                    ld.Company =leaddData.institution; 
                    ld.Location__c = leaddData.city;
                    ld.Participation_Confirmation__c=leaddData.participationConfirmation;
                }else if(webFormName =='contact'){
                    ld.would_like_to_know_more_about__c= leaddData.wouldLiketoKnowMoreAbout;
                    ld.Message__c= leaddData.message;
                    ld.Location__c= leaddData.location;
                    ld.Consent_to_Receive_Updates__c= leaddData.consentToReceiveUpdates;
                }else if(webFormName =='TradeIndia'){
                    ld.Webform_State__c =leaddData.state;
                    ld.Description = leaddData.description;
                    ld.Lead_Type__c=leaddData.leadType;
                    ld.company =leaddData.company;
                    ld.Trade_India_Lead_Id__c =leaddData.lead_id;
                }
                
                if(ld.Company ==null){
                    ld.Company='N/A';
                }

                list<AssignmentRule> leadAR = [  SELECT Id  FROM AssignmentRule   WHERE SobjectType = 'Lead'   AND Active = true and Name='Telecaller Lead Assignment' LIMIT 1 ];//Fetch the active Lead Assignment Rule (if you want a specific rule, filter by Name)
                if(!leadAR.isEmpty()){
                    Database.DMLOptions dmlOpts = new Database.DMLOptions();
                    dmlOpts.assignmentRuleHeader.assignmentRuleId = leadAR[0].Id; // leadassignment ruleId
                    Database.SaveResult sr = Database.insert(ld, dmlOpts);
                    if (sr.isSuccess()) {
                        ld.Id = sr.getId(); // so your response JSON still has ld.Id
                    } else {
                        Database.Error err = sr.getErrors()[0];
                        Error_Log__c erro = new Error_Log__c();
                        erro.className__c ='WebsiteAPIController';
                        erro.Message__c = err.getMessage()+' '+ err.getFields();
                        erro.User__c = UserInfo.getUserId();
                        database.insert(erro,false);  
                        insert ld;
                    }
                }else{ insert ld;}    
                
                if(webFormName =='career'){  
                    if (leaddData.file != null && !String.isBlank(leaddData.file.base64Data)) {
                        try {
                            Blob fileBody = EncodingUtil.base64Decode(leaddData.file.base64Data);
                            String fileName = String.isBlank(leaddData.file.fileName) ? 'Resume_Attachment.pdf': leaddData.file.fileName;
                            
                            // Use Files (ContentVersion) instead of old Attachment
                                ContentVersion cv = new ContentVersion(
                                Title = (fileName.length() > 80 ? fileName.substring(0, 80) : fileName),
                                PathOnClient = fileName,
                                VersionData = fileBody,
                                FirstPublishLocationId = ld.Id
                            );
                            insert cv;
                            fileuploadStatus='Success';
                            fileId =cv.Id;
                        } catch (Exception e) {
                             fileuploadStatus='Failure';
                            fileId ='';
                        }
                    }
                
                }
                
                
                
                res.statusCode = 200;
                res.addHeader('Content-Type', 'application/json');
                 if(webFormName =='career'){  
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                    'success'=>true , 'Salesforce LeadId' => ld.Id ,'file' => fileuploadStatus,'fileId' => fileId}));
                 }else{
                   res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                    'success'=>true , 'Salesforce LeadId' => ld.Id }));  
                 }
                log.Status_Code__c ='200';
                log.Status_Message__c='Success';
            } catch (Exception ex) {
                res.statusCode = 400;
                res.addHeader('Content-Type', 'application/json');
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                    'success'=> false ,'Error'=> ex.getMessage() }));
                log.Status_Code__c ='400';
                log.Status_Message__c='Failed';
            }
            
        }else{
            res.statusCode = 400;
            res.addHeader('Content-Type', 'application/json');
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success'=> false ,'Authorisation error'=> 'Invalid Key.'}));
            log.Status_Code__c ='400';
            log.Status_Message__c='Failed';
        }
        log.Response__c = res.responseBody.tostring() ; 
        insert log;
    }
    
    // Wrapper class for deserialization
    public class leadWrapper {
        
        public String name;
        public String source;
        public String phone;
        public String email;
        public String designation;
        public String institution;
        public String hospital;
        public String company;
        public String message;
        public String campaign;
        public String campaignId;
        public String campaignName;
        public String description;
        public String leadType;
        public boolean consentToReceiveUpdates;
        public String participationConfirmation;
        public String jobName;
        public String address;
        public String city;
        public String lead_id;
         public String orderId;
         public String paymentId;
        public String location;
        public String state;
        public String country;
        public date preferredDate;
        public string preferredTime;
        public String pinCode;
        public boolean iscyrixFormerEmployee;
        public boolean requestCounselling;
        public string noofHospitalBeds;
        public string hospitalDetails;
        public integer noofEquipmenttoCalibrate;
        public String resumeLink;
        public String productName;
        public String yearofMfaorAge;
        public String qualification;
        public String courseInterested;
        public String visitorCall;
        public string purchaseOption;
        public string prefModeofContact;
        public string equipofInterest;
        public string isThisDemofor;
        public string anticipPurchTimeline;
        public string preferredDemoFormat;
        public String wouldLiketoKnowMoreAbout;
        public string equipment;
        public string softwareAvailable;
        public  string features;
        public  string complaint;
        public string make;
        public string whenWouldyouLiketoSell;
        public string yearofInstallation;
        public string courseCenter;
        public string instalationLocation;
        public decimal registrationFees;
        public decimal totalPayment;
         public string product;
         public string priceRangeBudget;
         public FileInfo file; // optional
    }
        global class FileInfo {
        public String fileName;
        public String contentType;
        public String base64Data;
    }
    
}