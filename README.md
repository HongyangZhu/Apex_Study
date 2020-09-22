# Apex_Study
基于Salesforce平台

- [My Profile](https://trailblazer.me/id/hongyangzhu)
- [TrailHead](https://trailhead.salesforce.com/home)
- 🏆[Apex Specialist](markdown/ApexSpecialist.md)

[TOC]

# [Developer Intermediate](https://trailhead.salesforce.com/en/content/learn/trails/force_com_dev_intermediate)

## [Asynchronous Apex](https://trailhead.salesforce.com/en/content/learn/modules/asynchronous_apex?trail_id=force_com_dev_intermediate)

### [Use Future Methods](https://trailhead.salesforce.com/en/content/learn/modules/asynchronous_apex/async_apex_future_methods?trail_id=force_com_dev_intermediate)

#### 🎯Challenge

```java
public class AccountProcessor {
    /**
     * 方法必须是静态方法，并且只能返回一个 void 类型
     * 指定的参数必须是基元数据类型、基元数据类型数组或基元数据类型集合
     * 不能使用标准或自定义对象作为参数
     */
    @future
    public static void countContacts(Set<id> setid) {
        List<Account> listAccount=[SELECT Id,Number_of_contacts__c,
                                    (SELECT id From contacts)
                                    From Account
                                    where id =:setid
                                    ];
        for (Account acc : listAccount) {
            List<Contact> listContact=acc.contacts;
            acc.Number_of_contacts__c=listContact.size();
        }
        update listAccount;
    }
}
```

```java

```



### [Use Batch Apex](https://trailhead.salesforce.com/en/content/learn/modules/asynchronous_apex/async_apex_batch?trail_id=force_com_dev_intermediate)

#### 🎯Challenge

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



### [Control Processes with Queueable Apex](https://trailhead.salesforce.com/en/content/learn/modules/asynchronous_apex/async_apex_queueable?trail_id=force_com_dev_intermediate)

#### 🔖Queueable Syntax

要使用排队顶点，只需实现`Queueable`(排队接口)。

```java
public class SomeClass implements Queueable { 
    public void execute(QueueableContext context) {
        // awesome code here
    }
}
```

#### 🔖Sample Code

下面的代码获取一个 Account 记录集合，为每个记录设置 parentId，然后更新数据库中的记录。

```java
public class UpdateParentAccount implements Queueable {
    
    private List<Account> accounts;
    private ID parent;
    
    public UpdateParentAccount(List<Account> records, ID id) {
        this.accounts = records;
        this.parent = id;
    }
    public void execute(QueueableContext context) {
        for (Account account : accounts) {
          account.parentId = parent;
          // perform other processing or callout
        }
        update accounts;
    }
    
}
```

要将此类添加为队列中的作业，请执行以下代码:

```java
// find all accounts in ‘NY’
List<Account> accounts = [select id from account where billingstate = ‘NY’];
// find a specific parent account for all records
Id parentId = [select id from account where name = 'ACME Corp'][0].Id;
// instantiate a new instance of the Queueable class
UpdateParentAccount updateJob = new UpdateParentAccount(accounts, parentId);
// enqueue the job for processing
ID jobID = System.enqueueJob(updateJob);
```

可以使用新的作业 ID 来监视进度，或者通过 Apex Jobs 页面，或者通过程序查询 AsyncApexJob:

```sql
SELECT Id, Status, NumberOfErrors FROM AsyncApexJob WHERE Id = :jobID
```

#### 🔖Testing Queueable Apex 

```java
@isTest
public class UpdateParentAccountTest {
    @testSetup 
    static void setup() {
        List<Account> accounts = new List<Account>();
        // add a parent account
        accounts.add(new Account(name='Parent'));
        // add 100 child accounts
        for (Integer i = 0; i < 100; i++) {
            accounts.add(new Account(
                name='Test Account'+i
            ));
        }
        insert accounts;
    }
    
    static testmethod void testQueueable() {
        // query for test data to pass to queueable class
        Id parentId = [select id from account where name = 'Parent'][0].Id;
        List<Account> accounts = [select id, name from account where name like 'Test Account%'];
        // Create our Queueable instance
        UpdateParentAccount updater = new UpdateParentAccount(accounts, parentId);
        // startTest/stopTest block to force async processes to run
        Test.startTest();        
        System.enqueueJob(updater);
        Test.stopTest();        
        // Validate the job ran. Check if record have correct parentId now
        System.assertEquals(100, [select count() from account where parentId = :parentId]);
    }
    
}
```

#### 🎯Challenge

**创建一个可排队的 Apex 类，该类为特定状态的每个帐户插入相同的 Contact**

- 创建一个名为“ AddPrimaryContact”的 Apex 类，该类实现了 queuable 接口
- 为类创建一个构造函数，该类接受 Contact sObject 作为其第一个参数，接受第二个参数作为 State 缩写的字符串
- Execute 方法必须使用传递到构造函数的 State 缩写指定的 BillingState 查询最多200个 Account，并插入与每个 Account 关联的 Contact sObject 记录。查看 sObject clone ()方法
- 创建一个名为 AddPrimaryContactTest 的 Apex 测试类
- 在测试类中，为 BillingState“ NY”插入50个 Account 记录，为 BillingState“ CA”插入50个 Account 记录。创建 AddPrimaryContact 类的一个实例，对作业进行排队，并断言为每个50个帐户插入了带有“ CA”的 BillingState 的 Contact 记录

```java
public class AddPrimaryContact implements Queueable{
    private Contact c;
    private String state;
    public AddPrimaryContact(Contact c, String state)
    {
        this.c = c;
        this.state = state;
    }
    public void execute(QueueableContext context) {
        List<Account> ListAccount = [SELECT ID, Name ,
                                     (Select id,FirstName,LastName from contacts ) 
                                     FROM ACCOUNT 
                                     WHERE BillingState = :state LIMIT 200];
        List<Contact> lstContact = new List<Contact>();
        for (Account acc:ListAccount)
        {
            Contact cont = c.clone(false,false,false,false);
            cont.AccountId =  acc.id;
            lstContact.add( cont );
        }
        
        if(lstContact.size() >0 )
        {
            insert lstContact;
        }
    }
}
```

```java
@isTest
public class AddPrimaryContactTest {
    
    @isTest static void testQueueable(){
        //<-----@testSetup
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 50; i++){accounts.add(new Account(name = 'acc' + i, BillingState = 'NY')); }
        for (Integer i = 50; i < 100; i++){accounts.add(new Account(name = 'acc' + i, BillingState = 'CA')); }
        insert accounts;
        
        String strState = 'CA';
        Contact cont = new Contact(LastName = 'TstsName');
        AddPrimaryContact updater = new AddPrimaryContact(cont, strState);
        //<-----@testSetup
        
        //<-----@testExecution
        Test.startTest();
        System.enqueueJob(updater);
        Test.stopTest();
        //<-----@testExecution
        
        //<-----@testResult
        System.assertEquals(50, [select count() from Contact where accountID IN (SELECT id FROM Account WHERE BillingState = :strState)]);   
        //<-----@testResult
    }
}
```



### [Schedule Jobs Using the Apex Scheduler](https://trailhead.salesforce.com/en/content/learn/modules/asynchronous_apex/async_apex_scheduled?trail_id=force_com_dev_intermediate)

#### 🔖Scheduled Syntax

要调用 Apex 类在特定时间运行，首先实现该类的 `schedable` 接口。然后，使用 `System.schedule` 方法安排类的实例在特定时间运行。

```java
global class SomeClass implements Schedulable {
    global void execute(SchedulableContext ctx) {
        // awesome code here
    }
}
```

该类实现`Schedulable`接口，并且必须实现该接口包含的唯一方法，即 `execute` 方法。

此方法的参数是 `schedableecontext` 对象。在调度了一个类之后，将创建一个 `CronTrigger` 对象来表示调度的作业。它提供了一个 `getTriggerId` 方法，该方法返回 `CronTrigger` API 对象的 ID。

#### 🔖Sample Code

该类查询本应在当前日期前关闭的开放机会，并在每个机会上创建一个任务，以提醒所有者更新机会。

```java
global class RemindOpptyOwners implements Schedulable {
    global void execute(SchedulableContext ctx) {
        List<Opportunity> opptys = [SELECT Id, Name, OwnerId, CloseDate 
                                    FROM Opportunity 
                                    WHERE IsClosed = False AND 
                                    CloseDate < TODAY];
        // Create a task for each opportunity in the list
        TaskUtils.remindOwners(opptys);
    }
    
}
```

调用方法：

```java
RemindOpptyOwners reminder = new RemindOpptyOwners();
// Seconds Minutes Hours Day_of_month Month Day_of_week optional_year
String sch = '20 30 8 10 2 ?';
String jobID = System.schedule('Remind Opp Owners', sch, reminder);
```

Schedule 方法有三个参数: 

1. 作业的名称
2. 用于表示计划运行作业的时间和日期的 CRON 表达式
3. 类的名称。

#### 🔖Testing Scheduled Apex

```java
@isTest
private class RemindOppyOwnersTest {
    // Dummy CRON expression: midnight on March 15.
    // Because this is a test, job executes
    // immediately after Test.stopTest().
    public static String CRON_EXP = '0 0 0 15 3 ? 2022';
    static testmethod void testScheduledJob() {
        // Create some out of date Opportunity records
        List<Opportunity> opptys = new List<Opportunity>();
        Date closeDate = Date.today().addDays(-7);
        for (Integer i=0; i<10; i++) {
            Opportunity o = new Opportunity(
                Name = 'Opportunity ' + i,
                CloseDate = closeDate,
                StageName = 'Prospecting'
            );
            opptys.add(o);
        }
        insert opptys;
        
        // Get the IDs of the opportunities we just inserted
        Map<Id, Opportunity> opptyMap = new Map<Id, Opportunity>(opptys);
        List<Id> opptyIds = new List<Id>(opptyMap.keySet());
        Test.startTest();
        // Schedule the test job
        String jobId = System.schedule('ScheduledApexTest',
            CRON_EXP, 
            new RemindOpptyOwners());         
        // Verify the scheduled job has not run yet.
        List<Task> lt = [SELECT Id 
            FROM Task 
            WHERE WhatId IN :opptyIds];
        System.assertEquals(0, lt.size(), 'Tasks exist before job has run');
        // Stopping the test will run the job synchronously
        Test.stopTest();
        
        // Now that the scheduled job has executed,
        // check that our tasks were created
        lt = [SELECT Id 
            FROM Task 
            WHERE WhatId IN :opptyIds];
        System.assertEquals(opptyIds.size(), 
            lt.size(), 
            'Tasks were not created');
    }
}
```

#### 🎯Challenge

创建一个实现可调度接口的 Apex 类，使用特定的 LeadSource 更新 Lead 记录。

- 创建一个名为`DailyLeadProcessor`的 Apex 类，该类使用可调度接口
-  Execute 方法必须找到带有空白 LeadSource 字段的前200个 Leads，并用 'Dreamforce'的 LeadSource 值更新它们
- 创建一个名为 DailyLeadProcessorTest 的 Apex 测试类
- 在测试类中，插入200 Lead 记录，安排 DailyLeadProcessor 类运行并测试所有 Lead 记录是否被正确更新

```java
global  class DailyLeadProcessor implements Schedulable {
    global void execute(SchedulableContext ctx){
        List<Lead> listLead = [Select Id, LeadSource 
                               from Lead where LeadSource = null];
        if (listLead.size()!=0) {
            for(Lead l:listLead){
                l.LeadSource='Dreamforce';
            }
            update listLead;
        }
        
    }
}
```

```java
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
```

