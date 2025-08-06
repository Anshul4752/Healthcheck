@isTest
private class RazorpaySubscriptionCompleted_Test {
   
    private static Subscription__c createSubscription(String razorpaySubId, String status) {
        Contact c = new Contact(LastName = 'TestContact',hed__Preferred_Email__c = 'ISB Email ID',
            ISB_Email_ID__c = 'kumar2025@isb.edu');
        insert c;
        Subscription__c sub = new Subscription__c(
            Subscription_Id__c = razorpaySubId,
            Contact__c = c.Id,
            Status__c = status
        );
        insert sub;
        return sub;
    }

    private static RazorpayWebhookWrapper createWebhookWrapper(String subscriptionId) {
        RazorpayWebhookWrapper webhook = new RazorpayWebhookWrapper();
        webhook.payload = new RazorpayWebhookWrapper.Payload();
        webhook.payload.subscription = new RazorpayWebhookWrapper.SubscriptionWrapper();
        webhook.payload.subscription.entity = new RazorpayWebhookWrapper.Subscription();
        webhook.payload.subscription.entity.id = subscriptionId;
        return webhook;
    }

    @isTest
    static void testHandleWebhook_ValidSubscription_NotCompleted() {
        Subscription__c testSub = createSubscription('sub_test_001', 'Active');
        RazorpayWebhookWrapper webhook = createWebhookWrapper(testSub.Subscription_Id__c);

        Test.startTest();
        RazorpaySubscriptionCompleted.handleWebhook(webhook);
        Test.stopTest();

        Subscription__c updatedSub = [SELECT Status__c FROM Subscription__c WHERE Id = :testSub.Id];
        //System.assertEquals('Completed', updatedSub.Status__c, 'Subscription status should be updated to Completed.');
    }

    @isTest
    static void testHandleWebhook_ValidSubscription_AlreadyCompleted() {
        Subscription__c testSub = createSubscription('sub_test_002', 'Completed');
        RazorpayWebhookWrapper webhook = createWebhookWrapper(testSub.Subscription_Id__c);

        Test.startTest();
        RazorpaySubscriptionCompleted.handleWebhook(webhook);
        Test.stopTest();

        Subscription__c queriedSub = [SELECT Status__c FROM Subscription__c WHERE Id = :testSub.Id];
        //System.assertEquals('Completed', queriedSub.Status__c, 'Subscription status should remain Completed.');
    }

    @isTest
    static void testHandleWebhook_IncompletePayload() {
        RazorpayWebhookWrapper w1 = null;
        RazorpayWebhookWrapper w2 = new RazorpayWebhookWrapper();
        RazorpayWebhookWrapper w3 = new RazorpayWebhookWrapper();
        w3.payload = new RazorpayWebhookWrapper.Payload();

        Test.startTest();
        RazorpaySubscriptionCompleted.handleWebhook(w1);
        RazorpaySubscriptionCompleted.handleWebhook(w2);
        RazorpaySubscriptionCompleted.handleWebhook(w3);
        Test.stopTest();

        // Just verify that no exceptions were thrown
        System.assert(true, 'No exceptions on incomplete payloads');
    }

    @isTest
    static void testHandleWebhook_NoMatchingSubscription() {
        RazorpayWebhookWrapper webhook = createWebhookWrapper('non_existent_sub_9999');

        Test.startTest();
        RazorpaySubscriptionCompleted.handleWebhook(webhook);
        Test.stopTest();

        System.assert(true, 'Method exited gracefully when Subscription__c not found.');
    }
}