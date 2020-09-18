# Apex_Study
基于Salesforce平台

[My Profile](https://trailblazer.me/id/hongyangzhu)

[TrailHead](https://trailhead.salesforce.com/home)

## Batch Apex Challenge Code

```java
global class LeadProcessor implements Database.Batchable<SObject>{
    // instance member to retain state across transactions
    global Integer recordsProcessed = 0;
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator('Select id ,LeadSource from lead'); 
        }
    global void execute(Database.BatchableContext bc, List<Lead> scope){
        // process each batch of records
        List<Lead> leads = new List<Lead>();
        for (Lead lead : scope) {
            if (lead.LeadSource =='Dreamforce') {
                leads.add(lead);
                // increment the instance member counter
                recordsProcessed = recordsProcessed + 1;
            }
        }
        update leads;
    }    
    global void finish(Database.BatchableContext bc){
        System.debug(recordsProcessed + ' records processed. Shazam!');
        AsyncApexJob job = [SELECT Id, Status, NumberOfErrors, 
            JobItemsProcessed,
            TotalJobItems, CreatedBy.Email
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()];
        // call some utility to send email
    }    
}
```

```java
@isTest
private class LeadProcessorTest {
    @testSetup 
    static void setup() {
        List<Lead> leads = new List<Lead>();
        //insert 200 Lead records
        for (Integer i=0;i<200;i++) {
            leads.add(new Lead(FirstName='FirstName '+i, LastName='LastName'+i,
                               Company='Test',
                               LeadSource  = 'Dreamforce'));
        }
        insert leads;
    }
    static testmethod void test() {
        Test.startTest();
        LeadProcessor LeadP = new LeadProcessor();
        Id batchId = Database.executeBatch(LeadP);
        Test.stopTest();
        // after the testing stops, assert records were updated properly
        System.assertEquals(200,
                            [select count() from Lead where LeadSource  = 'Dreamforce']);
    }
}
```

