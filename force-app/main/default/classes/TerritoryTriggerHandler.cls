public with sharing class TerritoryTriggerHandler {
    public static void beforeUpdate(List<Territory__c> newTerritories, Map<Id,Territory__c> oldTerritories){
        // Reassign accounts in this territory if the Name (Zip Code) changed or if the number of TA's changed
        List<Territory__c> territoriesNeedingReassignment = new List<Territory__c>();
        for(Territory__c t : newTerritories){
            if(t.Name != oldTerritories.get(t.Id).Name || t.Number_Of_TAs__c != oldTerritories.get(t.Id).Number_Of_TAs__c){
                territoriesNeedingReassignment.add(t);
            }
        }
        
        if(territoriesNeedingReassignment != null && territoriesNeedingReassignment.size() > 0){
            TerritoryController tc = new TerritoryController();
            List<Account> ressignedAccounts = tc.processTriggeredTerritories(territoriesNeedingReassignment);
            AccountController.reassignAccountContactAndOpp(ressignedAccounts, FALSE);
        }
    }
}