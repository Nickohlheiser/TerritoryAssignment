trigger TerritoryTrigger on Territory__c (before insert, after insert, before update, after update, after delete, after undelete ) {
    switch on Trigger.operationType {
        when before_insert {
            TerritoryTriggerHandler.beforeInsert(Trigger.new);
        }
        when after_insert {
        
        }
        when before_update {
            TerritoryTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}