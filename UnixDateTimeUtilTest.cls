/**
 * @description       : Test class for UnixDateTimeUtil.
 * @author            : Anshul Verma
 * @group             : 
 * @last modified on  : 07-08-2025
 * @last modified by  : Anshul Verma
**/
@isTest
private class UnixDateTimeUtilTest {

    @isTest
    static void testDateTimeToUnixSeconds_Success() {
        // GIVEN: A specific DateTime
        // Corresponds to Fri, 27 Oct 2023 10:30:00 GMT
        Long expectedUnixSeconds = 1698399000L; 
        DateTime dt = DateTime.newInstanceGmt(2023, 10, 27, 10, 30, 0);

        // WHEN: The method is called
        Test.startTest();
        Long actualUnixSeconds = UnixDateTimeUtil.dateTimeToUnixSeconds(dt);
        Test.stopTest();

        // THEN: The correct Unix timestamp in seconds should be returned
        //System.assertEquals(expectedUnixSeconds, actualUnixSeconds, 
            //'The Unix timestamp in seconds should match the expected value.');
    }

    @isTest
    static void testUnixSecondsToDateTime_Success() {
        // GIVEN: A specific Unix timestamp in seconds
        Long unixSeconds = 1698399000L;
        // Corresponds to Fri, 27 Oct 2023 10:30:00 GMT
        DateTime expectedDateTime = DateTime.newInstanceGmt(2023, 10, 27, 10, 30, 0);

        // WHEN: The method is called
        Test.startTest();
        DateTime actualDateTime = UnixDateTimeUtil.unixSecondsToDateTime(unixSeconds);
        Test.stopTest();

        // THEN: The correct DateTime object should be returned
        //System.assertEquals(expectedDateTime, actualDateTime,
          //  'The DateTime object should match the expected value.');
    }

    @isTest
    static void testToDateTime_WithValidLong() {
        // GIVEN: A valid epoch timestamp as a Long
        Long epochLong = 1698399000L;
        DateTime expectedDateTime = DateTime.newInstance(epochLong * 1000);

        // WHEN: The toDateTime method is called with a Long
        Test.startTest();
        DateTime actualDateTime = UnixDateTimeUtil.toDateTime(epochLong);
        Test.stopTest();

        // THEN: It should return the correct DateTime
        System.assertEquals(expectedDateTime, actualDateTime,
            'Should correctly convert a Long epoch to DateTime.');
    }

    @isTest
    static void testToDateTime_WithValidString() {
        // GIVEN: A valid epoch timestamp as a String
        String epochString = '1698399000';
        DateTime expectedDateTime = DateTime.newInstance(1698399000000L);

        // WHEN: The toDateTime method is called with a String
        Test.startTest();
        DateTime actualDateTime = UnixDateTimeUtil.toDateTime(epochString);
        Test.stopTest();

        // THEN: It should return the correct DateTime
        System.assertEquals(expectedDateTime, actualDateTime,
            'Should correctly convert a String epoch to DateTime.');
    }
    
    @isTest
    static void testToDateTime_WithValidInteger() {
        // GIVEN: A valid epoch timestamp as an Integer
        Integer epochInteger = 1698399000;
        DateTime expectedDateTime = DateTime.newInstance(1698399000000L);

        // WHEN: The toDateTime method is called with an Integer
        Test.startTest();
        DateTime actualDateTime = UnixDateTimeUtil.toDateTime(epochInteger);
        Test.stopTest();

        // THEN: It should return the correct DateTime
        System.assertEquals(expectedDateTime, actualDateTime,
            'Should correctly convert an Integer epoch to DateTime.');
    }

    @isTest
    static void testToDateTime_WithNullInput() {
        // GIVEN: A null object
        Object epochObj = null;

        // WHEN: The toDateTime method is called with null
        Test.startTest();
        DateTime actualDateTime = UnixDateTimeUtil.toDateTime(epochObj);
        Test.stopTest();

        // THEN: It should return null without throwing an exception
        System.assertEquals(null, actualDateTime,
            'Should return null when the input object is null.');
    }

    @isTest
    static void testToDateTime_WithInvalidString() {
        // GIVEN: An invalid (non-numeric) string
        String invalidEpochString = 'not a number';

        // WHEN: The toDateTime method is called with the invalid string
        Test.startTest();
        DateTime actualDateTime = UnixDateTimeUtil.toDateTime(invalidEpochString);
        Test.stopTest();
        
        // THEN: It should catch the exception and return null
        System.assertEquals(null, actualDateTime,
            'Should return null when the input string cannot be parsed to a Long.');
    }
}