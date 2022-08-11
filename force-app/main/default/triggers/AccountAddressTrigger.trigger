trigger AccountAddressTrigger on Account (before insert, before update) {
    switch on Trigger.operationType {
        when BEFORE_INSERT {
            for (Account acc : Trigger.new) {
                    if(acc.Match_Billing_Address__c){
                        acc.ShippingPostalCode = acc.BillingPostalCode;
                    }
            }
        }
        when BEFORE_UPDATE {
            for(Account accNew : Trigger.new){
                if(accNew.Match_Billing_Address__c != trigger.oldMap.get(accNew.Id).Match_Billing_Address__c){
                    accNew.ShippingPostalCode = accNew.BillingPostalCode;
                }
            }
        }
    }

}