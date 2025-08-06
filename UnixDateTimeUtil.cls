/**
 * @description       : 
 * @author            : Anshul Verma
 * @group             : 
 * @last modified on  : 07-08-2025
 * @last modified by  : Anshul Verma
**/
public class UnixDateTimeUtil {
    public static Long dateTimeToUnixSeconds(DateTime dt) {
        return dt.getTime() / 1000;
    }
    public static DateTime unixSecondsToDateTime(Long seconds) {
        Long ms = seconds * 1000;
        return DateTime.newInstance(ms);
    }
    public static DateTime toDateTime(Object epochObj) {
        if (epochObj == null) return null;
        try {
            Long epoch = (epochObj instanceof Long) ? (Long)epochObj : Long.valueOf(String.valueOf(epochObj));
            return DateTime.newInstance(epoch * 1000);
        } catch (Exception e) {
            System.debug('RazorpaySubscription INFO: Could not parse epoch value: ' + epochObj);
            return null;
        }
    }
    
}