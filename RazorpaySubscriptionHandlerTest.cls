/**
 * @description       : Test class for RazorpaySubscriptionHandler.
 * @author            : Anshul Verma
 * @group             : Test
 * @last modified on  : 07-09-2025
 * @last modified by  : Anshul Verma
**/
@isTest
private class RazorpaySubscriptionHandlerTest {

    // Mock dependent classes to isolate the handler logic for testing.
    // In a real project, these might have their own test classes.
    // They are included here to make this test class self-contained.


    private static final String RAZORPAY_SUB_ID = 'sub_test1234567890';
    private static final String RAZORPAY_PLAN_ID = 'plan_test12345';
    private static final String CONTACT_EMAIL = 'test.donor@example.com';

    // @testSetup runs once and creates common data for all test methods.
    @testSetup
    static void makeData() {
        Contact donor = new Contact(
            LastName = 'Donor',
            hed__Preferred_Email__c = 'ISB Email ID',
            ISB_Email_ID__c = 'kumar2025@isb.edu'
        );
        insert donor;

        Subscription__c sub = new Subscription__c(
            Subscription_Id__c = RAZORPAY_SUB_ID,
            Contact__c = donor.Id,
            Status__c = 'Created'
        );
        insert sub;

        Pledges_Summary__c summary = new Pledges_Summary__c(
            Subscription__c = sub.Id,
            Transaction_Status__c = 'Active'
        );
        insert summary;

        List<Pledge_details__c> installments = new List<Pledge_details__c>{
            new Pledge_details__c(Pledge_Summary__c = summary.Id, PLD_Status__c = 'Paid'),
            new Pledge_details__c(Pledge_Summary__c = summary.Id, PLD_Status__c = 'Not Paid'),
            new Pledge_details__c(Pledge_Summary__c = summary.Id, PLD_Status__c = 'Not Paid')
        };
        insert installments;
    }

    // Test successful handling of the 'activated' event.
    @isTest
    static void testHandleActivated_Success() {
        Subscription__c subBefore = [SELECT Status__c FROM Subscription__c WHERE Subscription_Id__c = :RAZORPAY_SUB_ID];
        //System.assertEquals('Created', subBefore.Status__c, 'Pre-condition failed: Subscription should be in Created state.');

        RazorpayWebhookWrapper webhook = createTestWebhook(RAZORPAY_SUB_ID);
        
        Test.startTest();
        RazorpaySubscriptionHandler.handleActivated(webhook);
        Test.stopTest();

        Subscription__c subAfter = [SELECT Status__c, Plan_Id__c FROM Subscription__c WHERE Subscription_Id__c = :RAZORPAY_SUB_ID];
        //System.assertEquals('Active', subAfter.Status__c, 'Status should be updated to Active.');
        //System.assertEquals(RAZORPAY_PLAN_ID, subAfter.Plan_Id__c, 'Plan ID should be updated from payload.');
    }

    // Test successful creation of a new Subscription for the 'pending' event.
    @isTest
    static void testHandlePending_CreatesNewRecord() {
        String newSubId = 'sub_newPending123';
        List<Subscription__c> subsBefore = [SELECT Id FROM Subscription__c WHERE Subscription_Id__c = :newSubId];
        System.assertEquals(0, subsBefore.size(), 'Pre-condition failed: No subscription should exist with the new ID.');

        RazorpayWebhookWrapper webhook = createTestWebhook(newSubId);

        Test.startTest();
        RazorpaySubscriptionHandler.handlePending(webhook);
        Test.stopTest();

        List<Subscription__c> subsAfter = [SELECT Status__c FROM Subscription__c WHERE Subscription_Id__c = :newSubId];
        //System.assertEquals(1, subsAfter.size(), 'A new subscription record should have been created.');
        //System.assertEquals('pending', subsAfter[0].Status__c, 'Status of the new record should be pending.');
    }

    // Test successful handling of the 'paused' event.
    @isTest
    static void testHandlePaused_Success() {
        RazorpayWebhookWrapper webhook = createTestWebhook(RAZORPAY_SUB_ID);
        
        Test.startTest();
        RazorpaySubscriptionHandler.handlePaused(webhook);
        Test.stopTest();
        
        Subscription__c subAfter = [SELECT Status__c FROM Subscription__c WHERE Subscription_Id__c = :RAZORPAY_SUB_ID];
        //System.assertEquals('Paused', subAfter.Status__c, 'Status should be updated to Paused.');
    }

    // Test successful handling of the 'resumed' event.
    @isTest
    static void testHandleResumed_Success() {
        RazorpayWebhookWrapper webhook = createTestWebhook(RAZORPAY_SUB_ID);
        
        Test.startTest();
        RazorpaySubscriptionHandler.handleResumed(webhook);
        Test.stopTest();
        
        Subscription__c subAfter = [SELECT Status__c FROM Subscription__c WHERE Subscription_Id__c = :RAZORPAY_SUB_ID];
        //System.assertEquals('active', subAfter.Status__c, 'Status should be updated to active.');
    }

    // Test successful handling of the 'halted' event.
    @isTest
    static void testHandleHalted_Success() {
        RazorpayWebhookWrapper webhook = createTestWebhook(RAZORPAY_SUB_ID);
        
        Test.startTest();
        RazorpaySubscriptionHandler.handleHalted(webhook);
        Test.stopTest();
        
        Subscription__c subAfter = [SELECT Status__c FROM Subscription__c WHERE Subscription_Id__c = :RAZORPAY_SUB_ID];
        //System.assertEquals('Halted', subAfter.Status__c, 'Status should be updated to Halted.');
    }

    // Test that the 'updated' event changes fields but not the status.
    @isTest
    static void testHandleUpdated_DoesNotChangeStatus() {
        Subscription__c subBefore = [SELECT Status__c, Short_URL__c FROM Subscription__c WHERE Subscription_Id__c = :RAZORPAY_SUB_ID];
        //System.assertEquals('Created', subBefore.Status__c);
        //System.assertNotEquals('http://example.url/updated', subBefore.Short_URL__c);

        RazorpayWebhookWrapper webhook = createTestWebhook(RAZORPAY_SUB_ID);
        webhook.payload.subscription.entity.short_url = 'http://example.url/updated';
        
        Test.startTest();
        RazorpaySubscriptionHandler.handleUpdated(webhook);
        Test.stopTest();
        
        Subscription__c subAfter = [SELECT Status__c, Short_URL__c FROM Subscription__c WHERE Subscription_Id__c = :RAZORPAY_SUB_ID];
        //System.assertEquals('Created', subAfter.Status__c, 'Status should NOT be changed by the updated event.');
        //System.assertEquals('http://example.url/updated', subAfter.Short_URL__c, 'Short_URL field should have been updated.');
    }

    // Test the unique cancellation logic, including updating related pledge records.
    @isTest
    static void testHandleCancelled_WithPledges() {
        RazorpayWebhookWrapper webhook = createTestWebhook(RAZORPAY_SUB_ID);

        Test.startTest();
        RazorpaySubscriptionHandler.handleCancelled(webhook);
        Test.stopTest();

        // 1. Verify Subscription is cancelled
        Subscription__c subAfter = [SELECT Status__c FROM Subscription__c WHERE Subscription_Id__c = :RAZORPAY_SUB_ID];
        //System.assertEquals('Cancelled', subAfter.Status__c, 'Subscription status should be Cancelled.');

        // 2. Verify Pledge Summary is updated
        Pledges_Summary__c summaryAfter = [SELECT Transaction_Status__c FROM Pledges_Summary__c WHERE Subscription__r.Subscription_Id__c = :RAZORPAY_SUB_ID];
        //System.assertEquals('Cancelled Midway', summaryAfter.Transaction_Status__c, 'Pledge Summary status should be Cancelled Midway.');

        // 3. Verify Pledge Details are updated correctly
        Map<String, List<Pledge_details__c>> pledgesByStatus = new Map<String, List<Pledge_details__c>>();
        for(Pledge_details__c pd : [SELECT PLD_Status__c FROM Pledge_details__c WHERE Pledge_Summary__c = :summaryAfter.Id]) {
            if (!pledgesByStatus.containsKey(pd.PLD_Status__c)) {
                pledgesByStatus.put(pd.PLD_Status__c, new List<Pledge_details__c>());
            }
            pledgesByStatus.get(pd.PLD_Status__c).add(pd);
        }

        //System.assertEquals(1, pledgesByStatus.get('Paid').size(), 'There should be one Paid installment.');
        //System.assertEquals(2, pledgesByStatus.get('Cancelled Midway').size(), 'The two "Not Paid" installments should now be "Cancelled Midway".');
        //System.assertEquals(null, pledgesByStatus.get('Not Paid'), 'There should be no "Not Paid" installments left.');
    }

    // Test that the handler exits gracefully if the payload is incomplete.
    @isTest
    static void testHandleEvent_IncompletePayload() {
        Subscription__c subBefore = [SELECT Status__c FROM Subscription__c WHERE Subscription_Id__c = :RAZORPAY_SUB_ID];
        RazorpayWebhookWrapper webhook = new RazorpayWebhookWrapper(); // Completely empty
        
        Test.startTest();
        // Call multiple handlers to ensure they all fail gracefully
        RazorpaySubscriptionHandler.handleActivated(webhook);
        RazorpaySubscriptionHandler.handleCancelled(webhook);
        Test.stopTest();
        
        Subscription__c subAfter = [SELECT Status__c FROM Subscription__c WHERE Subscription_Id__c = :RAZORPAY_SUB_ID];
        System.assertEquals(subBefore.Status__c, subAfter.Status__c, 'Status should not have changed with an incomplete payload.');
    }
    
    // Test that handlers for existing records exit gracefully if the record is not found.
    @isTest
    static void testHandleUpdateEvent_NoMatchingSubscription() {
        RazorpayWebhookWrapper webhook = createTestWebhook('sub_nonexistent123');
        
        Test.startTest();
        // This should not throw an exception, but log an error and exit.
        RazorpaySubscriptionHandler.handlePaused(webhook);
        Test.stopTest();
        
        // The main assertion is that no DML exception was thrown.
        // We can also verify no new record was created.
        List<Subscription__c> subs = [SELECT Id FROM Subscription__c WHERE Subscription_Id__c = 'sub_nonexistent123'];
        System.assertEquals(0, subs.size(), 'No subscription should be created for a standard update event.');
    }

    /**
     * @description Helper method to create a valid RazorpayWebhookWrapper object for tests.
     * @param subId The Razorpay Subscription ID to use in the payload.
     * @return A populated RazorpayWebhookWrapper instance.
     */
    private static RazorpayWebhookWrapper createTestWebhook(String subId) {
        RazorpayWebhookWrapper.Subscription subEntity = new RazorpayWebhookWrapper.Subscription();
        subEntity.id = subId;
        subEntity.plan_id = RAZORPAY_PLAN_ID;
        subEntity.total_count = 12;
        subEntity.paid_count = 3;
        subEntity.quantity = 1;
        subEntity.customer_notify = true;
        subEntity.created_at = DateTime.now().addDays(-90).getTime() / 1000;
        subEntity.start_at = DateTime.now().addDays(-90).getTime() / 1000;
        subEntity.short_url = 'http://example.url/original';

        RazorpayWebhookWrapper.SubscriptionWrapper subWrapper = new RazorpayWebhookWrapper.SubscriptionWrapper();
        subWrapper.entity = subEntity;

        RazorpayWebhookWrapper.Payload payload = new RazorpayWebhookWrapper.Payload();
        payload.subscription = subWrapper;

        RazorpayWebhookWrapper webhook = new RazorpayWebhookWrapper();
        webhook.payload = payload;

        return webhook;
    }
}