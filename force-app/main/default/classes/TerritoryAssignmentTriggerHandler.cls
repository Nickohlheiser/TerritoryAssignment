public with sharing class TerritoryAssignmentTriggerHandler {
    public static void beforeInsert(List<Territory_Assignment__c> newTAs){
        for(Territory_Assignment__c t : newTAs){
            t.Duplicate_Key__c = t.Territory__c + '' + t.Assignee__c;
        }
    }

    public static void beforeUpdate(List<Territory_Assignment__c> newTAs, Map<Id,Territory_Assignment__c> oldTAsMap){
        for(Territory_Assignment__c t : newTAs){
            if(t.Territory__c + '' + t.Assignee__c != oldTAsMap.get(t.Id).Duplicate_Key__c){
                t.Duplicate_Key__c = t.Territory__c + '' + t.Assignee__c;
            }
        }
    }
    
    public static void afterUpdate(List<Territory_Assignment__c> newTAs, Map<Id,Territory_Assignment__c> oldTAs){
        Set<Id> reassignTerritoryIDs = new Set<Id>();

        for(Territory_Assignment__c newTA : newTAs){
            if(newTA.Assignee__c != oldTAs.get(newTA.Id).Assignee__c){
                reassignTerritoryIDs.add(newTA.Territory__c);
            }
        }

        if(reassignTerritoryIDs != null && reassignTerritoryIDs.size() > 0){
            List<Territory__c> reassignTerritories = [SELECT Id, Name FROM Territory__c WHERE Id IN :reassignTerritoryIDs];
            TerritoryController tc = new TerritoryController();
            List<Account> reassignedAccounts = tc.processTriggeredTerritories(reassignTerritories);
            if(reassignedAccounts != null && reassignedAccounts.size() > 0){
                AccountController.reassignAccountContactAndOpp(reassignedAccounts, FALSE);
            }
        }
    }
}