public with sharing class AccountController {
    public static void reassignAccountContactAndOpp (List<Account> reassignAccounts, Boolean updateAccounts){
        List<Contact> updatedContacts = new List<Contact>();
        List<Opportunity> updatedOpps = new List<Opportunity>();
        
        // Build map to reference the new Owner ID based on the Account ID of the child object
        Map<Id,Id> AccountIdByOwnerId = new Map<Id,Id>();
        for(Account acc : reassignAccounts){
            AccountIdByOwnerId.put(acc.Id, acc.OwnerId);
        }
        
        for(Contact c : [SELECT Id, AccountId, OwnerId FROM Contact WHERE AccountId IN :AccountIdByOwnerId.keySet()]){
            c.OwnerId = AccountIdByOwnerId.get(c.AccountId);
            updatedContacts.add(c);
        }
        
        for(Opportunity opp : [SELECT Id, AccountId, OwnerID FROM Opportunity WHERE AccountId IN : AccountIdByOwnerId.keySet() AND IsClosed = FALSE]){
            opp.ownerId = AccountIdByOwnerId.get(opp.AccountId);
            updatedOpps.add(opp);
        }
        
        if(updateAccounts == FALSE){
            update reassignAccounts;
        }
        update updatedContacts;
        update updatedOpps;
    }
    
    public static List<Account> checkOwnerMatchesTerritory(List<Account> triggeredAccounts){
        // Returns list of account with updated Owner ID & Territory__c value
        List<Account> returnAccounts = new List<Account>();
        
        // Find the appropriate Territory for the Account's Postal Billing Code
        // AccountId > Territory ID
        Map<String,Id> matchedTerritoriesByAccount = new Map<String,Id>();
        
        // Function only returns for accounts which match to a Territory
        TerritoryHelper th = new TerritoryHelper();
        matchedTerritoriesByAccount = th.findTerritory(triggeredAccounts);
        
        
        // Take the list of Territory ID's returned in the section above & produce the territoryAndTAsMap for a quick lookup next
        Set<Id> matchedTerritoryIds = new Set<Id>();
        matchedTerritoryIds.addAll(matchedTerritoriesByAccount.values());
        Map<Id,Set<Id>> territoryAndTAsMap = new Map<Id,Set<Id>>();
        for(Territory_Assignment__c ta : [SELECT Territory__c, Assignee__c FROM Territory_Assignment__c ]){
            if(!territoryAndTAsMap.containsKey(ta.Territory__c)){
                territoryAndTAsMap.put(ta.Territory__c, new Set<Id>());
            }
            territoryAndTAsMap.get(ta.Territory__c).add(ta.Assignee__c);
        }
        
        Set<Id> triggerTerritoryIds = new Set<Id>();
        List<Account> accountNeedNewOwner = new List<Account>();
        // Check the Account's appropriate Territory (matchedTerritoriesByAccount) against the TA's in the Territory (territoryAndTAsMap), if there is NO match then add the territory to the list to be re-processed
        for(Account acc : triggeredAccounts){
            // Check to see if the Account matched a Territory, if no match then loop iteration ends, else check the Account Owner to the TA's in the Territory    
            String mapKey = (acc.Id == null) ? acc.OwnerId + acc.BillingPostalCode : acc.Id;
            if(matchedTerritoriesByAccount.containsKey(mapKey)){
                Id matchedTerritoryId = matchedTerritoriesByAccount.get(mapKey);
                System.debug('AccountController: Account BillingPostalCode ' + acc.BillingPostalCode + ' matched Territory Id ' + matchedTerritoryId);
                // Check to see if the Account owner is listed in the TA's for the Account's appropriate Territory record
                if(!territoryAndTAsMap.get(matchedTerritoryId).contains(acc.OwnerId)){
                    triggerTerritoryIds.add(matchedTerritoryId);
                    accountNeedNewOwner.add(acc);
                    System.debug('AccountController: Account (Owner ' + acc.OwnerId + ' BillingPostalCode ' + acc.BillingPostalCode + ') does not match a TA, adding account to accountNeedNewOwner and TerritoryId to triggerTerritoryIds');
                    System.debug('AccountController: TAs: ' + territoryAndTAsMap.get(matchedTerritoryId));
                } else {
                    System.debug('AccountController: Account ' + acc.Name + ' (Owner ID ' + acc.OwnerId + ' BillingPostalCode' + acc.BillingPostalCode + ') matched a TA (' + territoryAndTAsMap.get(matchedTerritoryId) + ')');
                }
            }
        }
        
        // Finally allow the TerritoryController to re-assign any mis-owned accounts
        // Also identifies the prior Territory for the Assignment History record
        if(triggerTerritoryIds != null && triggerTerritoryIds.size() >0){
            List<Territory__c> triggerTerritories = [SELECT ID, Name FROM Territory__c WHERE Id IN :triggerTerritoryIds];
            TerritoryController tc = new TerritoryController();
            List<Account> reassignedAccounts = tc.processTriggeredTerritories(triggerTerritories, accountNeedNewOwner);
            if(reassignedAccounts != null && reassignedAccounts.size() > 0){
                for(Account acc : reassignedAccounts){
                    acc.Territory__c = matchedTerritoriesByAccount.get(acc.Id);
                    returnAccounts.add(acc);
                }
            }
        }

        return returnAccounts;
    }

    public static void createAssignmentHistory(List<Account> updatedAccounts, Map<Id,Account> oldMap){
        List<Assignment_History__c> insertHistories = new List<Assignment_History__c>();
        for(Account acc : updatedAccounts){
            Assignment_History__c history = new Assignment_History__c();
            history.Account__c = acc.Id;
            history.New_Owner__c = acc.OwnerId;
            history.Previous_Owner__c = oldMap.get(acc.Id).OwnerId;
            history.New_Territory__c = acc.Territory__c;
            history.Previous_Territory__c = oldMap.get(acc.Id).Territory__c;
            insertHistories.add(history);
        }
        insert insertHistories;
    }
}