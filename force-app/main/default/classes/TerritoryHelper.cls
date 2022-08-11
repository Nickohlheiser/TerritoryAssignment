public without sharing class TerritoryHelper {
    public  Map<Id,Id> findTerritory(List<Account> accountsToProcess){
        // return Map = Account ID > Territory Id
        Map<Id,Id> returnMap = new Map<Id,Id>();
        
        // create Map of territories for matching (Territory Name > Territory ID> List of TA's)
        Map<String,Id> allTerritoriesMap = new Map<String,Id>();
        for(Territory__c t : [Select Id, Name FROM Territory__c WHERE Number_Of_TAs__c > 0]){
            allTerritoriesMap.put(t.Name, t.Id);
        }
        System.debug('allTerritoriesMap keySet: ' + allTerritoriesMap.keySet());

        for(Account acc : accountsToProcess){
            // Loop through the zip iterations (continuously adding wildcarded characters) until a match is found, if one is found then add to returnMap
            for(Integer i = 5; i > 0 ; i--){
                String zipIteration; 
                if(i == 5){
                    // Accounts for exact zip assignment '12345'
                    zipIteration = acc.BillingPostalCode;
                } else {
                    // No exact zip assignment found, begin wildcarding: 12345 > 1234% > 123% etc.
                    zipIteration = acc.BillingPostalCode.left(i) + '%';
                }
                System.debug('findTerritory zipIteration: ' + zipIteration);
                if(allTerritoriesMap.containsKey(zipIteration)){
                    // add the account ID & Territory ID to the returnMap
                    returnMap.put(acc.Id, allTerritoriesMap.get(zipIteration));
                }
            }
        }

        return returnMap;

    }
}