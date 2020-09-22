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