@isTest
public  class DailyLeadProcessorTest {
    public static String CRON_EXP = '0 0 1 * * ?';
    static testmethod void testScheduledJob() {
        // Create some out of date Lead records
        List<Lead> Leads = new List<Lead>();
        for (Integer i=0; i<200; i++) {
            Lead l = new Lead(
                Firstname = 'Lead' + i,
                LastName= 'LastName' + i,
                Company= 'TestCompany'
            );
            Leads.add(l);
        }
        insert Leads;
        
        Test.startTest();
        String jobId = System.schedule('DailyLeadProcessor', CRON_EXP,new DailyLeadProcessor());
        Test.stopTest();
    }
}