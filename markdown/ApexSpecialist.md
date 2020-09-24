# 🏆[Apex Specialist](https://trailhead.salesforce.com/en/content/learn/superbadges/superbadge_apex)

![](assets/Snipaste_2020-09-24_16-32-49.png)

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

    @future( callout = true )
    public static void runWarehouseEquipmentSync() {
        
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        HTTPResponse response = new HTTPResponse();
        
        request.setEndpoint( WAREHOUSE_URL );
        request.setMethod( 'GET' );
        request.setHeader( 'Content-Type', 'text-xml' );
        response = http.send( request );
        
        List<WarehouseEquipment> warehouseEquipmentList = new WarehouseEquipment().parse( response.getBody() );
        List<Product2> productsToUpsert = new List<Product2>();
        
        // Update Salesforce Records
        for ( WarehouseEquipment whrEquip : warehouseEquipmentList ) {
            Product2 newProduct = new Product2( Warehouse_SKU__c  = whrEquip.id );
            newProduct.Replacement_Part__c = true;
            newProduct.Cost__c = whrEquip.cost;
            newProduct.Current_Inventory__c = whrEquip.quantity;
            newProduct.Lifespan_Months__c = whrEquip.lifespan;
            newProduct.Maintenance_Cycle__c = whrEquip.maintenanceperiod;
            newProduct.Name = whrEquip.name; 
            productsToUpsert.add( newProduct );
        }

        upsert productsToUpsert;
    }
    
    public class WarehouseEquipment {
        public String name;
        public Boolean replacement;
        public Integer quantity;
        public Integer maintenanceperiod;
        public Integer lifespan;
        public Integer cost;
        public String sku;
        public String id;
        
        public List<WarehouseEquipment> parse( String json ) {
            json.replace( '"id":', '"_id ":' );
            return ( List<WarehouseEquipment> ) System.JSON.deserialize( json, List<WarehouseEquipment>.class );
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

```java
@isTest
global class WarehouseCalloutServiceMock implements HttpCalloutMock {
    global HTTPResponse respond(HTTPRequest request) {
        HttpResponse response = new HttpResponse();
        response.setHeader('Content-Type', 'text-xml');
        response.setBody(getJsonResponse());
        response.setStatusCode(200);
        return response;
    }
    
    public String getJsonResponse() {
        return '[{"_id":"55d66226726b611100aaf741","replacement":false,"quantity":5,"name":"Generator 1000 kW","maintenanceperiod":365,"lifespan":120,"cost":5000,' +
         '"sku":"100003"},{"_id":"55d66226726b611100aaf742","replacement":true,"quantity":183,"name":"Cooling Fan","maintenanceperiod":0,"lifespan":0,"cost":300,' +
         '"sku":"100004"},{"_id":"55d66226726b611100aaf743","replacement":true,"quantity":143,"name":"Fuse 20A","maintenanceperiod":0,"lifespan":0,"cost":22, ' +
         '"sku":"100005"},{"_id":"55d66226726b611100aaf744","replacement":false,"quantity":5,"name":"Generator 2000 kw","maintenanceperiod":365,"lifespan":120,"cost":6000, '+
         '"sku":"100006"},{"_id":"55d66226726b611100aaf745","replacement":true,"quantity":142,"name":"Fuse 25A","maintenanceperiod":0,"lifespan":0,"cost":28,' +
         '"sku":"100007"},{"_id":"55d66226726b611100aaf746","replacement":true,"quantity":122,"name":"Fuse 13A","maintenanceperiod":0,"lifespan":0,"cost":10, '+
         '"sku":"100008"},{"_id":"55d66226726b611100aaf747","replacement":true,"quantity":90,"name":"Ball Valve 10 cm","maintenanceperiod":0,"lifespan":0,"cost":50,'+
         '"sku":"100009"},{"_id":"55d66226726b611100aaf748","replacement":false,"quantity":2,"name":"Converter","maintenanceperiod":180,"lifespan":120,"cost":3000, '+
         '"sku":"100010"},{"_id":"55d66226726b611100aaf749","replacement":true,"quantity":75,"name":"Ball Valve 8 cm","maintenanceperiod":0,"lifespan":0,"cost":42,'+
         '"sku":"100011"},{"_id":"55d66226726b611100aaf74a","replacement":true,"quantity":100,"name":"Breaker 25A","maintenanceperiod":0,"lifespan":0,"cost":30,'+
         '"sku":"100012"},{"_id":"55d66226726b611100aaf74b","replacement":true,"quantity":150,"name":"Switch","maintenanceperiod":0,"lifespan":0,"cost":100, '+
         '"sku":"100013"},{"_id":"55d66226726b611100aaf74c","replacement":true,"quantity":200,"name":"Ball Valve 5 cm","maintenanceperiod":0,"lifespan":0,"cost":30, '+
         '"sku":"100014"},{"_id":"55d66226726b611100aaf74d","replacement":false,"quantity":8,"name":"UPS 3000 VA","maintenanceperiod":180,"lifespan":60,"cost":1600,'+
         '"sku":"100015"},{"_id":"55d66226726b611100aaf74e","replacement":false,"quantity":10,"name":"UPS 1000 VA","maintenanceperiod":180,"lifespan":48,"cost":1000,'+
         '"sku":"100016"},{"_id":"55d66226726b611100aaf74f","replacement":true,"quantity":180,"name":"Breaker 8A","maintenanceperiod":0,"lifespan":0,"cost":10,'+
         '"sku":"100017"},{"_id":"55d66226726b611100aaf750","replacement":false,"quantity":2,"name":"Cooling Tower","maintenanceperiod":365,"lifespan":120,"cost":10000,'+
         '"sku":"100018"},{"_id":"55d66226726b611100aaf751","replacement":true,"quantity":165,"name":"Motor","maintenanceperiod":0,"lifespan":0,"cost":150,'+
         '"sku":"100019"},{"_id":"55d66226726b611100aaf752","replacement":true,"quantity":210,"name":"Breaker 13A","maintenanceperiod":0,"lifespan":0,"cost":20,'+
         '"sku":"100020"},{"_id":"55d66226726b611100aaf753","replacement":true,"quantity":100,"name":"Radiator Pump","maintenanceperiod":0,"lifespan":0,"cost":500, '+
         '"sku":"100021"},{"_id":"55d66226726b611100aaf754","replacement":true,"quantity":129,"name":"Breaker 20A","maintenanceperiod":0,"lifespan":0,"cost":25,'+
         '"sku":"100022"},{"_id":"55d66226726b611100aaf73f","replacement":false,"quantity":10,"name":"UPS 2000 VA","maintenanceperiod":180,"lifespan":60,"cost":1350, '+
         '"sku":"100001"},{"_id":"55d66226726b611100aaf740","replacement":true,"quantity":194,"name":"Fuse 8A","maintenanceperiod":0,"lifespan":0,"cost":5,"sku":"100002"}]';
    }
}
```

```java
@isTest
private class WarehouseCalloutServiceTest {
    
    @isTest static  void warehouseServiceTest() {
        Test.startTest();
        Test.SetMock(HttpCallOutMock.class, new WarehouseCalloutServiceMock());
        
        WarehouseCalloutService.runWarehouseEquipmentSync();
        
        List<Product2> productsToUpsert = [SELECT Replacement_Part__c, Cost__c, Current_Inventory__c, Lifespan_Months__c,
                                           Maintenance_Cycle__c, Name FROM Product2];
        
        System.assert( true, productsToUpsert.size() == 22 );
        
        // Update Salesforce Records
        for ( Product2 equipmentUpserted : productsToUpsert ) {
            System.assert( true, equipmentUpserted.Replacement_Part__c );
            System.assert( true, equipmentUpserted.Cost__c != null );
            System.assert( true, equipmentUpserted.Current_Inventory__c != null );
            System.assert( true, equipmentUpserted.Lifespan_Months__c != null );
            System.assert( true, equipmentUpserted.Maintenance_Cycle__c != null );
            System.assert( true, equipmentUpserted.Name != null );
        }
        
        Test.stopTest();
    }
}
```



## 6️⃣**Test scheduling logic**

```java
@isTest
private class WarehouseSyncScheduleTest {
    public static String CRON_EXP = '0 0 0 15 3 ? 2022';
    
    static testmethod void testjob(){
        MaintenanceRequestTest.CreateData( 5,2,2,'Repair');
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new WarehouseCalloutServiceMock());
        String joBID= System.schedule('TestScheduleJob', CRON_EXP, new WarehouseSyncSchedule());
        // List<Case> caselist = [Select count(id) from case where case]
        Test.stopTest();
    }
}
```

