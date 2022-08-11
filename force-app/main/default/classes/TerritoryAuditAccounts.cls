public class TerritoryAuditAccounts implements Schedulable {

/* How to schedule the job: 
TerritoryAuditAccounts s = new TerritoryAuditAccounts();
String sch = '0 0 0 * * ?	';
String jobID = system.schedule('Territory Audit Accounts', sch, s);
*/

    public void execute(SchedulableContext SC) {
        Database.executeBatch(new TerritoryAuditAccountsBatchable(), 200);
    }
}