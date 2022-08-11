trigger AccountTrigger on Account (before insert, after insert, before update) {
    switch on Trigger.operationType {
        when before_insert {
            AccountTriggerHandler.beforeInsert(Trigger.new);
        }

        when after_insert {
            AccountTriggerHandler.afterInsert(Trigger.new, Trigger.oldMap);
        }
        
        when before_update {
            AccountTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}