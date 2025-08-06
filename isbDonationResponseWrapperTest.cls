/**
 * @description       : 
 * @author            : Jatin Prasad
 * @group             : 
 * @last modified on  : 07-14-2025
 * @last modified by  : Jatin Prasad
**/
@isTest
public class isbDonationResponseWrapperTest {

    @isTest
    static void testWrapperClass() {
        // Instantiate the wrapper class
        isbDonationResponseWrapper responseWrapper = new isbDonationResponseWrapper();
        
        // Set values
        responseWrapper.shortURL = 'https://example.com/payment';
        responseWrapper.subscriptionId = 'sub_987654321';
        responseWrapper.isNewSubscription = false;
        
        // Validate the values
        System.assertEquals('https://example.com/payment', responseWrapper.shortURL);
        System.assertEquals('sub_987654321', responseWrapper.subscriptionId);
        System.assertEquals(false, responseWrapper.isNewSubscription);
    }
}