global  class DailyLeadProcessor implements Schedulable {
    global void execute(SchedulableContext ctx){
        List<Lead> listLead = [Select Id, LeadSource from Lead where LeadSource = null];
        if (listLead.size()!=0) {
            for(Lead l:listLead){
                l.LeadSource='Dreamforce';
            }
            update listLead;
        }
        
    }
}