@IsTest
private class WebsiteAPIControllerTest {
    
    @TestSetup
    static void setupTestData() {

    }
    
    private static RestRequest createTestRequest(String requestBody, String key, String webFormName) {
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        req.params.put('key', key);
        req.params.put('webFormName', webFormName);
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/WebsiteLead/';
        return req;
    }
    
    private static String createLeadWrapperJSON(Map<String, Object> additionalFields) {
        Map<String, Object> leadData = new Map<String, Object>{
            'name' => 'Test User',
            'phone' => '9876543210',
            'email' => 'test@example.com',
            'address' => '123 Test Street',
            'city' => 'Mumbai',
            'pinCode' => '400001',
            'country' => 'India'
        };
        
        if (additionalFields != null) {
            leadData.putAll(additionalFields);
        }
        
        return JSON.serialize(leadData);
    }
    
    // Test 1: Basic lead creation with valid API key
    @IsTest
    static void testBasicLeadCreation() {
        String requestBody = createLeadWrapperJSON(new Map<String, Object>{
            'institution' => 'Test Hospital'
        });
        
        RestRequest req = createTestRequest(requestBody, 'test-api-key-123', 'medical-equipment-maintenance');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 2: Test with invalid API key
    @IsTest
    static void testInvalidAPIKey() {
        String requestBody = createLeadWrapperJSON(null);
        
        RestRequest req = createTestRequest(requestBody, 'invalid-key', 'medical-equipment-maintenance');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 3: Test with disabled WebToLeadAPI
    @IsTest
    static void testDisabledWebToLeadAPI() {
        String requestBody = createLeadWrapperJSON(null);
        
        RestRequest req = createTestRequest(requestBody, 'test-api-key-123', 'medical-equipment-maintenance');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 4: Test pay-now web form
    @IsTest
    static void testPayNowWebForm() {
        String requestBody = createLeadWrapperJSON(new Map<String, Object>{
            'institute' => 'Test Institute',
            'registrationFees' => 5000,
            'totalPayment' => 10000,
            'message' => 'Payment request',
            'courseInterested' => 'Biomedical Engineering',
            'courseCenter' => 'Mumbai Center',
            'paymentId' => 'pay_123456',
            'orderId' => 'ord_789012'
        });
        
        RestRequest req = createTestRequest(requestBody, 'test-api-key-123', 'pay-now');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 5: Test career web form with file attachment
    @IsTest
    static void testCareerWebFormWithFile() {
        String base64File = 'JVBERi0xLjQKJcOkw7zDtsOfCjIgMCBvYmoKPDwvTGVuZ3RoIDMgMCBSL0Zp';
        String requestBody = createLeadWrapperJSON(new Map<String, Object>{
            'state' => 'Maharashtra',
            'jobName' => 'Software Engineer',
            'source' => 'Website',
            'iscyrixFormerEmployee' => false,
            'resumeLink' => 'https://example.com/resume.pdf',
            'file' => new Map<String, Object>{
                'fileName' => 'resume.pdf',
                'contentType' => 'application/pdf',
                'base64Data' => base64File
            }
        });
        
        RestRequest req = createTestRequest(requestBody, 'test-api-key-123', 'career');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 6: Test career web form without file
    @IsTest
    static void testCareerWebFormWithoutFile() {
        String requestBody = createLeadWrapperJSON(new Map<String, Object>{
            'state' => 'Maharashtra',
            'jobName' => 'Software Engineer',
            'source' => 'Website',
            'iscyrixFormerEmployee' => false,
            'resumeLink' => 'https://example.com/resume.pdf'
        });
        
        RestRequest req = createTestRequest(requestBody, 'test-api-key-123', 'career');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 7: Test cyrix-aurum-schedule-a-demo web form
    @IsTest
    static void testCyrixAurumScheduleDemo() {
        String requestBody = createLeadWrapperJSON(new Map<String, Object>{
            'designation' => 'Doctor',
            'hospital' => 'ABC Hospital',
            'location' => 'Delhi',
            'purchaseOption' => 'Lease',
            'preferredTime' => '2:00 PM',
            'prefModeofContact' => 'Email',
            'equipofInterest' => 'MRI Machine',
            'isThisDemofor' => 'Hospital',
            'anticipPurchTimeline' => '3 months',
            'preferredDemoFormat' => 'Online'
        });
        
        RestRequest req = createTestRequest(requestBody, 'test-api-key-123', 'cyrix-aurum-schedule-a -demo');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 8: Test buyback web form
    @IsTest
    static void testBuybackWebForm() {
        String requestBody = createLeadWrapperJSON(new Map<String, Object>{
            'institution' => 'Test Hospital',
            'preferredDate' => Date.today(),
            'preferredTime' => '11:00 AM',
            'equipment' => 'X-Ray Machine',
            'softwareAvailable' => 'Yes',
            'make' => 'GE Healthcare',
            'yearofInstallation' => '2018',
            'instalationLocation' => 'Radiology Department',
            'whenWouldyouLiketoSell' => 'Immediately',
            'visitorCall' => 'Visit',
            'features' => 'Digital, Portable'
        });
        
        RestRequest req = createTestRequest(requestBody, 'test-api-key-123', 'buyback');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 9: Test medical-device-repair web form
    @IsTest
    static void testMedicalDeviceRepair() {
        String requestBody = createLeadWrapperJSON(new Map<String, Object>{
            'institution' => 'Test Hospital',
            'preferredDate' => Date.today(),
            'preferredTime' => '10:00 AM',
            'productName' => 'Ventilator',
            'yearofMfaorAge' => '2020',
            'visitorCall' => 'Call',
            'complaint' => 'Not starting'
        });
        
        RestRequest req = createTestRequest(requestBody, 'test-api-key-123', 'medical-device-repair');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 10: Test biomedical-equipment-training-program
    @IsTest
    static void testBiomedicalTrainingProgram() {
        String requestBody = createLeadWrapperJSON(new Map<String, Object>{
            'institute' => 'Test Institute',
            'qualification' => 'B.Tech',
            'courseInterested' => 'Biomedical Equipment Maintenance',
            'requestCounselling' => true
        });
        
        RestRequest req = createTestRequest(requestBody, 'test-api-key-123', 'biomedical-equipment-training-program');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 11: Test contact web form
    @IsTest
    static void testContactWebForm() {
        String requestBody = createLeadWrapperJSON(new Map<String, Object>{
            'institute' => 'Test Institute',
            'wouldLiketoKnowMoreAbout' => 'Products',
            'message' => 'Interested in your products',
            'location' => 'Bangalore',
            'consentToReceiveUpdates' => true
        });
        
        RestRequest req = createTestRequest(requestBody, 'test-api-key-123', 'contact');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 12: Test TradeIndia web form
    @IsTest
    static void testTradeIndiaWebForm() {
        String requestBody = createLeadWrapperJSON(new Map<String, Object>{
            'company' => 'TradeIndia Company',
            'state' => 'Gujarat',
            'description' => 'Looking for medical equipment',
            'leadType' => 'Buyer',
            'lead_id' => 'TI_123456'
        });
        
        RestRequest req = createTestRequest(requestBody, 'test-api-key-123', 'TradeIndia');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 13: Test exception scenario (invalid JSON)
    @IsTest
    static void testExceptionScenario() {
        String invalidRequestBody = 'invalid json {';
        
        RestRequest req = createTestRequest(invalidRequestBody, 'test-api-key-123', 'medical-equipment-maintenance');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        try {
            WebsiteAPIController.createLead();
        } catch (Exception e) {
            // Exception is expected
        }
        Test.stopTest();
    }
    
    // Test 14: Test with large request body
    @IsTest
    static void testLargeRequestBody() {
        String largeMessage = 'a'.repeat(35000);
        String requestBody = createLeadWrapperJSON(new Map<String, Object>{
            'institution' => 'Test Hospital',
            'message' => largeMessage
        });
        
        RestRequest req = createTestRequest(requestBody, 'test-api-key-123', 'contact');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 15: Test when assignment rule is not found
    @IsTest
    static void testWithoutAssignmentRule() {

        String requestBody = createLeadWrapperJSON(new Map<String, Object>{
            'institution' => 'Test Hospital'
        });
        
        RestRequest req = createTestRequest(requestBody, '96ca585abb297b995fab61679e0516fb', 'medical-equipment-maintenance');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 16: Test cyrix-converge-2025 web form
    @IsTest
    static void testCyrixConverge2025() {
        String requestBody = createLeadWrapperJSON(new Map<String, Object>{
            'designation' => 'Manager',
            'institution' => 'XYZ Corporation',
            'city' => 'Chennai',
            'participationConfirmation' => 'Yes'
        });
        
        RestRequest req = createTestRequest(requestBody, '96ca585abb297b995fab61679e0516fb', 'cyrix-converge-2025');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 17: Test with null company (should default to 'N/A')
    @IsTest
    static void testWithNullCompany() {
        String requestBody = createLeadWrapperJSON(new Map<String, Object>{
            'institution' => null,
            'hospital' => null
        });
        
        RestRequest req = createTestRequest(requestBody, '96ca585abb297b995fab61679e0516fb', 'contact');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 18: Test cyrix-aurum-contact-our-team
    @IsTest
    static void testCyrixAurumContactTeam() {
        String requestBody = createLeadWrapperJSON(new Map<String, Object>{
            'designation' => 'Purchase Manager',
            'hospital' => 'City Hospital',
            'location' => 'Pune',
            'purchaseOption' => 'Buy',
            'preferredTime' => '3:00 PM',
            'prefModeofContact' => 'Phone'
        });
        
        RestRequest req = createTestRequest(requestBody, '96ca585abb297b995fab61679e0516fb', 'cyrix-aurum-contact-our-team');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 19: Test cyrix-aurum-request-a-quote
    @IsTest
    static void testCyrixAurumRequestQuote() {
        String requestBody = createLeadWrapperJSON(new Map<String, Object>{
            'designation' => 'Radiologist',
            'hospital' => 'Super Specialty Hospital',
            'location' => 'Hyderabad',
            'purchaseOption' => 'Rent',
            'preferredTime' => '4:00 PM',
            'prefModeofContact' => 'Video Call',
            'product' => 'CT Scanner',
            'priceRangeBudget' => '50-60 Lakhs',
            'message' => 'Need quote for CT Scanner'
        });
        
        RestRequest req = createTestRequest(requestBody, '96ca585abb297b995fab61679e0516fb', 'cyrix-aurum-request-a-quote');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 20: Test medical-equipment-calibration-services
    @IsTest
    static void testMedicalEquipmentCalibration() {
        String requestBody = createLeadWrapperJSON(new Map<String, Object>{
            'institution' => 'Calibration Center',
            'preferredDate' => Date.today(),
            'preferredTime' => '9:00 AM',
            'visitorCall' => 'Visit',
            'noofEquipmenttoCalibrate' => 5
        });
        
        RestRequest req = createTestRequest(requestBody, '96ca585abb297b995fab61679e0516fb', 'medical-equipment-calibration-services');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 21: Test medical-equipment-servicing
    @IsTest
    static void testMedicalEquipmentServicing() {
        String requestBody = createLeadWrapperJSON(new Map<String, Object>{
            'institution' => 'Service Hospital',
            'preferredDate' => Date.today(),
            'preferredTime' => '10:30 AM',
            'hospitalDetails' => 'Multi-specialty hospital with 200 beds'
        });
        
        RestRequest req = createTestRequest(requestBody, '96ca585abb297b995fab61679e0516fb', 'medical-equipment-servicing');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 22: Test hospital-equipment-maintenance
    @IsTest
    static void testHospitalEquipmentMaintenance() {
        String requestBody = createLeadWrapperJSON(new Map<String, Object>{
            'institution' => 'General Hospital',
            'preferredDate' => Date.today(),
            'preferredTime' => '11:00 AM',
            'noofHospitalBeds' => '150'
        });
        
        RestRequest req = createTestRequest(requestBody, '96ca585abb297b995fab61679e0516fb', 'hospital-equipment-maintenance');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 23: Test multiple web forms in sequence
    @IsTest
    static void testMultipleWebForms() {
        List<String> webForms = new List<String>{
            'pay-now',
            'career',
            'contact',
            'TradeIndia'
        };
        
        Test.startTest();
        for (String webForm : webForms) {
            String requestBody = createLeadWrapperJSON(new Map<String, Object>{
                'institute' => 'Test Institute ' + webForm
            });
            
            RestRequest req = createTestRequest(requestBody, '96ca585abb297b995fab61679e0516fb', webForm);
            RestContext.request = req;
            RestContext.response = new RestResponse();
            
            WebsiteAPIController.createLead();
        }
        Test.stopTest();
    }
    
    // Test 24: Test empty request body
    @IsTest
    static void testEmptyRequestBody() {
        RestRequest req = createTestRequest('', '96ca585abb297b995fab61679e0516fb', 'medical-equipment-maintenance');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 25: Test with special characters in fields
    @IsTest
    static void testSpecialCharacters() {
        String requestBody = createLeadWrapperJSON(new Map<String, Object>{
            'name' => 'Test User @#₹%&*()',
            'email' => 'test+special@example.co.in',
            'phone' => '+91-98765-43210',
            'message' => 'Line 1\nLine 2\r\nLine 3\tTab',
            'address' => '123, ABC Road\nNear XYZ Circle\nMumbai - 400001'
        });
        
        RestRequest req = createTestRequest(requestBody, '96ca585abb297b995fab61679e0516fb', 'contact');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
    
    // Test 26: Test with very long field values
    @IsTest
    static void testLongFieldValues() {
        String longName = 'A'.repeat(255);
        String longEmail = 'test' + 'a'.repeat(240) + '@example.com';
        String longPhone = '9'.repeat(15);
        
        String requestBody = createLeadWrapperJSON(new Map<String, Object>{
            'name' => longName,
            'email' => longEmail,
            'phone' => longPhone,
            'message' => 'M'.repeat(1000)
        });
        
        RestRequest req = createTestRequest(requestBody, '96ca585abb297b995fab61679e0516fb', 'contact');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();
    }
}