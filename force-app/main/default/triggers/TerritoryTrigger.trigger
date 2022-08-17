trigger TerritoryTrigger on Territory__c (before insert, after insert, before update, after update, after delete, after undelete ) {
    switch on Trigger.operationType {
        when before_update {
            TerritoryTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}