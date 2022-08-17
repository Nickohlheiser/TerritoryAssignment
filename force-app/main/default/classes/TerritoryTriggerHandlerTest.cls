@isTest
private class TerritoryTriggerHandlerTest {
    
    @testSetup
    private static void testSetup() {
        // result is test Users, Accounts, Territories, and Territory Assignments
        // Users all have a last name ranging from 0 to 8
        // Territoies are 12345,777%, 7776% ,  and 77765
        // TA's are 0 & 1, 2 & 3, 4 & 5, 6 & 7 respectively
        // All accounts are created with owners NOT in the territory but are corrected by the automation in the end
        // Account BillingPostalCodes are:
        //      12345 (two accounts, 12345 territory)
        //      77788 & 77789 (777% territory)
        //      77761 & 77762 (7776% territory)
        //      77765 (two accounts, 77765 territory)


        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        
        System.runAs(thisUser){
            //! Create test users
            List<User> newUsers = new List<User>();
            Id profileId = [SELECT Id FROM Profile WHERE Name = 'Custom: Sales Profile' LIMIT 1].Id;
            
            Id roleId = [SELECT Id FROM UserRole WHERE Name = 'Western Sales Team' LIMIT 1].Id;
            
            for (Integer i = 0; i < 8; i++) {
                String iString = String.ValueOf(i);
                String firstName = 'Test_T';
                String alias = firstName + iString;
                String userName = alias + '@abc.test.TerritoryAssignmentDEMO';
                String timeZoneSidKey = 'America/Los_Angeles';
                String localeSidKey = 'en_US';
                String emailEncodingKey = 'UTF-8';
                String languageLocaleKey = 'en_US';
                
                newUsers.add(new User(
                FirstName = firstName, 
                LastName = iString, 
                email = userName, 
                UserName = userName,
                Alias = alias,
                ProfileId = profileId, 
                UserRoleId = roleId,
                TimeZoneSidKey = timeZoneSidKey,
                LocaleSidKey = localeSidKey, 
                EmailEncodingKey = emailEncodingKey,
                LanguageLocaleKey = languageLocaleKey
                ));
            }
            
            insert newUsers;
            
            //! Create Territories
            List<Territory__c> newTerritories = new List<Territory__c>();
            newTerritories.add(new Territory__c(Name = '12345'));
            newTerritories.add(new Territory__c(Name = '777%'));
            newTerritories.add(new Territory__c(Name = '7776%'));
            newTerritories.add(new Territory__c(Name = '77765'));
            
            insert newTerritories;
            
            //! Assign TAs to the Territories
            List<User> testUsersIndexed = [SELECT Id, LastName FROM User WHERE FirstName = 'Test_T' ORDER BY LastName ASC];
            List<Territory_Assignment__c> newTAs = new List<Territory_Assignment__c>();
            // Users 0 & 1 assigned to Territory 12345
            newTAs.add(new Territory_Assignment__c(Territory__c = newTerritories[0].Id, Assignee__c = testUsersIndexed[0].Id));
            newTAs.add(new Territory_Assignment__c(Territory__c = newTerritories[0].Id, Assignee__c = testUsersIndexed[1].Id));
            // Users 2 & 3 assigned to Territory 777%
            newTAs.add(new Territory_Assignment__c(Territory__c = newTerritories[1].Id, Assignee__c = testUsersIndexed[2].Id));
            newTAs.add(new Territory_Assignment__c(Territory__c = newTerritories[1].Id, Assignee__c = testUsersIndexed[3].Id));  
            // Users 3 & 4 assigned to Territory 7776%
            newTAs.add(new Territory_Assignment__c(Territory__c = newTerritories[2].Id, Assignee__c = testUsersIndexed[4].Id));
            newTAs.add(new Territory_Assignment__c(Territory__c = newTerritories[2].Id, Assignee__c = testUsersIndexed[5].Id));
            // Users 5 & 6 assigned to Territory 77765
            newTAs.add(new Territory_Assignment__c(Territory__c = newTerritories[3].Id, Assignee__c = testUsersIndexed[6].Id));
            newTAs.add(new Territory_Assignment__c(Territory__c = newTerritories[3].Id, Assignee__c = testUsersIndexed[7].Id));
            
            insert newTAs;
            
            List<Account> baseAccounts = new List<Account>();
            baseAccounts.add(new Account(OwnerId = newTAs[0].Assignee__c, Name = 'Test 0', BillingPostalCode = '12345'));
            baseAccounts.add(new Account(OwnerId = newTAs[2].Assignee__c, Name = 'Test 1', BillingPostalCode = '12345')); //Intentional bad owner
            baseAccounts.add(new Account(OwnerId = newTAs[2].Assignee__c, Name = 'Test 2', BillingPostalCode = '77788'));
            baseAccounts.add(new Account(OwnerId = newTAs[4].Assignee__c, Name = 'Test 3', BillingPostalCode = '77789')); //Intentional bad owner
            baseAccounts.add(new Account(OwnerId = newTAs[4].Assignee__c, Name = 'Test 4', BillingPostalCode = '77761'));
            baseAccounts.add(new Account(OwnerId = newTAs[6].Assignee__c, Name = 'Test 5', BillingPostalCode = '77762')); //Intentional bad owner
            baseAccounts.add(new Account(OwnerId = newTAs[6].Assignee__c, Name = 'Test 6', BillingPostalCode = '77765'));
            baseAccounts.add(new Account(OwnerId = newTAs[0].Assignee__c, Name = 'Test 7', BillingPostalCode = '77765')); //Intentional bad owner
            
            insert baseAccounts;
        
        }
        
    }
    
    @IsTest
    private static void TestInsertWildcardAccounts() {
        System.debug('TestInsertWildcardAccounts starting');
        //!Verify the data created in the test method re-assigned accounts properly & did not re-assign accounts which matched a TA.
        
        // Get list of good TA's
        Map<String,Set<Id>> taByZip = new Map<String,Set<Id>>();
        
        List<String> territoryNames = new List<String>{'777%','7776%','77765','12345'};
        for(Territory_Assignment__c t : [SELECT Assignee__c, Territory__r.Name, Assignee__r.LastName FROM Territory_Assignment__c WHERE Territory__r.Name IN :territoryNames]){
            if(taByZip != null && !taByZip.containsKey(t.Territory__r.Name)){
                taByZip.put(t.Territory__r.Name, new Set<Id>());
            }
            taByZip.get(t.Territory__r.Name).add(t.Assignee__c);
            System.debug('TestInsertWildcardAccounts: taByZip, Adding ' + t.Territory__r.Name + ' & TA ' + t.Assignee__c + ' (LastName ' + t.Assignee__r.LastName + ')');
        }
        
        Test.startTest();
        Test.stopTest();
        List<String> postalCodes = new List<String>{'77788','77789', '77761','77762','77765','12345'};
        List<Account> wildcardAccounts = [SELECT OwnerId, Name, BillingPostalCode FROM Account WHERE BillingPostalCode IN :postalCodes];
        
        // Ensure all 8 accounts are being checked
        System.assertEquals(wildCardAccounts.size(), 8);
        
        // Ensure the new owner is a TA for the Territory
        for(Account a : wildcardAccounts){
            System.debug('TestInsertWildcardAccounts: wildcarAccounts iteration ' + a.Name + ' (' + a.BillingPostalCode + ') OwnerId is ' + a.OwnerId);
            switch on a.BillingPostalCode {
                when '77788','77789' {
                    system.assert(taByZip.get('777%').contains(a.OwnerId));
                }
                when '77761','77762' {
                    system.assert(taByZip.get('7776%').contains(a.OwnerId));
                }
                when '77765' {
                    system.assert(taByZip.get('77765').contains(a.OwnerId));
                }
                when '12345' {
                    system.assert(taByZip.get('12345').contains(a.OwnerId));
                }
            }
        }
        System.debug('TestInsertWildcardAccounts finished');
    }
    
    @isTest
    private static void testAccountUpdate() {
        Map<String,Set<Id>> taByZip = new Map<String,Set<Id>>();
        
        List<String> territoryNames = new List<String>{'777%','7776%','77765','12345'};
        for(Territory_Assignment__c t : [SELECT Assignee__c, Territory__r.Name, Assignee__r.LastName FROM Territory_Assignment__c WHERE Territory__r.Name IN :territoryNames]){
            if(taByZip != null && !taByZip.containsKey(t.Territory__r.Name)){
                taByZip.put(t.Territory__r.Name, new Set<Id>());
            }
            taByZip.get(t.Territory__r.Name).add(t.Assignee__c);
        }
        
        // 77761 to 77763, no owner change
        // 77762 to 77773, owner should change
        // 12345 to 77765, owner should change
        List<String> postalCodes = new List<String>{'77761','77762','12345'};
        List<Account> accountsBefore = [SELECT Id, OwnerId, BillingPostalCode FROM Account WHERE BillingPostalCode IN :postalCodes];

        
        List<Account> updateAccounts = new List<Account>();
        for (Account acc : accountsBefore) {
            switch on acc.BillingPostalCode {
                when '77761' {
                    acc.BillingPostalCode = '77763';
                    updateAccounts.add(acc);
                }
                when '77762' {
                    acc.BillingPostalCode = '77773';
                    updateAccounts.add(acc);
                }
                when '12345' {
                    acc.BillingPostalCode = '77765';
                    updateAccounts.add(acc);
                }
            }
        }

        // Create an opportunity & contact for each of the accounts with the current owner
        List<Contact> insertContacts = new List<Contact>();
        List<Opportunity> insertOpps = new List<Opportunity>();
        for(Account acc : accountsBefore){
            insertContacts.add(new Contact(OwnerId = acc.OwnerId, AccountId = acc.Id, Email = 'abc@def.com', LastName = 'test'));
            insertOpps.add(new Opportunity(OwnerId = acc.OwnerId, AccountId = acc.Id, CloseDate = date.today(), StageName = 'Prospecting', Name = 'test opp'));
        }

        insert insertContacts;
        insert insertOpps;
        
        Test.startTest();
        update updateAccounts;
        Test.stopTest();
        
        List<String> newPostalCodes = new List<String>{'77763','77773','77765'};
        List<Account> accountsAfter = [SELECT OwnerId, Name, BillingPostalCode, (SELECT OwnerId FROM Opportunities), (SELECT OwnerId FROM Contacts) FROM Account WHERE BillingPostalCode IN :newPostalCodes];
        System.debug('accountsAfter: ' + accountsAfter);
        
        for(Account a : accountsAfter){
            switch on a.BillingPostalCode {
                when '77763' {
                    system.assert(taByZip.get('7776%').contains(a.OwnerId));
                    for(Contact con : a.Contacts){
                        system.assert(taByZip.get('7776%').contains(con.OwnerId));
                    }
                    for(Opportunity opp : a.Opportunities){
                        system.assert(taByZip.get('7776%').contains(opp.OwnerId));
                    }
                }
                when '77773' {
                    system.assert(taByZip.get('777%').contains(a.OwnerId));
                    for(Contact con : a.Contacts){
                        system.assert(taByZip.get('777%').contains(con.OwnerId));
                    }
                    for(Opportunity opp : a.Opportunities){
                        system.assert(taByZip.get('777%').contains(opp.OwnerId));
                    }
                }
                when '77765' {
                    system.assert(taByZip.get('77765').contains(a.OwnerId));
                }
                
            }
        }
    }

    @isTest
    private static void testNewTerritory() {
        // Create accounts which don't match a Territory, create the territories & verify the account was reassigned
        // The new accounts & territories will be wildcarded & hardcoded to ensure the layering is working as well
        // Territories will be:

        List<String> lastNames = new List<String>{'0','1','2','3','4','5'};
        List<User> users = [SELECT Id, LastName FROM User WHERE LastName IN :lastNames ORDER BY LastName ASC];
    
        // Create the accounts
        List<Account> createAccounts = new List<Account>();
        // 111% goes to users 0 & 1
        createAccounts.add(new Account(Name='11111',OwnerId = users[4].Id, BillingPostalCode = '11111'));
        createAccounts.add(new Account(Name='11112',OwnerId = users[3].Id, BillingPostalCode = '11112'));
        createAccounts.add(new Account(Name='11113',OwnerId = users[4].Id, BillingPostalCode = '11113'));
        createAccounts.add(new Account(Name='11114',OwnerId = users[3].Id, BillingPostalCode = '11114'));
        // 1112% goes to users 2 & 3
        createAccounts.add(new Account(Name='11121 test 1',OwnerId = users[4].Id, BillingPostalCode = '11121'));
        createAccounts.add(new Account(Name='11121 test 2',OwnerId = users[4].Id, BillingPostalCode = '11121'));
        // 11122 goes to user 4 or 5
        createAccounts.add(new Account(Name='11122',OwnerId = users[2].Id, BillingPostalCode = '11122'));

        insert createAccounts;

        List<Territory__c> territories = new List<Territory__c>();
        territories.add(new Territory__c(Name = '111%'));
        territories.add(new Territory__c(Name = '1112%'));
        territories.add(new Territory__c(Name = '11122'));

        insert territories;

        List<Territory_Assignment__c> tAssignments = new List<Territory_Assignment__c>();
        // 111% TA's, users 0 & 1
        tAssignments.add(new Territory_Assignment__c(Territory__c = territories[0].id, Assignee__c = users[0].Id));
        tAssignments.add(new Territory_Assignment__c(Territory__c = territories[0].id, Assignee__c = users[1].Id));
        // 1112% TA's, users 2 & 3
        tAssignments.add(new Territory_Assignment__c(Territory__c = territories[1].id, Assignee__c = users[2].Id));
        tAssignments.add(new Territory_Assignment__c(Territory__c = territories[1].id, Assignee__c = users[3].Id));
        // 11122 TA's, users 4 & 5
        tAssignments.add(new Territory_Assignment__c(Territory__c = territories[2].id, Assignee__c = users[4].Id));
        tAssignments.add(new Territory_Assignment__c(Territory__c = territories[2].id, Assignee__c = users[5].Id));

        // Actual test
        Test.startTest();
        insert tAssignments;
        Test.stopTest();
    
        Map<String,Set<Id>> tAssignmentsMap = new Map<String,Set<Id>>();
        List<String> territoryNames = new List<String>{'111%','1112%','11122'};
        for(Territory_Assignment__c ta : [SELECT Assignee__c, Territory__r.Name FROM Territory_Assignment__c WHERE Territory__r.Name IN :territoryNames]){
            if(!tAssignmentsMap.containsKey(ta.Territory__r.Name)){
                tAssignmentsMap.put(ta.Territory__r.Name, new Set<Id>());
            }
            tAssignmentsMap.get(ta.Territory__r.Name).add(ta.Assignee__c);
        }
        List<String> accountPostalCodes = new List<String>{'11111','11112','11113','11114','11121','11122'};
        for(Account acc : [SELECT Id, OwnerId, BillingPostalCode FROM Account WHERE BillingPostalCode IN :accountPostalCodes]){
            switch on acc.BillingPostalCode {
                when '11111','11112','11113','11114' {
                    System.assert(tAssignmentsMap.get('111%').contains(acc.OwnerId));
                }
                when '11121' {
                    System.assert(tAssignmentsMap.get('1112%').contains(acc.OwnerId));
                }
                when '11122' {
                    System.assert(tAssignmentsMap.get('11122').contains(acc.OwnerId));
                }
            }
        }
        // Asserts
    }

    @isTest
    private static void testUpdateAssignee() {
        // update one of the TA's for 777% territory from user 2 to user 4
        
        // Get the user ID's of user 2 and 4
        Id userTwo;
        Id userFour;
        for(User u : [SELECT Id, LastName FROM User WHERE LastName IN ('2','4')]){
            if(u.LastName == '2'){
                userTwo = u.Id;
            } else {
                userFour = u.Id;
            }
        }

        // Get the accounts owned by user 2 for this territory to compare after
        Map<Id,Account> beforeAccounts = new Map<Id,Account>([SELECT Id, OwnerId FROM Account WHERE OwnerId = :userTwo AND BillingPostalCode LIKE '777%' AND (NOT BillingPostalCode LIKE '7776%')]);

        // Begin updating the user 2 TA to user 4
        // Get the TA for user 2 from Territory 777%
        Territory_Assignment__c ta = [SELECT Id, Assignee__c FROM Territory_Assignment__c WHERE Assignee__c = :userTwo AND Territory__r.Name = '777%' LIMIT 1];
        // Change the Assignee__c value from user 2 to user 4
        ta.Assignee__c = userFour;

        // Actual test
        Test.startTest();
        update ta;
        Test.stopTest();

        // Loop through the the accounts owned by user 4 in this Territory & confirm they were all owned by user 2 prior
        for(Account acc : [SELECT Id, OwnerId FROM Account WHERE OwnerId = :userFour AND BillingPostalCode LIKE '777%' AND (NOT BillingPostalCode LIKE '7776%')]){
            // Confirm new OwnerId is user 4
            system.assertNotEquals(acc.OwnerId, beforeAccounts.get(acc.Id).OwnerId);
            // Confirm original OwnerId was user 2
            system.assertEquals(userTwo, beforeAccounts.get(acc.Id).OwnerId);
        }

    }

    @IsTest
    private static void testUpdateAssigneeHardcodedTerritory() {
        // update one of the TA's for 12345 territory from user 0 to user 6
        
        // Get the user ID's of user 0 and 6
        Id userZero;
        Id userSix;
        for(User u : [SELECT Id, LastName FROM User WHERE LastName IN ('6','0')]){
            if(u.LastName == '6'){
                userSix = u.Id;
            } else {
                userZero = u.Id;
            }
        }

        // Get the accounts owned by user 6 for this territory to compare after
        Map<Id,Account> beforeAccounts = new Map<Id,Account>([SELECT Id, OwnerId FROM Account WHERE OwnerId = :userZero AND BillingPostalCode = '12345']);

        // Begin updating the user 0 TA to user 6
        // Get the TA for user 0 from Territory 12345
        Territory_Assignment__c ta = [SELECT Id, Assignee__c FROM Territory_Assignment__c WHERE Assignee__c = :userZero AND Territory__r.Name = '12345' LIMIT 1];
        // Change the Assignee__c value from user 6 to user 0
        ta.Assignee__c = userSix;

        // Actual test
        Test.startTest();
        update ta;
        Test.stopTest();

        // Loop through the the accounts owned by user 0 in this Territory & confirm they were all owned by user 6 prior
        for(Account acc : [SELECT Id, OwnerId FROM Account WHERE OwnerId = :userSix AND BillingPostalCode = '12345']){
            // Confirm new OwnerId is user 0
            system.assertNotEquals(acc.OwnerId, beforeAccounts.get(acc.Id).OwnerId);
            // Confirm original OwnerId was user 6
            system.assertEquals(userSix, beforeAccounts.get(acc.Id).OwnerId);
        }

    }

    @IsTest
    private static void testUpdateAssigneeWildcardTerritory() {
        // update one of the TA's for 777% territory from user 2 to user 6
        
        // Get the user ID's of user 2 and 6
        Id userTwo;
        Id userSix;
        for(User u : [SELECT Id, LastName FROM User WHERE LastName IN ('6','2')]){
            if(u.LastName == '6'){
                userSix = u.Id;
            } else {
                userTwo = u.Id;
            }
        }

        // Get the accounts owned by user 6 for this territory to compare after
        Map<Id,Account> beforeAccounts = new Map<Id,Account>([SELECT Id, OwnerId FROM Account WHERE OwnerId = :userTwo AND BillingPostalCode IN ('77788','77789')]);

        // Begin updating the user 0 TA to user 6
        // Get the TA for user 0 from Territory 12345
        Territory_Assignment__c ta = [SELECT Id, Assignee__c FROM Territory_Assignment__c WHERE Assignee__c = :userTwo AND Territory__r.Name = '777%' LIMIT 1];
        // Change the Assignee__c value from user 6 to user 0
        ta.Assignee__c = userSix;

        // Actual test
        Test.startTest();
        update ta;
        Test.stopTest();

        // Loop through the the accounts owned by user 0 in this Territory & confirm they were all owned by user 6 prior
        for(Account acc : [SELECT Id, OwnerId FROM Account WHERE OwnerId = :userSix AND BillingPostalCode IN ('77788','77789')]){
            // Confirm new OwnerId is user 6
            system.assertNotEquals(acc.OwnerId, beforeAccounts.get(acc.Id).OwnerId);
            // Confirm original OwnerId was user 2
            system.assertEquals(userSix, beforeAccounts.get(acc.Id).OwnerId);
        }

    }

    @isTest
    private static void testAccountUpdateHardCodeOnly() {
        System.debug('testAccountUpdateHardCodeOnly starting');
        Map<Id,Account> accountsBefore = new Map<Id,Account>([SELECT Id, OwnerId, BillingPostalCode FROM Account WHERE BillingPostalCode = '77765']);
        List<Account> updateAccounts = new List<Account>();

        for(Id accId : accountsBefore.keySet()) {
            Account tempAccount = accountsBefore.get(accId);
            tempAccount.BillingPostalCode = '12345';
            updateAccounts.add(tempAccount);
        }

        Set<Id> TAIds = new Set<Id>();
        for(Territory_Assignment__c ta : [SELECT Id, Assignee__c FROM Territory_Assignment__c WHERE Territory__r.Name = '12345']){
            TAIds.add(ta.Assignee__c);
        }

        // Actual test
        Test.startTest();
        update updateAccounts;
        Test.stopTest();
    
        for(Account acc : [SELECT Id, OwnerId FROM Account WHERE Id IN :accountsBefore.keySet()]){
            system.assert(TAIds.contains(acc.OwnerId));
        }
        System.debug('testAccountUpdateHardCodeOnly finished');
    }

    @isTest
    private static void testAccountUpdateWildcardOnly() {
        System.debug('testAccountUpdateWildcardOnly starting');
        Map<Id,Account> accountsBefore = new Map<Id,Account>([SELECT Id, OwnerId, BillingPostalCode FROM Account WHERE BillingPostalCode IN ('77788','77789')]);
        List<Account> updateAccounts = new List<Account>();

        for(Id accId : accountsBefore.keySet()) {
            Account tempAccount = accountsBefore.get(accId);
            tempAccount.BillingPostalCode = '77765';
            updateAccounts.add(tempAccount);
        }

        Set<Id> TAIds = new Set<Id>();
        for(Territory_Assignment__c ta : [SELECT Id, Assignee__c FROM Territory_Assignment__c WHERE Territory__r.Name = '77765']){
            TAIds.add(ta.Assignee__c);
        }

        // Actual test
        Test.startTest();
        update updateAccounts;
        Test.stopTest();
    
        for(Account acc : [SELECT Id, OwnerId FROM Account WHERE Id IN :accountsBefore.keySet()]){
            system.assert(TAIds.contains(acc.Ownerid));
        }
        System.debug('testAccountUpdateWildcardOnly finished');
    }
}