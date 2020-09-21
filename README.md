# Apex_Study
基于Salesforce平台

[My Profile](https://trailblazer.me/id/hongyangzhu)

[TrailHead](https://trailhead.salesforce.com/home)

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

```

```java

```

