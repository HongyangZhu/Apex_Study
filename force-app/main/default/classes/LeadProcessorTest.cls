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