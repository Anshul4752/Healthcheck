/**
 * @description       : Test class for RazorpaySubscriptionAuthentication.
 * @author            : Anshul Verma
 * @group             : Test
 * @last modified on  : 07-08-2025
 * @last modified by  : Anshul Verma
**/
@isTest
    private class RazorpaySubscriptionAuthenticationTest {

    /**
     * @description Test the happy path where a valid webhook is received for an existing subscription.
     *              It verifies that the subscription record is updated correctly.
     */
    @isTest
    static void testHandleWebhook_Success_UpdateSubscription() {
        // 1. Setup: Create prerequisite data
        Contact testContact = new Contact(LastName = 'Test',hed__Preferred_Email__c = 'ISB Email ID',
            ISB_Email_ID__c = 'kumar2025@isb.edu');
        insert testContact;

        String razorpaySubId = 'sub_xxxxxxxxxxxxxx';
        Subscription__c sub = new Subscription__c(
            Subscription_Id__c = razorpaySubId,
            Status__c = 'created',
            Auth_Attempts__c = 0,
            Customer_Notify__c = false,
            Contact__c = testContact.Id
        );
        insert sub;

        // Create the mock webhook payload
        RazorpayWebhookWrapper webhook = new RazorpayWebhookWrapper();
        webhook.payload = new RazorpayWebhookWrapper.Payload();
        webhook.payload.subscription = new RazorpayWebhookWrapper.SubscriptionWrapper();
        webhook.payload.subscription.entity = new RazorpayWebhookWrapper.Subscription();
        
        webhook.payload.subscription.entity.id = razorpaySubId;
        webhook.payload.subscription.entity.auth_attempts = 3;
        webhook.payload.subscription.entity.customer_notify = true;
        webhook.payload.subscription.entity.status = 'authenticated'; // Even though this field is commented out in the main class, we include it for completeness.

        // 2. Execute: Call the method to be tested
        Test.startTest();
        RazorpaySubscriptionAuthentication.handleWebhook(webhook);
        Test.stopTest();

        // 3. Verify: Assert that the record was updated as expected
        Subscription__c updatedSub = [SELECT Id, Auth_Attempts__c, Customer_Notify__c, Status__c FROM Subscription__c WHERE Id = :sub.Id];

        System.assertEquals(3, updatedSub.Auth_Attempts__c, 'Auth Attempts should be updated.');
        System.assertEquals(true, updatedSub.Customer_Notify__c, 'Customer Notify should be updated.');
        // The Status__c field is commented out in the main class, so we assert it was NOT changed.
        System.assertEquals('created', updatedSub.Status__c, 'Status should not have changed.');
    }

    /**
     * @description Test the scenario where a webhook is received for a subscription ID
     *              that does not exist in Salesforce. The method should exit gracefully.
     */
    @isTest
    static void testHandleWebhook_NoMatchingSubscription() {
        // 1. Setup: Create a webhook payload for a non-existent subscription
        String nonExistentSubId = 'sub_nonexistent123';
        RazorpayWebhookWrapper webhook = new RazorpayWebhookWrapper();
        webhook.payload = new RazorpayWebhookWrapper.Payload();
        webhook.payload.subscription = new RazorpayWebhookWrapper.SubscriptionWrapper();
        webhook.payload.subscription.entity = new RazorpayWebhookWrapper.Subscription();
        webhook.payload.subscription.entity.id = nonExistentSubId;

        // 2. Execute: Call the method
        Test.startTest();
        // We expect this to run without throwing any exceptions
        RazorpaySubscriptionAuthentication.handleWebhook(webhook);
        Test.stopTest();

        // 3. Verify: Assert that no new subscription records were created or updated
        List<Subscription__c> subs = [SELECT Id FROM Subscription__c WHERE Subscription_Id__c = :nonExistentSubId];
        System.assertEquals(0, subs.size(), 'No subscription should be found or created.');
    }

    /**
     * @description Tests that the method handles various null or incomplete inputs
     *              without throwing a NullPointerException.
     */
    @isTest
    static void testHandleWebhook_NullAndEmptyInputs() {
        // Start the test context
        Test.startTest();

        // Test with a completely null webhook
        RazorpaySubscriptionAuthentication.handleWebhook(null);

        // Test with a webhook that has a null payload
        RazorpayWebhookWrapper webhookWithNullPayload = new RazorpayWebhookWrapper();
        webhookWithNullPayload.payload = null;
        RazorpaySubscriptionAuthentication.handleWebhook(webhookWithNullPayload);

        // Test with a webhook that has a null subscription object
        RazorpayWebhookWrapper webhookWithNullSub = new RazorpayWebhookWrapper();
        webhookWithNullSub.payload = new RazorpayWebhookWrapper.Payload();
        webhookWithNullSub.payload.subscription = null;
        RazorpaySubscriptionAuthentication.handleWebhook(webhookWithNullSub);
        
        // Test with a webhook that has a null entity object
        RazorpayWebhookWrapper webhookWithNullEntity = new RazorpayWebhookWrapper();
        webhookWithNullEntity.payload = new RazorpayWebhookWrapper.Payload();
        webhookWithNullEntity.payload.subscription = new RazorpayWebhookWrapper.SubscriptionWrapper();
        webhookWithNullEntity.payload.subscription.entity = null;
        RazorpaySubscriptionAuthentication.handleWebhook(webhookWithNullEntity);

        // Stop the test context
        Test.stopTest();

        // The assertion is that no exceptions were thrown, which means the test passes if it completes.
        // We can add a dummy assertion for clarity.
        System.assert(true, 'The method gracefully handled all null input scenarios.');
    }
}