public with sharing class AccountController {
    public static List<Account> insertAccounts(List<Account> accountToInsert){
        insert accountToInsert;
        return accountToInsert;
    }
    
    public static Account insertAccount(Account acc){
        insert acc;
        return acc;
    }
    
    public static Integer getAccountSize(){
        List<Account> acc = [SELECT Id from Account];
        return acc.size();
    }
    
    public static List<Account> getAllAccounts(){
        List<Account> accounts = [SELECT Name, Phone FROM Account];
        return accounts;
    }
    
    public static  List<Account> listAllAccounts(){
        List<Account> accounts = getAllAccounts();
        return accounts;
    }
    
    public static void printAllAccounts(){
        List<Account> accounts = getAllAccounts();
        for(Account acc : accounts){
            system.debug(acc);
        }
    }
    public static void updateAvgCaseResolutionDays(List<Account> accountId){
        Map<Id,Integer> totalDays = new Map<Id,Integer>();
        Map<Id,Integer> totalCases = new Map<Id,Integer>();
        List<Account> updateAccounts = new List<Account>();
        
        
        // retrive all cloased cases for the list of accounts & compile maps for calculation
        for(Case caseObj : [SELECT Id, CreatedDate, ClosedDate, AccountId
        FROM Case
        WHERE IsClosed=true
        AND AccountId IN :accountId order by AccountId]){
            // increase number of cases
            totalCases.put(caseObj.AccountId, (totalCases.containsKey(caseObj.AccountId)) ? totalCases.get(caseObj.AccountId) + 1 : 1);
            system.debug(caseObj.AccountId + ' increased totalCases to ' + totalCases.get(caseObj.AccountId));
            // get duration in days and add it to totalDays
            totalDays.put(caseObj.AccountId, (totalDays.containsKey(caseObj.AccountId)) ? totalDays.get(CaseObj.AccountId) + caseObj.CreatedDate.date().daysBetween(caseObj.ClosedDate.date()) : 1);
            system.debug(caseObj.AccountId + ' increased totalDays to ' + totalDays.get(caseObj.AccountId));
        }
        
        // loop through totalDays map to calculate Avg_Case_Resolution Days and
        // compile the list of accounts to be updated
        system.debug('key set: ' + totalDays.keySet());
        for(String acct: totalDays.keySet()){
            Account accountTemp = new Account();
            accountTemp.Id = acct;
            // Calculate resolution days by fetching the map values based on account id
            accountTemp.Avg_Case_Resolution_Days__c = (totalDays.get(acct)/totalCases.get(acct)) ;
            system.debug(acct + ' Avg_Case_Resolution_Days__c calculated to ' + accountTemp.Avg_Case_Resolution_Days__c + '(days: ' + totalDays.get(acct) + ' cases: ' + totalCases.get(acct) + ')');
            
            // add account to list of accounts to update
            updateAccounts.add(accountTemp);
        }
        
        system.debug(updateAccounts);
        
        // Update accounts if any
        try{
            if(updateAccounts != null){
                update updateAccounts;
            }
        } catch(Exception e){
            system.debug('EXCEPTION!!!');
            system.debug(e.getCause());
            system.debug(e.getLineNumber());
            system.debug(e.getMessage());
        }
    }
    
    
    public static List<Account> getAllActiveAccounts() {
        return [SELECT Id,Name,Active__c FROM Account WHERE Active__c = 'Yes'];
    }
    
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
        Map<Id,Id> matchedTerritoriesByAccount = new Map<Id,Id>();
        
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
            if(matchedTerritoriesByAccount.containsKey(acc.Id)){
                Id matchedTerritoryId = matchedTerritoriesByAccount.get(acc.Id);
                // Check to see if the Account owner is listed in the TA's for the Account's appropriate Territory record
                if(!territoryAndTAsMap.get(matchedTerritoryId).contains(acc.OwnerId)){
                    triggerTerritoryIds.add(matchedTerritoryId);
                    accountNeedNewOwner.add(acc);
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