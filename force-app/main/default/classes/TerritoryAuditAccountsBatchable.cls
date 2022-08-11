public class TerritoryAuditAccountsBatchable implements Database.Batchable<sObject> {
    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator('SELECT Id, OwnerId, Territory__c,  BillingPostalCode FROM Account WHERE BillingPostalCode != null');
    }
    
    public void execute(Database.BatchableContext BC, List<Account> scope) {
        // Build a map of the records original values for Assignment History creation if necessary
        Map<Id,Account> effectiveOldMap = new Map<Id,Account>();
        for(Account acc : scope){
            Account temp = new Account();
            temp.OwnerId = acc.OwnerId;
            temp.Territory__c = acc.Territory__c;

            effectiveOldMap.put(acc.id, temp);
        }

        // Identify any accounts in this batch which don't align with the appropriate Territory
        List<Account> accountsWithNewOwner = new List<Account>();
        accountsWithNewOwner = AccountController.checkOwnerMatchesTerritory(scope);
        
        
        if(accountsWithNewOwner != null && accountsWithNewOwner.size() > 0){
            
            // Finally update Account, Contact, and Opp owners!
            AccountController.reassignAccountContactAndOpp(accountsWithNewOwner , FALSE);
            
            // Create Territory Assignment records
            AccountController.createAssignmentHistory(accountsWithNewOwner, effectiveOldMap);
        }
    }
    
    public void finish(Database.BatchableContext BC) {
    }
}