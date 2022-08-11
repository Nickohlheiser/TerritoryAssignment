public without sharing class TerritoryController {
    // The function to receive accounts list with new owners is processTriggeredTerritories
    //      There are two flavors of this function:
    //          1. Receives only a list of territories: Territory/TA triggers
    //                  Simply calls flavor 2 with a null account list
    //          2. Receives territories & an account list: Account trigger
    
    
    public static Map<String,List<Account>> accountByZipMap = new Map<String,List<Account>>();
    public static Map<String,Map<String,Map<String,Integer>>> TAmap = new Map<String,Map<String,Map<String,Integer>>>();
    //Territory Name > TA Assignee > 'current' > count
    public static Map<String,List<Account>> misOwnedAccounts = new Map<String,List<Account>>();
    

    public List<Account> processTriggeredTerritories(List<Territory__c> triggeredTerritories){
        // called by functions triggered by Territory/TA changes.
        // Polymorphism allows the function to be called with or without a list of specific accounts to process, calls the same process but with a null account list
        list<Account> nullAccountsList = new List<Account>();
        List<Account> returnAccounts = processTriggeredTerritories(triggeredTerritories, nullAccountsList);
        return returnAccounts;
    }

    public list<Account> processTriggeredTerritories(List<Territory__c> triggeredTerritories, List<Account> specificAccountOverride){
        buildTAMap(triggeredTerritories);
        // 
        
        // requires Territories list
        // required to run for function identifyMisOwnedAccountsForZipCode
        
        // builds to accountByZipMap, required for function identifyMisOwnedAccountsForZipCode
        if(specificAccountOverride != null && specificAccountOverride.size() > 0){
            buildAccountByZipMap(specificAccountOverride);
        } else {
        buildAccountByZipMap(findAccountsInTerritory(getSoqlFilters(triggeredTerritories)));
        }


        identifyMisOwnedAccountsForZipCode();
        // loops through accountByZipMap & identifies accounts with OwnerIds that are not a TA for that zip.  Accounts are added to misOwnedAccounts map
        // requires accountsByZipMap to be populated (Territory zip code (Name) > list of accounts)

        List<Account> reassignedAccounts = new List<Account>();
        for(String Zip : TAmap.keySet()){
            Map<String,Map<String,Integer>> currentTAMap = TAmap.get(Zip);
            Map<String,Integer> unsortedTAMap = calculateCurrentAccountsByTA(currentTAMap);
            reassignedAccounts.addAll(assignMisOwnedAccountsForZipCode(currentTAMap, Zip));
            System.debug('processTriggeredTerritories finished for Zip ' + Zip);
        }
        return reassignedAccounts;    
    }
    
    private Map<String,List<String>> getSoqlFilters(List<Territory__c> territories){
        // Map of values to return:
        //      IN: not wildcarded
        //      LIKE: wildcarded
        //      NOT IN: Non-wildcarded Sub-territories of a wildcarded territory that's not in the incoming territories
        //      NOT LIKE: Wildcarded Sub-territories of a wildcarded territory that's not in the incoming territories
        Map<String,List<String>> filters = new Map<String,List<String>>();
        
        // Set of incoming territories to ensure an incoming territory isn't filtered due to being a sub-territory of an incoming wildcarded territory
        Set<String> includedTerritories = new Set<String>();
        
        // Loop through incoming territories & place into respective IN / OR Map values
        for(Territory__c t : territories){
            if(!t.Name.contains('%')){
                if(!filters.containsKey('IN')){
                    filters.put('IN',new List<String>());
                }
                filters.get('IN').add(t.Name);
                System.debug('getSoqlFilters: added ' + t.Name + ' to IN values');
            } else {
                if(!filters.containsKey('LIKE')){
                    filters.put('LIKE',new List<String>());
                }
                filters.get('LIKE').add(t.Name);
                System.debug('getSoqlFilters: added ' + t.Name + ' to LIKE values');
            }
        }
        
        // Compile SOQL filter to find sub-territories of the incoming wildcard territories to populate NOT IN portion of the query
        // Only necessary if there areinbound wildcarded territories
        if(filters.containsKey('LIKE')){
            // Step 1: Set base of SOQL filter
            String subTerritoryFilter = 'SELECT Id, Name FROM Territory__c WHERE ';
            String includeFilter = 'Name NOT IN (';
            
            // Step 2: add the IN & LIKE values from the map to the filter
            if(filters.containsKey('IN')){
                includeFilter += Utils.listToStringSingleQuote(filters.get('IN'));
                System.debug('includeFilter after IN = ' + includeFilter);
            }

            // if there are no LIKE values then close the IN filter ")"
            if(!filters.containsKey('LIKE')){
                subTerritoryFilter += includeFilter + ')';
                System.debug('filters doesn\'t contain LIKE, subTerritoryFilter = ' + subTerritoryFilter);
            } else {
                if(filters.containsKey('IN')){
                    System.debug('filters contains IN, adding comma');
                    includeFilter += ',';
                    System.debug('subTerritoryFilter = ' + subTerritoryFilter);
                }
                subTerritoryFilter += includeFilter + Utils.listToStringSingleQuote(filters.get('LIKE')) + ') AND (';
                System.debug('subTerritoryFilter after adding LIKEs = ' + subTerritoryFilter);
                
                
                // Step 3: Add the OR portions for LIKE filter on inbound wildcarded territories
                includeFilter = Utils.listToStringSingleQuote(filters.get('LIKE'), 'Name LIKE ', 'OR');
                
                
                // Step 4: Close OR portion of SOQL filter
                subTerritoryFilter += includeFilter + ')';
                System.debug('subTerritoryFilter after adding OR Name Like filter' + subTerritoryFilter);
            }
            
            // Add sub-territories of wildcarded incoming territories, incoming territores already filtered out
            for(Territory__c t : database.query(subTerritoryFilter)){
                if(!filters.containsKey('NOT IN')){
                    filters.put('NOT IN', new List<String>());
                }
                filters.get('NOT IN').add(t.Name);
            }
            
            System.debug('subTerritoryFilter = ' + subTerritoryFilter);
        }
        
        System.debug('filters values = ' + filters.keySet());
        for(String s : filters.keySet()){
            System.debug(s + ' size = ' + filters.get(s).size());
        }
        return filters;
    }
    
    private List<Account> findAccountsInTerritory(Map<String,List<String>> filterMap){
        String queryString = 'SELECT Id, BillingPostalCode, OwnerId FROM Account WHERE ';
        
        // Three potential filters:
        //      if only IN (no LIKEs): BillingPostalCode IN(12345,67890)
        //      if no IN: (BillingPostalCode LIKE '###%' AND BillingPostalCode NOT IN (<INs>,<NOT INs>) AND BillingPostalCode NOT LIKE '####%')
        //      if IN and LIKE: BillingPostalCode IN(12345,67890) OR ((BillingPostalCode LIKE '###%' AND BillingPostalCode NOT IN (<INs>,<NOT INs>) AND BillingPostalCode NOT LIKE '####%'))
        if(filterMap.containsKey('IN')){
            queryString += 'BillingPostalCode IN (' + Utils.listToStringSingleQuote(filterMap.get('IN')) + ')';
        }

        if(!filterMap.containsKey('LIKE')){
            // No LIKE values so close the IN statement & finished
            System.debug('No LIKE values, final queryString = ' + queryString);
        } else {
            if(filterMap.containsKey('IN')){
                // This case means there are IN and LIKEs, need to add the ' OR ' string
                queryString += ' OR ';
            }
            
            // add open parenthesis which groups the second part of the query
            queryString += '(';

            queryString += '(' + Utils.listToStringSingleQuote(filterMap.get('LIKE'), 'BillingPostalCode LIKE ', 'OR') + ')';
            System.debug('LIKE values PRESENT!!! ' + queryString);
            
            // Covers cases where IN and NOT INs are present
            if(filterMap.containsKey('IN') || filterMap.containsKey('NOT IN')){
                queryString += ' AND BillingPostalCode NOT IN (';
                if(filterMap.containsKey('IN)')){
                    queryString += Utils.listToStringSingleQuote(filterMap.get('IN'));
                } 
                if(filterMap.containsKey('NOT IN')){
                    queryString += Utils.listToStringSingleQuote(filterMap.get('NOT IN'));
                }
            queryString += ')';
            } 

            // Covers cases where NOT LIKEs are present
            if(filterMap.containsKey('NOT LIKE')){
                queryString += Utils.listToStringSingleQuote(filterMap.get('NOT LIKE'), 'BillingPostalCode NOT LIKE ', 'AND') + ')';
            }
            // add closing parenthesis which groups the second part of the query
            queryString += ')';
        }
        System.debug('final queryString: ' + queryString);        
        List<Account> accountsInTerritory = database.query(queryString);
        return accountsInTerritory;        
    }

    private void buildAccountByZipMap(List<Account> targetAccounts){        
        for(Account a : targetAccounts){
            String zip = expandWildCardZip(a.BillingPostalCode);
            Integer zipLength = zip.length();
            String matchingZip = zip; 
            // Continuously wildcard the BillingPostalCode until a match is found in TA Map
            // Eg: check 12345, then 1234*, then 123**, 12***, 1****
            for(Integer i = 4 ; i > 0; i--){ 
                // System.debug('checking TAmap for key ' + matchingZip);
                if(TAmap.containsKey(matchingZip)){
                    // System.debug('TAmap contains key for ' + matchingZip);
                    if(!accountByZipMap.containsKey(matchingZip)){
                        accountByZipMap.put(matchingZip,new List<Account>());
                    }
                    accountByZipMap.get(matchingZip).add(a);
                    break;
                } else {
                    // System.debug('TAmap does not contain key ' + matchingZip);
                    matchingZip = zip.left(i).rightPad(5,'*');
                    // System.debug('matchingZip updated to ' + matchingZip);
                }
            }
        }
    }
    
    private String expandWildcardZip(String zipcode){
        if(zipcode.contains('%')){
            zipcode = zipcode.substringBefore('%').rightPad(5,'*');
        }        
        return zipcode;
    }
    
    private void buildTAMap(List<Territory__c> territories){
        Set<Id> territoryIds = new Set<Id>();
        for(Territory__c t : territories){
            territoryIds.add(t.Id);
        }
        System.debug('territoryIds = ' + territoryIds);
        
        for(Territory_Assignment__c ta : [SELECT Id, Assignee__c, Territory__r.Name FROM Territory_assignment__c WHERE Territory__c IN :territoryIds]){
            String zip = expandWildcardZip(ta.Territory__r.Name);
            if (!TAmap.containsKey(zip)) {
                TAmap.put(zip, new Map<String,Map<String,Integer>>());
            }
            
            if (!TAmap.get(zip).containsKey(ta.Assignee__c)) {
                TAmap.get(zip).put(ta.Assignee__c, new Map<String,Integer>());
            }
            
            if(!TAmap.get(zip).get(ta.Assignee__c).containsKey('current')){
                TAmap.get(zip).get(ta.Assignee__c).put('current',0);
            }
        }
        System.debug('TAmap = ' + TAmap.toString());
        
    }
    
    private void identifyMisOwnedAccountsForZipCode(){
        // receives a single zip code in accountsByZipMap & identifies accounts with OwnerIds that are not a TA for that zip
        for(String zip : accountByZipMap.keySet()){
            System.debug('identifyMisOwnedAccountsForZipCode: processing zip = ' + zip);
            for(Account a : accountByZipMap.get(zip)){
                //System.debug('a.OwnerId = ' + a.OwnerId);
                String ownerId = (String) a.OwnerId;
                
                // Match the account's Billing Postal Code to a Zip Code in the TAmap map, also add the account to misOwnedAccounts list if the OwnerId doesn't match one of the Territory Assignments
                for(Integer i = 5 ; i > 0 ; i--){
                    String zipIteration = zip.left(i).rightpad(5,'*');
                    
                    // If this is true then this is the Zip Code iteration which matches the appropriate Territory
                    if(TAmap.containsKey(zipIteration)){
                        //System.debug('identifyMisOwnedAccountsForZipCode: matched zipIteration ' + zipIteration + ' with a TAmap key');
                        // If this is true then increase the TA's current value by 1, don't add the account to the misOwnedAccounts
                        if(TAmap.get(zipIteration).containsKey(ownerId)){
                            //System.debug('identifyMisOwnedAccountsForZipCode: account ' + a.Id + ' owner matched TA, increasing \'current \' value by 1');
                            Integer currentVal = TAmap.get(zipIteration).get(ownerId).get('current');
                            TAmap.get(zipIteration).get(ownerId).put('current',currentVal + 1);
                            System.debug('identifyMisOwnedAccountsForZipCode, Account ' + a.Id + ' matched a TA, not misOwned');
                            // break the loop, no need to continue looping through zipIterations
                            break;
                        } else {
                            // The account's OwnerId doesn't match a TA in this Territory, add to misOwnedAccounts
                            //System.debug('adding account ' + a.Id + ' to misOwnedAccounts map');
                            if(!misOwnedAccounts.containsKey(zipIteration)){
                                misOwnedAccounts.put(zipIteration, new List<Account>());
                            }
                            misOwnedAccounts.get(zipIteration).add(a);
                            // break the loop, no need to continue looping through zipIterations
                            break;
                        }
                        System.debug('identifyMisOwnedAccountsForZipCode, Account ' + a.Id + ' (BillingPostalCode: ' + a.BillingPostalCode + ') wasn\'t able to match a Territory.  Odd.....');
                    }
                    //System.debug('zipIteration didn\'t match on ' + zipIteration);
                }
            }
        }
    }
    
    private static Map<String,Integer> calculateCurrentAccountsByTA(Map<String,Map<String,Integer>> TAMapforZipCode){
        Map<String,Integer> currentByTA = new Map<String,Integer>();
        
        // Loop through the list of TA's for the zip code being processed
        for (String currentTA : TAMapforZipCode.keySet()) {
            CurrentByTA.put(currentTA,TAMapforZipCode.get(currentTA).get('current'));
        }
        
        return currentByTA;
    }
    
    private List<Account> assignMisOwnedAccountsForZipCode(Map<String,Map<String,Integer>> unsortedTAMap, String currentZipCode){
        // List of accounts with updated Owner ID
        List<Account> reassignedAccounts = new List<Account>();
        
        // Integer is the 'current' value & the String is the TA's Assignee value
        Map<Integer,List<String>> TAsByCurrent = new Map<Integer,List<String>>();
        List<Integer> currentValueList = new List<Integer>();
        
        
        // Generate the TAsByCurrent map & 
        // Generate currentValueList to process the TA's with the lowest 'current' value first
        System.debug('assignMisOwnedAccountsForZipCode, Processing TAs for ZipCode ' + currentZipCode);
        for(String TA : unsortedTAMap.keySet()){
            Integer TAcurrent = unsortedTAMap.get(TA).get('current');
            
            // Add the current TA's 'current' value and TA to TAsByCurrent map 
            if(!TAsByCurrent.containsKey(TAcurrent)){
                TAsByCurrent.put(TAcurrent, new List<String>());
            }
            TAsByCurrent.get(TAcurrent).add(TA);
            
            // Add the current TA's 'current' value to the currentValueList if not present
            if(!currentValueList.contains(TAcurrent)){
                currentValueList.add(TAcurrent);
            }
        }
        
        currentValueList.sort();
        System.debug('assignMisOwnedAccountsForZipCode, finished building TAsByCurrent map & currentValueList');
        System.debug('currentValueList = ' + currentValueList);
        System.debug('TAsByCurrent map = ' + TAsByCurrent);


        // Begin looping through CurrentValueList & re-assigning accounts
        // Derive the delta between the first value (minimum) & the 2nd (next minimum) value in the list
        List<Account> misOwnedAccountsForCurrentZip = misOwnedAccounts.get(currentZipCode);
        while (misOwnedAccountsForCurrentZip != null && misOwnedAccountsForCurrentZip.size() > 0) {
            System.debug('assignMisOwnedAccountsForZipCode, misOwnedAccountsForCurrentZip size = ' + misOwnedAccountsForCurrentZip.size());
            Integer lowerBound = currentValueList[0];
            Integer upperBound;
            Integer remainingAccounts = misOwnedAccountsForCurrentZip.size();
            
            // Derive the number of accounts that should be reassigned to bring the lowest 'current' value to the next highest value (see loopIterations value)
            // When the currentValueList size is greater than 1 use the value in index 1, else value of index 0 (lowerBound) 
            if(currentValueList.size() > 1){
                upperBound = currentValueList[1];
                System.debug('Setting upperBound based on currentValueList size');
            } else {
                upperBound = lowerBound;
                System.debug('Setting upperBound to match lowerBound as lowerBound is the last value in the currentValueList list');
            }
            System.debug('lowerBound = ' + lowerBound);
            System.debug('upperBound = ' + upperBound);
            System.debug('Zip = ' + currentZipCode);
            System.debug('remaining accounts for Zip ' + currentZipCode + ' = ' + remainingAccounts);
            Integer loopIterations;
            if(lowerBound == 0 && upperBound != 0){
                loopIterations = Math.min(upperBound, remainingAccounts);
            } else if(lowerBound == upperBound) {
                loopIterations = remainingAccounts;
            } else {
                loopIterations = Math.min((upperBound - lowerBound),remainingAccounts);
            }
            
            // Reassign mis-owned accounts to a list of rolling TA's in this 'current' range
            System.debug('loopIterations = ' + loopIterations);
            Integer assignToTAIndex = 0;
            for(Integer i = 0; i < loopIterations; i++){
                // maintains the rep in TAsByCurrent which will receive the next account.  Once the value is greater than the size of the TAsByCurrent list then reset to zero
                
                // reset to index 0 if assignToTAIndex is greater than the size of TA's in the list
                if(assignToTAIndex > (TAsByCurrent.get(lowerBound).size() -1)){
                    assignToTAIndex = 0;
                }
                
                String assignTAID = TAsByCurrent.get(lowerBound)[assignToTAIndex];
                //System.debug('Assigning the next account to ' + assignTAID + '(Index ' + assignToTAIndex + ')');
                
                // get the next misOwner account from the list, set the new owner ID, then remove the account from the list
                Account reassignAcc = misOwnedAccountsForCurrentZip[0];
                reassignAcc.OwnerId = assignTAID;
                misOwnedAccountsForCurrentZip.remove(0);
                //System.debug('Account ' + reassignAcc.Id + ' reassigned to ' + assignTAID);
                // Add the account to the reassignedAccounts List
                reassignedAccounts.add(reassignAcc);
                assignToTAIndex++;
            }
            // the current lowerBound has been made equal with the next bound.  Remove the lowerBound from the list (index 0) & move the TA's in the current lower bound to the next bound 
            currentValueList.remove(0);
            System.debug('Finished assigning accounts for currentValueList value ' + lowerBound);
            TAsByCurrent.get(upperBound).addAll(TAsByCurrent.get(lowerBound));
            System.debug('Moved all TAs in ' + lowerBound + ' to ' + upperbound + '. upperBound list is now' + TAsByCurrent.get(upperBound));
        }
        
        System.debug('returning ' + reassignedAccounts.size() + ' accounts');
        return reassignedAccounts;
    }
}