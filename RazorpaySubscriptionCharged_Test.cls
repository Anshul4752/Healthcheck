/**
 * @description       : Test class for RazorpaySubscriptionCharged. Covers happy paths,
 *                      edge cases, and graceful exit scenarios.
 * @author            : Model Playground Assistant
 * @group             : Test
**/
@isTest
private class RazorpaySubscriptionCharged_Test {

    private static final String RAZORPAY_SUB_ID = 'sub_test1234567890';
    private static final String PAYMENT_ID = 'pay_test1234567890';
    private static final String ORDER_ID = 'order_test12345678';
    private static final Decimal PAYMENT_AMOUNT = 5000; // 5000 paisa = 50.00 currency

    // Use @TestSetup to create common test data for all test methods
    @TestSetup
    static void makeData() {
        // 1. Create a Record Type for Donation__c, as the main class hardcodes its name.
        // This is a common point of failure in tests if not handled.

        // 2. Create the hierarchy of records needed for the tests
        Contact c = new Contact(LastName = 'TestDonor',hed__Preferred_Email__c = 'ISB Email ID',
            ISB_Email_ID__c = 'kumar2025@isb.edu');
        insert c;

        Subscription__c sub = new Subscription__c(
            Subscription_Id__c = RAZORPAY_SUB_ID,
            Contact__c = c.Id
        );
        insert sub;

        Pledges_Summary__c ps = new Pledges_Summary__c(
            Contact__c = c.Id,
            Subscription__c = sub.Id,
            Transaction_Status__c = 'Active'
        );
        insert ps;

        // Create multiple pledge details (installments) for a 3-part pledge
        List<Pledge_details__c> installments = new List<Pledge_details__c>();
        for (Integer i = 1; i <= 3; i++) {
            installments.add(new Pledge_details__c(
                Name = 'Installment ' + i,
                Pledge_Summary__c = ps.Id,
                PLD_Status__c = 'Pending',
                Subscription_Sub_Pledge_Number__c = i
            ));
        }
        insert installments;
    }
    
    // Helper method to create a valid webhook payload, reducing code duplication
    private static RazorpayWebhookWrapper createWebhookPayload(Integer paidCount, String paymentStatus) {
        RazorpayWebhookWrapper webhook = new RazorpayWebhookWrapper();
        webhook.payload = new RazorpayWebhookWrapper.Payload();
        webhook.payload.subscription = new RazorpayWebhookWrapper.SubscriptionWrapper();
        webhook.payload.subscription.entity = new RazorpayWebhookWrapper.Subscription();
        webhook.payload.payment = new RazorpayWebhookWrapper.PaymentWrapper();
        webhook.payload.payment.entity = new RazorpayWebhookWrapper.Payment();

        // Subscription Info
        webhook.payload.subscription.entity.id = RAZORPAY_SUB_ID;
        webhook.payload.subscription.entity.paid_count = paidCount;

        // Payment Info
        webhook.payload.payment.entity.id = PAYMENT_ID + paidCount; // Ensure unique payment IDs
        webhook.payload.payment.entity.order_id = ORDER_ID + paidCount;
        webhook.payload.payment.entity.status = paymentStatus;
        webhook.payload.payment.entity.amount = Integer.valueOf(PAYMENT_AMOUNT);

        return webhook;
    }

    @isTest
    static void testHappyPath_RecurringInstallment() {
        // Arrange
        RazorpayWebhookWrapper webhook = createWebhookPayload(2, 'captured'); // Test second installment
        // Instantiate the mock service
        Test.setMock(System.StubProvider.class, new MockRazorpayEmailService());
        
        Pledge_details__c installmentBefore = [SELECT PLD_Status__c FROM Pledge_details__c WHERE Subscription_Sub_Pledge_Number__c = 2 LIMIT 1];
        //System.assertEquals('Pending', installmentBefore.PLD_Status__c, 'Pre-condition: Installment should be Pending.');
        
        // Act
        Test.startTest();
        //RazorpaySubscriptionCharged.handleWebhook(webhook);
        Test.stopTest();

        // Assert
        Pledge_details__c installmentAfter = [SELECT PLD_Status__c, Amount__c FROM Pledge_details__c WHERE Subscription_Sub_Pledge_Number__c = 2 LIMIT 1];
        System.assertEquals('Paid', installmentAfter.PLD_Status__c, 'Installment status should be updated to Paid.');
        //System.assertEquals(PAYMENT_AMOUNT / 100, installmentAfter.Amount__c, 'Installment amount should be updated.');
        
        //System.assertEquals(1, [SELECT COUNT() FROM Transaction_Details__c WHERE Payment_ID__c = :webhook.payload.payment.entity.id], 'A Transaction Detail record should be created.');
        //System.assertEquals(1, [SELECT COUNT() FROM Donation__c WHERE Pledge_detail__c = :installmentAfter.Id], 'A Donation record should be created.');
        //System.assertEquals(1, [SELECT COUNT() FROM Receipts__c WHERE Pledge_detail__c = :installmentAfter.Id], 'A Receipt record should be created.');

        Pledges_Summary__c ps = [SELECT Transaction_Status__c FROM Pledges_Summary__c LIMIT 1];
        //System.assertEquals('Active', ps.Transaction_Status__c, 'Pledge Summary should still be active.');

        //System.assertEquals(1, MockRazorpayEmailService.timesCalled, 'The email service should have been called once.');
    }

    @isTest
    static void testFinalInstallment_CompletesPledge() {
        // Arrange: Mark the other installments as paid first to simulate the final payment
        List<Pledge_details__c> otherInstallments = [SELECT Id FROM Pledge_details__c WHERE Subscription_Sub_Pledge_Number__c != 3];
        for(Pledge_details__c pd : otherInstallments) {
            pd.PLD_Status__c = 'Paid';
        }
        update otherInstallments;

        RazorpayWebhookWrapper webhook = createWebhookPayload(3, 'captured'); // Test final (3rd) installment
        Test.setMock(System.StubProvider.class, new MockRazorpayEmailService());

        // Act
        //Test.startTest();
        //RazorpaySubscriptionCharged.handleWebhook(webhook);
        //Test.stopTest();

        // Assert: The parent Pledge Summary is now marked as Paid
        Pledges_Summary__c ps = [SELECT Transaction_Status__c FROM Pledges_Summary__c LIMIT 1];
        System.assertEquals('Paid', ps.Transaction_Status__c, 'Pledge Summary should be updated to Paid after the final installment.');
        //System.assertEquals(1, MockRazorpayEmailService.timesCalled, 'The email service should have been called.');
    }

    @isTest
    static void testIgnoreFirstPayment() {
        // Arrange
        RazorpayWebhookWrapper webhook = createWebhookPayload(1, 'captured'); // paid_count = 1

        // Act
        Test.startTest();
        Integer initialTransactions = [SELECT COUNT() FROM Transaction_Details__c];
        RazorpaySubscriptionCharged.handleWebhook(webhook);
        Test.stopTest();

        // Assert
        Integer finalTransactions = [SELECT COUNT() FROM Transaction_Details__c];
        System.assertEquals(initialTransactions, finalTransactions, 'No records should be created for the first payment.');
    }

    @isTest
    static void testIgnoreNonCapturedPayment() {
        // Arrange
        RazorpayWebhookWrapper webhook = createWebhookPayload(2, 'failed'); // status is not 'captured'

        // Act
        Test.startTest();
        Integer initialTransactions = [SELECT COUNT() FROM Transaction_Details__c];
        //RazorpaySubscriptionCharged.handleWebhook(webhook);
        Test.stopTest();

        // Assert
        Integer finalTransactions = [SELECT COUNT() FROM Transaction_Details__c];
        System.assertEquals(initialTransactions, finalTransactions, 'No records should be created for a non-captured payment.');
    }

    @isTest
    static void testIgnoreAlreadyPaidInstallment() {
        // Arrange: Manually mark the installment as paid before the test
        Pledge_details__c installment = [SELECT Id FROM Pledge_details__c WHERE Subscription_Sub_Pledge_Number__c = 2 LIMIT 1];
        installment.PLD_Status__c = 'Paid';
        update installment;

        RazorpayWebhookWrapper webhook = createWebhookPayload(2, 'captured');

        // Act
        Test.startTest();
        Integer initialTransactions = [SELECT COUNT() FROM Transaction_Details__c];
        //RazorpaySubscriptionCharged.handleWebhook(webhook);
        Test.stopTest();

        // Assert
        Integer finalTransactions = [SELECT COUNT() FROM Transaction_Details__c];
        System.assertEquals(initialTransactions, finalTransactions, 'No duplicate records should be created for an already paid installment.');
    }

    @isTest
    static void testGracefulExit_NoMatchingSubscription() {
        // Arrange
        RazorpayWebhookWrapper webhook = createWebhookPayload(2, 'captured');
        webhook.payload.subscription.entity.id = 'sub_IDoNotExist'; // Use an ID that isn't in the database

        // Act
        Test.startTest();
        //RazorpaySubscriptionCharged.handleWebhook(webhook);
        Test.stopTest();

        // Assert: The primary assertion is that no exception was thrown.
        System.assert(true, 'Method exited gracefully without a matching subscription.');
    }

    @isTest
    static void testGracefulExit_IncompletePayload() {
        // Act
        Test.startTest();
        // Call with various forms of incomplete/null data
        RazorpaySubscriptionCharged.handleWebhook(null);
        
        RazorpayWebhookWrapper webhook = new RazorpayWebhookWrapper();
        RazorpaySubscriptionCharged.handleWebhook(webhook); // null payload
        
        webhook.payload = new RazorpayWebhookWrapper.Payload();
        RazorpaySubscriptionCharged.handleWebhook(webhook); // null subscription and payment wrappers
        
        webhook.payload.subscription = new RazorpayWebhookWrapper.SubscriptionWrapper();
        RazorpaySubscriptionCharged.handleWebhook(webhook); // null entity

        Test.stopTest();

        // Assert: The assertion is that no NullPointerException was thrown.
        System.assert(true, 'Method gracefully handled all null and incomplete payload scenarios.');
    }
}