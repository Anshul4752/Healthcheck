/**
 * @description       : Test class for the RazorpaySubCtrl Visualforce controller.
 * @author            : Anshul Verma
 * @group             : 
 * @last modified on  : 07-09-2025
 * @last modified by  : Anshul Verma
**/
@isTest
private class RazorpaySubCtrlTest {

    @isTest
    static void testControllerInitialization_WithParameters() {
        PageReference pageRef = new PageReference('/apex/YourPageName');
        Test.setCurrentPage(pageRef);
        
        // Add the 'subscriptionId' parameter to the current page's context
        String testSubscriptionId = 'sub_HkyT4g6aToIndex';
        ApexPages.currentPage().getParameters().put('subscriptionId', testSubscriptionId);

        // WHEN: The controller is instantiated, which calls the constructor
        Test.startTest();
        RazorpaySubCtrl controller = new RazorpaySubCtrl();
        Test.stopTest();

        // THEN: Verify that the controller's properties are initialized correctly
        
        // 1. Verify subscriptionId was captured from the URL parameter
        System.assertEquals(testSubscriptionId, controller.subscriptionId, 
            'The subscriptionId property should be set from the URL parameter.');

        // 2. Verify properties are set from Custom Labels
        System.assertEquals(System.Label.RazorPayUsername, controller.razorPayUserName,
            'The razorPayUserName property should be set from the custom label.');
        System.assertEquals(System.Label.Razorpay_Subscriptions_Callback_URL, controller.callbackUrl,
            'The callbackUrl property should be set from the custom label.');

        // 3. Verify contactId is null because the code to set it is commented out
        System.assertEquals(null, controller.contactId, 
            'The contactId property should be null.');
    }

    @isTest
    static void testControllerInitialization_WithoutParameters() {
        // GIVEN: A mock PageReference with no URL parameters.
        PageReference pageRef = new PageReference('/apex/YourPageName');
        Test.setCurrentPage(pageRef);

        // WHEN: The controller is instantiated
        Test.startTest();
        RazorpaySubCtrl controller = new RazorpaySubCtrl();
        Test.stopTest();

        // THEN: Verify that properties are initialized as expected
        
        // 1. subscriptionId should be null because it was not in the URL
        System.assertEquals(null, controller.subscriptionId, 
            'The subscriptionId property should be null when not provided in the URL.');

        // 2. Custom label properties should still be set
        System.assertEquals(System.Label.RazorPayUsername, controller.razorPayUserName,
            'The razorPayUserName property should still be set from the custom label.');
        System.assertEquals(System.Label.Razorpay_Subscriptions_Callback_URL, controller.callbackUrl,
            'The callbackUrl property should still be set from the custom label.');
    }
}