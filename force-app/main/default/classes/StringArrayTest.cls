/**
* Create an Apex class with a method 
* that returns an array (or list) of strings.
* Create an Apex class with a method 
* that returns an array (or list) of formatted strings ('Test 0', 'Test 1', ...). 
* The length of the array is determined by an integer parameter.
*/
public class StringArrayTest {
    public static String[] generateStringArray(Integer num) {
        List<String> str = new String[num];
        for (Integer i = 0; i < num; i++) {
            str.add('Test '+i);
        }
        return str;
        
    }
}