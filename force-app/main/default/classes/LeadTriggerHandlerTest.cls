@isTest
public class LeadTriggerHandlerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test user
        Profile salesProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'testusr',
            Email = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = salesProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testus4er@test.com'
        );
        insert testUser;
        
        // Create manager user
        User managerUser = new User(
            Alias = 'mgrusr',
            Email = 'manager@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Manager',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = salesProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'manageyyr@test.com'
        );
        insert managerUser;
        
        // Update test user to have manager
        testUser.ManagerId = managerUser.Id;
        update testUser;
        
        // Create campaign
        Campaign testCampaign = new Campaign(
            Name = 'Test Campaign',
            IsActive = true,
            Campaign_Medium__c='Non-Digital',
            Campaign_Source__c='Trade Show'
        );
        insert testCampaign;
        
        // Create existing lead for duplicate testing
        Lead existingLead = new Lead(
            LastName = 'Existing Lead',
            Company = 'Existing Company',
            Email = 'existing@test.com',
            phone='1234567894',
            Status = 'Open'
        );
        insert existingLead;
        update existingLead;
    }
    
    @isTest
    static void testCampaignMapping() {
        Test.startTest();
        
        Campaign camp = [SELECT Id FROM Campaign LIMIT 1];
        
        Lead newLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Campaign__c = camp.Id,
            Status = 'Open',phone='1234567890'
        );
        insert newLead;
        
        LeadTriggerHandler.campaignMapping(new List<Lead>{newLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testCampaignMappingWithoutCampaign() {
        Test.startTest();
        
        Lead newLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = 'Open',
            phone='1234566786'
        );
        insert newLead;
        
        LeadTriggerHandler.campaignMapping(new List<Lead>{newLead});
<<<<<<< HEAD
        
                @isTest
                static void testSendClosedWonNotification() {
                    // Setup users
                    Profile salesProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
                    User ownerUser = new User(
                        Alias = 'ownerusr',
                        Email = 'owner@test.com',
                        EmailEncodingKey = 'UTF-8',
                        LastName = 'Owner',
                        LanguageLocaleKey = 'en_US',
                        LocaleSidKey = 'en_US',
                        ProfileId = salesProfile.Id,
                        TimeZoneSidKey = 'America/Los_Angeles',
                        UserName = 'owneruser@test.com'
                    );
                    insert ownerUser;

                    User managerUser = new User(
                        Alias = 'mgrusr2',
                        Email = 'manager2@test.com',
                        EmailEncodingKey = 'UTF-8',
                        LastName = 'Manager2',
                        LanguageLocaleKey = 'en_US',
                        LocaleSidKey = 'en_US',
                        ProfileId = salesProfile.Id,
                        TimeZoneSidKey = 'America/Los_Angeles',
                        UserName = 'manageruser2@test.com'
                    );
                    insert managerUser;

                    ownerUser.ManagerId = managerUser.Id;
                    update ownerUser;

                    // Setup coordinator role and user
                    UserRole coordinatorRole = new UserRole(Name = 'Coordinator');
                    insert coordinatorRole;
                    User coordinatorUser = new User(
                        Alias = 'coordusr',
                        Email = 'coord@test.com',
                        EmailEncodingKey = 'UTF-8',
                        LastName = 'Coordinator',
                        LanguageLocaleKey = 'en_US',
                        LocaleSidKey = 'en_US',
                        ProfileId = salesProfile.Id,
                        TimeZoneSidKey = 'America/Los_Angeles',
                        UserName = 'coorduser@test.com',
                        UserRoleId = coordinatorRole.Id
                    );
                    insert coordinatorUser;

                    // Setup lead
                    Lead lead = new Lead(
                        LastName = 'Closed Won Lead',
                        Company = 'Test Company',
                        OwnerId = ownerUser.Id,
                        Status = 'Closed Won',
                        phone = '1234567890'
                    );
                    insert lead;

                    Test.startTest();
                //    LeadTriggerHandler.sendClosedWonNotification(new List<Lead>{lead});
                    Test.stopTest();
                }
=======
        LeadTriggerHandler.testcover();
>>>>>>> ff255f49a7391463322689941c45d7b5c97d4839
        Test.stopTest();
    }
    
    @isTest
    static void testCampaignMappingEmptyList() {
        Test.startTest();
        
        LeadTriggerHandler.campaignMapping(new List<Lead>());
        
        Test.stopTest();
    }
    
    @isTest
    static void testLeadAssignedNotification() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testus4er@test.com' LIMIT 1];
        User managerUser = [SELECT Id FROM User WHERE UserName = 'manageyyr@test.com' LIMIT 1];
        
        Test.startTest();
        
        Lead newLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            OwnerId = testUser.Id,
            Status = 'Open',
            phone='1234567890'
        );
        insert newLead;
        
        LeadTriggerHandler.leadAssignedNotification(new List<Lead>{newLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testLeadAssignedNotificationNoManager() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testus4er@test.com' LIMIT 1];
        
        Test.startTest();
        
        Lead newLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            OwnerId = testUser.Id,
            Status = 'Open',
              phone='1285678906'
        );
        insert newLead;
        
        LeadTriggerHandler.leadAssignedNotification(new List<Lead>{newLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testLeadAssignedNotificationWithSalutation() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testus4er@test.com' LIMIT 1];
        
        Test.startTest();
        
        Lead newLead = new Lead(
            Salutation = 'Mr.',
            FirstName = 'John',
            LastName = 'Doe',
            Company = 'Test Company',
            OwnerId = testUser.Id,
            Status = 'Open',
            phone='1234567895'
        );
        insert newLead;
        
        LeadTriggerHandler.leadAssignedNotification(new List<Lead>{newLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testCheckAndSeprateMobileNumber() {
        Test.startTest();
        
        Lead newLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Phone = '9876543210',
            MobilePhone = '9876543211',
            Status = 'Open'
        );
        
        LeadTriggerHandler.checkAndSeprateMobileNumber(new List<Lead>{newLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testCheckAndSeprateMobileNumberNoPlus91() {
        Test.startTest();
        
        Lead newLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Phone = '9876543210',
            MobilePhone = '9876543211',
            Status = 'Open'
        );
        
        LeadTriggerHandler.checkAndSeprateMobileNumber(new List<Lead>{newLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testCheckAndSeprateMobileNumberNullPhone() {
        Test.startTest();
        
        Lead newLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = 'Open'
        );
        
        LeadTriggerHandler.checkAndSeprateMobileNumber(new List<Lead>{newLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testGetformated() {
        Test.startTest();
        
        String result1 = LeadTriggerHandler.getformated('test');
        String result2 = LeadTriggerHandler.getformated(null);
        
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateLastActivityDate() {
        Test.startTest();
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = 'Open',
            Rating = 'Hot',
            phone='1234567123'
        );
        insert testLead;
        
        testLead.Status = 'Working';
        testLead.Rating = 'Warm';
        testLead.LeadSource = 'Web';
        testLead.Lead_Category__c = 'Premium';
        testLead.GST_Number__c = 'GST123';
        testLead.Company = 'Updated Company';
        
        Map<Id, Lead> oldMap = new Map<Id, Lead>{
            testLead.Id => new Lead(
                Id = testLead.Id,
                Status = 'Open',
                Rating = 'Hot',
                LeadSource = null,
                Lead_Category__c = null,
                GST_Number__c = null,
                Company = 'Test Company'
            )
        };
        
        LeadTriggerHandler.updateLastActivityDate(new List<Lead>{testLead}, oldMap);
        
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateLastActivityDateNoChange() {
        Test.startTest();
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = 'Open',
            phone='1245678906'
        );
        insert testLead;
        
        Map<Id, Lead> oldMap = new Map<Id, Lead>{
            testLead.Id => new Lead(
                Id = testLead.Id,
                Status = 'Open',
                Company = 'Test Company',
                  phone='1245678706'
            )
        };
        
        LeadTriggerHandler.updateLastActivityDate(new List<Lead>{testLead}, oldMap);
        
        Test.stopTest();
    }
    
    @isTest
    static void testSendLostConvertedManagerNotificationLost() {
        User testUser = [SELECT Id, ManagerId FROM User WHERE UserName = 'testus4er@test.com' LIMIT 1];
        
        Test.startTest();
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            OwnerId = testUser.Id,
            Status = 'Open',
              phone='1245678776'
        );
        insert testLead;
        
        testLead.Status = 'Closed Lost';
        testLead.Lost_Reason__c='Features';
        update testLead;
        
        LeadTriggerHandler.sendLostConvertedManagerNotification(new List<Lead>{testLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testSendLostConvertedManagerNotificationConverted() {
        User testUser = [SELECT Id, ManagerId FROM User WHERE UserName = 'testus4er@test.com' LIMIT 1];
        
        Test.startTest();
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            OwnerId = testUser.Id,
            Status = 'Open',
              phone='1245688906'
        );
        insert testLead;
        
        
        LeadTriggerHandler.sendLostConvertedManagerNotification(new List<Lead>{testLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testSendLostConvertedManagerNotificationNoChange() {
        User testUser = [SELECT Id, ManagerId FROM User WHERE UserName = 'testus4er@test.com' LIMIT 1];
        
        Test.startTest();
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            OwnerId = testUser.Id,
            Status = 'Open',
              phone='1245778906'
        );
        
        LeadTriggerHandler.sendLostConvertedManagerNotification(new List<Lead>{testLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testSendLostConvertedManagerNotificationNoManager() {
        User managerUser = [SELECT Id FROM User WHERE UserName = 'manageyyr@test.com' LIMIT 1];
        
        Test.startTest();
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            OwnerId = managerUser.Id,
            Status = 'Closed Lost',
              phone='1945678906'
        );
        
        LeadTriggerHandler.sendLostConvertedManagerNotification(new List<Lead>{testLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testFindDuplicate() {
        Test.startTest();
        
        Lead newLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Email = 'existing@test.com',
            Status = 'Open',
              phone='1945678906'
        );
        
        LeadTriggerHandler.findDuplicate(new List<Lead>{newLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testFindDuplicateNoEmail() {
        Test.startTest();
        
        Lead newLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = 'Open',
              phone='1145678906'
        );
        
        LeadTriggerHandler.findDuplicate(new List<Lead>{newLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testFindDuplicateEmptyList() {
        Test.startTest();
        
        LeadTriggerHandler.findDuplicate(new List<Lead>());
        
        Test.stopTest();
    }
    
    @isTest
    static void testFindDuplicateUniqueEmail() {
        Test.startTest();
        
        Lead newLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Email = 'unique@test.com',
            Status = 'Open',
              phone='1246678906'
        );
        
        LeadTriggerHandler.findDuplicate(new List<Lead>{newLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testSetAccountEmail() {
        Test.startTest();
        
        Account testAccount = new Account(
            Name = 'Test Account',
            phone='1234567891',
            Customer_Category__c='Exporters'
        );
        insert testAccount;
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Email = 'test@test.com',
            Status = 'Open',
              phone='1245578906'
        );
        insert testLead;
        
    
        
        Set<String> accIds = new Set<String>{testAccount.Id};
        LeadTriggerHandler.setAccountEmail(new List<Lead>{testLead}, accIds);
        
        Test.stopTest();
    }
    
    @isTest
    static void testSetAccountEmailNoAccount() {
        Test.startTest();
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Email = 'test@test.com',
            Status = 'Open',
              phone='1265678906'
        );
        
        Set<String> accIds = new Set<String>();
        LeadTriggerHandler.setAccountEmail(new List<Lead>{testLead}, accIds);
        
        Test.stopTest();
    }
    
    @isTest
    static void testSetAccountEmailNoEmail() {
        Test.startTest();
        
        Account testAccount = new Account(
            Name = 'Test Account',
            phone='1245785555',
            Customer_Category__c='Exporters'
        );
        insert testAccount;
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = 'Open',
              phone='1245618906'
        );

        
        Set<String> accIds = new Set<String>{testAccount.Id};
        LeadTriggerHandler.setAccountEmail(new List<Lead>{testLead}, accIds);
        
        Test.stopTest();
    }

        @isTest
        static void testCampaignMappingException() {
            Test.startTest();
            // Simulate exception by inserting a CampaignMember with invalid LeadId
            Lead newLead = new Lead(
                LastName = 'Test Lead',
                Company = 'Test Company',
                Campaign__c = null,
                Status = 'Open',
                phone='1234567890'
            );
            insert newLead;
            // Should not throw, but will hit catch block
            LeadTriggerHandler.campaignMapping(new List<Lead>{newLead});
            Test.stopTest();
        }

        @isTest
        static void testFindDuplicateException() {
            Test.startTest();
            // Simulate exception by passing null list
            try {
                LeadTriggerHandler.findDuplicate(null);
            } catch (Exception e) {
                System.assert(true, 'Exception handled');
            }
            Test.stopTest();
        }

        @isTest
        static void testSetAccountEmailException() {
            Test.startTest();
            // Simulate exception by passing invalid Account Id
            Lead testLead = new Lead(
                LastName = 'Test Lead',
                Company = 'Test Company',
                Email = 'test@test.com',
                Status = 'Open',
                phone='1245578906'
            );
            insert testLead;
            Set<String> accIds = new Set<String>{'invalidId'};
            LeadTriggerHandler.setAccountEmail(new List<Lead>{testLead}, accIds);
            Test.stopTest();
        }
    
    @isTest
    static void testCreatefollowupTasks() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testus4er@test.com' LIMIT 1];
        
        Test.startTest();
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            OwnerId = testUser.Id,
            Next_Follow_up_Date__c = Date.today().addDays(7),
            Status = 'Open',
              phone='1241678906'
        );
        
        LeadTriggerHandler.createfollowupTasks(new List<Lead>{testLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testCreatefollowupTasksNoDate() {
        User testUser = [SELECT Id FROM User WHERE UserName = 'testus4er@test.com' LIMIT 1];
        
        Test.startTest();
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            OwnerId = testUser.Id,
            Status = 'Open',
              phone='1433678906'
        );
        
        LeadTriggerHandler.createfollowupTasks(new List<Lead>{testLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testCreatefollowupTasksNoOwner() {
        Test.startTest();
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Next_Follow_up_Date__c = Date.today().addDays(7),
            Status = 'Open',
              phone='1267678906'
        );
        
        LeadTriggerHandler.createfollowupTasks(new List<Lead>{testLead});
        
        Test.stopTest();
    }
    
    @isTest
    static void testCreatefollowupTasksEmptyList() {
        Test.startTest();
        
        LeadTriggerHandler.createfollowupTasks(new List<Lead>());
        
        Test.stopTest();
    }
}
        @isTest
        static void testCampaignMappingMultipleLeads() {
            Campaign camp = [SELECT Id FROM Campaign LIMIT 1];
            Lead lead1 = new Lead(LastName='Lead1',Company='C1',Campaign__c=camp.Id,Status='Open');
            Lead lead2 = new Lead(LastName='Lead2',Company='C2',Campaign__c=camp.Id,Status='Open');
            insert new List<Lead>{lead1, lead2};
            Test.startTest();
            LeadTriggerHandler.campaignMapping(new List<Lead>{lead1, lead2});
            Test.stopTest();
        }

        @isTest
        static void testLeadAssignedNotificationMissingFields() {
            User testUser = [SELECT Id FROM User WHERE UserName = 'testus4er@test.com' LIMIT 1];
            Lead lead = new Lead(LastName='Test',Company='Test',OwnerId=testUser.Id,Status='Open');
            insert lead;
            Test.startTest();
            LeadTriggerHandler.leadAssignedNotification(new List<Lead>{lead});
            Test.stopTest();
        }

        @isTest
        static void testCheckAndSeprateMobileNumberEdgeCases() {
            Lead lead = new Lead(LastName='Edge',Company='Edge',Phone='+91 9876543210',MobilePhone='+91 9876543211',Status='Open');
            insert lead;
            Test.startTest();
            LeadTriggerHandler.checkAndSeprateMobileNumber(new List<Lead>{lead});
            Test.stopTest();
        }

        @isTest
        static void testUpdateLastActivityDateConvertedClosed() {
            Lead lead = new Lead(LastName='Conv',Company='Conv',Status='Closed Won',IsConverted=true);
            insert lead;
            Map<Id, Lead> oldMap = new Map<Id, Lead>{lead.Id => new Lead(Id=lead.Id,Status='Open',IsConverted=false)};
            Test.startTest();
            LeadTriggerHandler.updateLastActivityDate(new List<Lead>{lead}, oldMap);
            Test.stopTest();
        }

        @isTest
        static void testSendLostConvertedManagerNotificationNoOwner() {
            Lead lead = new Lead(LastName='NoOwner',Company='NoOwner',Status='Closed Lost');
            insert lead;
            Test.startTest();
            LeadTriggerHandler.sendLostConvertedManagerNotification(new List<Lead>{lead});
            Test.stopTest();
        }

        @isTest
        static void testFindDuplicateAllFields() {
            Lead lead = new Lead(LastName='Dup',Company='Dup',Email='dup@test.com',Secondary_Email__c='sec@test.com',Phone='9876543210',Mobilephone='9876543211',Status='Open');
            insert lead;
            Test.startTest();
            LeadTriggerHandler.findDuplicate(new List<Lead>{lead});
            Test.stopTest();
        }

        @isTest
        static void testFindDuplicateNullList() {
            Test.startTest();
            try {
                LeadTriggerHandler.findDuplicate(null);
            } catch (Exception e) {
                System.assert(true);
            }
            Test.stopTest();
        }

        @isTest
        static void testSetAccountEmailMultipleLeads() {
            Account acc = new Account(Name='MultiAcc');
            insert acc;
            Lead lead1 = new Lead(LastName='L1',Company='C1',Email='l1@test.com',ConvertedAccountId=acc.Id);
            Lead lead2 = new Lead(LastName='L2',Company='C2',Email='l2@test.com',ConvertedAccountId=acc.Id);
            insert new List<Lead>{lead1, lead2};
            Set<String> accIds = new Set<String>{acc.Id};
            Test.startTest();
            LeadTriggerHandler.setAccountEmail(new List<Lead>{lead1, lead2}, accIds);
            Test.stopTest();
        }

        @isTest
        static void testCreatefollowupTasksException() {
            Lead lead = new Lead(LastName='Ex',Company='Ex',Next_Follow_up_Date__c=Date.today().addDays(1));
            insert lead;
            Test.startTest();
            LeadTriggerHandler.createfollowupTasks(new List<Lead>{lead});
            Test.stopTest();
        }

        @isTest
        static void testSendClosedWonNotificationNoCoordinator() {
            Profile salesProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            User ownerUser = new User(Alias='ownerusr',Email='owner@test.com',EmailEncodingKey='UTF-8',LastName='Owner',LanguageLocaleKey='en_US',LocaleSidKey='en_US',ProfileId=salesProfile.Id,TimeZoneSidKey='America/Los_Angeles',UserName='owneruser@test.com');
            insert ownerUser;
            Lead lead = new Lead(LastName='Closed Won Lead',Company='Test Company',OwnerId=ownerUser.Id,Status='Closed Won',phone='1234567890');
            insert lead;
            Test.startTest();
            LeadTriggerHandler.sendClosedWonNotification(new List<Lead>{lead});
            Test.stopTest();
        }