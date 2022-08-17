public with sharing class AccountTriggerHandler {
    public static void beforeInsert(List<Account> newAccounts){
        List<Account> assignTerritory = new List<Account>();
            
        for(Account acc : newAccounts){
            if(acc.BillingPostalCode != null){
                assignTerritory.add(acc);
            }
        }
        
        if(assignTerritory != null && assignTerritory.size() > 0){
            AccountController.checkOwnerMatchesTerritory(assignTerritory);
        }
    }
    
    public static void afterInsert(List<Account> updatedAccounts, Map<Id,Account> oldAccounts){
        List<Assignment_History__c> insertHistories = new List<Assignment_History__c>();

        for(Account acc : updatedAccounts){
            Assignment_History__c history = new Assignment_History__c();
            history.Account__c = acc.Id;
            history.New_Territory__c = acc.Territory__c;
            history.New_Owner__c = acc.OwnerId;
        }

        insert insertHistories;
    }
    
    public static void beforeUpdate(List<Account> updatedAccounts, Map<Id,Account> oldMap){
        List<Account> assignTerritory = new List<Account>();
        
        for(Account acc : updatedAccounts){
            if(acc.BillingPostalCode != oldMap.get(acc.Id).BillingPostalCode){
                assignTerritory.add(acc);
            }
        }
        
        List<Account> accountsWithNewOwner = new List<Account>();
        if(assignTerritory != null && assignTerritory.size() > 0){
            System.debug('assignTerritory is not null : ' + assignTerritory);
            accountsWithNewOwner = AccountController.checkOwnerMatchesTerritory(assignTerritory);
            System.debug('accountsWithNewOwner = ' + accountsWithNewOwner);
            
            // Finally update Account, Contact, and Opp owners!
            AccountController.reassignAccountContactAndOpp(accountsWithNewOwner , TRUE);

            // Create Territory Assignment records
            AccountController.createAssignmentHistory(accountsWithNewOwner, oldMap);
        }
    }
}