public with sharing class AccountHandler {
    public static Account insertNewAccount(String acctName) {
        Account acc = new Account(Name = acctName);

        try {
            insert acc;
            return acc;
        } catch (Exception e) {
            return null;
        }

    

    }
}