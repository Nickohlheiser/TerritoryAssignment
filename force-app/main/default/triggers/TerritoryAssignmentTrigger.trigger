trigger TerritoryAssignmentTrigger on Territory_Assignment__c (before insert, before update) {
    switch on Trigger.operationType {
        when before_insert {
            TerritoryAssignmentTriggerHandler.beforeInsert(Trigger.new);
        }
        when before_update {
            TerritoryAssignmentTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}