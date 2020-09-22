# 🏆[Apex Specialist](https://trailhead.salesforce.com/en/content/learn/superbadges/superbadge_apex)

## 如何赚取此超级徽章

1. 使用Apex触发器自动创建记录(`Apex triggers`)
2. 使用异步REST标注将Salesforce数据与外部系统同步(`REST callouts`)
3. 使用Apex代码安排同步(`Schedule synchronization`)
4. 测试自动化逻辑以确认Apex触发副作用(`Test automation logic`)
5. 使用标注模拟测试集成逻辑(`Test integration logic`)
6. 测试调度逻辑以确认操作已排队(`Test scheduling logic`)

## 实体图

![Entity Diagram - Vehicle, Case, Work Part, Product](assets/c029d98dfdb478da2673ceb187a78fef_image_0.png)

## 1️⃣Step1 **Automate record creation**

```java
trigger MaintenanceRequest on Case (before update, after update) {
    // ToDo: Call MaintenanceRequestHelper.updateWorkOrders
    if(Trigger.isAfter && Trigger.isUpdate){
        MaintenanceRequestHelper.updateWorkOrders(Trigger.New);
    }
}
```

```java
public with sharing class MaintenanceRequestHelper {
    public static void updateWorkOrders(List<Case> caseList) {
        List<case> newCases = new List<Case>();
        Map<String,Integer> result=getDueDate(caseList);
        for(Case c : caseList){
            if(c.status=='closed')
                if(c.type=='Repair' || c.type=='Routine Maintenance'){
                    Case newCase = new Case();
                    newCase.Status='New';
                    newCase.Origin='web';
                    newCase.Type='Routine Maintenance';
                    newCase.Subject='Routine Maintenance of Vehicle';
                    newCase.Vehicle__c=c.Vehicle__c;
                    newCase.Equipment__c=c.Equipment__c;
                    newCase.Date_Reported__c=Date.today();
                    if(result.get(c.Id)!=null)
                        newCase.Date_Due__c=Date.today()+result.get(c.Id);
                    else
                        newCase.Date_Due__c=Date.today();
                    newCases.add(newCase);
                }
        }
        insert newCases;
    }
    //
    public static  Map<String,Integer> getDueDate(List<case> CaseIDs){
        Map<String,Integer> result = new Map<String,Integer>();
        Map<Id, case> caseKeys = new Map<Id, case> (CaseIDs);
        List<AggregateResult> wpc=[select Maintenance_Request__r.ID cID,min(Equipment__r.Maintenance_Cycle__c)cycle
                                   from Work_Part__c where  Maintenance_Request__r.ID in :caseKeys.keySet() group by             Maintenance_Request__r.ID ];
        for(AggregateResult res :wpc){
            Integer addDays=0;
            if(res.get('cycle')!=null)
                addDays+=Integer.valueOf(res.get('cycle'));
            result.put((String)res.get('cID'),addDays);
        }
        return result;
    }
    
}
```

## 2️⃣Step2 **Synchronize Salesforce data with an external system**

```java
public with sharing class WarehouseCalloutService {
    
    private static final String WAREHOUSE_URL = 'https://th-superbadge-apex.herokuapp.com/equipment';
    
    @future(callout=true)
    public static void runWarehouseEquipmentSync() {
        //ToDo: complete this method to make the callout (using @future) to the
        //      REST endpoint and update equipment on hand.
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(WAREHOUSE_URL);
        request.setMethod('GET');
        HttpResponse response = http.send(request);
        // If the request is successful, parse the JSON response.
        if (response.getStatusCode() == 200) {
            // Deserialize the JSON string into collections of primitive data types.
            List<Object> equipments = (List<Object>) JSON.deserializeUntyped(response.getBody());
            List<Product2> products = new List<Product2>();
            for(Object o :  equipments){
                Map<String, Object> mapProduct = (Map<String, Object>)o;
                Product2 product = new Product2();
                product.Name = (String)mapProduct.get('name');
                product.Cost__c = (Integer)mapProduct.get('cost');
                product.Current_Inventory__c = (Integer)mapProduct.get('quantity');
                product.Maintenance_Cycle__c = (Integer)mapProduct.get('maintenanceperiod');
                product.Replacement_Part__c = (Boolean)mapProduct.get('replacement');
                product.Lifespan_Months__c = (Integer)mapProduct.get('lifespan');
                product.Warehouse_SKU__c = (String)mapProduct.get('sku');
                product.ProductCode = (String)mapProduct.get('_id');
                products.add(product);
            }
            if(products.size() > 0){
                System.debug(products);
                upsert products;
            }
        }
    }
}
```

## **3️⃣Schedule synchronization**

```java
global class WarehouseSyncSchedule implements Schedulable{
    // implement scheduled code here
    global void execute(SchedulableContext ctx){
        WarehouseCalloutService.runWarehouseEquipmentSync();
    }
}
```

### Scheduling a Job from the UI

You can also schedule a class using the user interface.

1. From Setup, enter Apex in the Quick Find box, then select **Apex Classes**.
2. Click **Schedule Apex**.
3. For the job name, enter something like Daily Oppty Reminder.
4. Click the lookup button next to Apex class and enter * for the search term to get a list of all classes that can be scheduled. In the search results, click the name of your scheduled class.
5. Select Weekly or Monthly for the frequency and set the frequency desired.
6. Select the start and end dates, and a preferred start time.
7. Click **Save**.

## 4️⃣**Test automation logic**

```java
@isTest
public  class MaintenanceRequestTest {
    static  List<Case> caseList1 = new List<Case>();
    static List<Product2> prodList = new List<Product2>();
    static List<Work_Part__c> wpList = new List<Work_Part__c>();
    @testSetup
    static void getData(){
        caseList1= CreateData(300,3,3,'Repair');
    }
    
    public static List<Case>   CreateData( Integer numOfcase, Integer numofProd, Integer numofVehicle,
                                          String type){
                                              List<Case> caseList = new List<Case>();
                                              //Create Vehicle
                                              Vehicle__c vc = new Vehicle__c();
                                              vc.name='Test Vehicle';
                                              upsert vc;
                                              //Create Equiment
                                              for(Integer i=0;i<numofProd;i++){
                                                  Product2 prod = new Product2();
                                                  prod.Name='Test Product'+i;
                                                  if(i!=0)
                                                      prod.Maintenance_Cycle__c=i;
                                                  prod.Replacement_Part__c=true;
                                                  prodList.add(prod);
                                              }
                                              upsert  prodlist;
                                              //Create Case
                                              for(Integer i=0;i< numOfcase;i++){
                                                  Case newCase = new Case();
                                                  newCase.Status='New';
                                                  newCase.Origin='web';
                                                  if( math.mod(i, 2) ==0)
                                                      newCase.Type='Routine Maintenance';
                                                  else
                                                      newCase.Type='Repair';
                                                  newCase.Subject='Routine Maintenance of Vehicle' +i;
                                                  newCase.Vehicle__c=vc.Id;
                                                  if(i<numofProd)
                                                      newCase.Equipment__c=prodList.get(i).ID;
                                                  else
                                                      newCase.Equipment__c=prodList.get(0).ID;
                                                  caseList.add(newCase);
                                              }
                                              upsert caseList;
                                              for(Integer i=0;i<numofProd;i++){
                                                  Work_Part__c wp = new Work_Part__c();
                                                  wp.Equipment__c   =prodlist.get(i).Id   ;
                                                  wp.Maintenance_Request__c=caseList.get(i).id;
                                                  wplist.add(wp) ;
                                              }
                                              upsert wplist;
                                              return caseList;
                                          }
    
    public static testmethod void testMaintenanceHelper(){
        Test.startTest();
        getData();
        for(Case cas: caseList1)
            cas.Status ='Closed';
        update caseList1;
        Test.stopTest();
    }
    
}
```

## 5️⃣**Test callout logic**

## 5️⃣**Test scheduling logic**