@isTest
private class RazorpayWebhookWrapperTest {
    @isTest
    static void testRazorpayWebhookWrapper() {
        RazorpayWebhookWrapper wrapper = new RazorpayWebhookWrapper();
        wrapper.entity = 'event';
        wrapper.account_id = 'acc_test_123';
        wrapper.event = 'subscription.activated';
        wrapper.contains = new List<String>{'subscription', 'payment'};
        wrapper.created_at = 1650000000;

        RazorpayWebhookWrapper.Payload payload = new RazorpayWebhookWrapper.Payload();
        RazorpayWebhookWrapper.SubscriptionWrapper subscriptionWrapper = new RazorpayWebhookWrapper.SubscriptionWrapper();
        RazorpayWebhookWrapper.PaymentWrapper paymentWrapper = new RazorpayWebhookWrapper.PaymentWrapper();

        RazorpayWebhookWrapper.Subscription subscription = new RazorpayWebhookWrapper.Subscription();
        subscription.id = 'sub_test_456';
        subscription.entity = 'subscription';
        subscription.plan_id = 'plan_test';
        subscription.customer_id = 'cust_test';
        subscription.status = 'active';
        subscription.type = 1;
        subscription.current_start = 1650000000;
        subscription.current_end = 1650003600;
        subscription.ended_at = null;
        subscription.quantity = 1;
        subscription.charge_at = 1650007200;
        subscription.start_at = 1650000000;
        subscription.end_at = 1650003600;
        subscription.auth_attempts = 0;
        subscription.total_count = 12;
        subscription.paid_count = 1;
        subscription.customer_notify = true;
        subscription.created_at = 1650000000;
        subscription.expire_by = null;
        subscription.short_url = 'https://rzp.io/sub';
        subscription.has_scheduled_changes = false;
        subscription.change_scheduled_at = null;
        subscription.source = 'api';
        subscription.offer_id = null;
        subscription.payment_method = 'card';
        subscription.remaining_count = 11;
        subscription.pause_initiated_by = null;
        subscription.cancel_initiated_by = null;

        subscriptionWrapper.entity = subscription;

        RazorpayWebhookWrapper.Payment payment = new RazorpayWebhookWrapper.Payment();
        payment.id = 'pay_test_789';
        payment.entity = 'payment';
        payment.amount = 5000;
        payment.currency_code = 'INR';
        payment.status = 'captured';
        payment.order_id = 'order_test';
        payment.invoice_id = 'invoice_test';
        payment.international = false;
        payment.method = 'card';
        payment.amount_refunded = '0';
        payment.amount_transferred = '0';
        payment.refund_status = 'null';
        payment.captured = 'true';
        payment.description = 'Test payment';
        payment.card_id = 'card_test';
        payment.bank = 'HDFC';
        payment.wallet = null;
        payment.vpa = null;
        payment.email = 'test@example.com';
        payment.contact = '9999999999';
        payment.token_id = 'token_test';
        payment.customer_id = 'cust_test';
        payment.fee = 50;
        payment.tax = 10;
        payment.error_code = null;
        payment.error_description = null;
        payment.created_at = '1650000000';

        RazorpayWebhookWrapper.Card card = new RazorpayWebhookWrapper.Card();
        card.id = 'card_test';
        card.entity = 'card';
        card.name = 'John Doe';
        card.last4 = '4242';
        card.network = 'Visa';
        card.type = 'credit';
        card.issuer = 'HDFC';
        card.international = 'false';
        card.emi = 'false';
        card.sub_type = 'consumer';

        payment.card = card;
        paymentWrapper.entity = payment;

        payload.subscription = subscriptionWrapper;
        payload.payment = paymentWrapper;

        wrapper.payload = payload;

        System.assertEquals('subscription.activated', wrapper.event);
        System.assertEquals('sub_test_456', wrapper.payload.subscription.entity.id);
        System.assertEquals('pay_test_789', wrapper.payload.payment.entity.id);
        System.assertEquals('Visa', wrapper.payload.payment.entity.card.network);
    }
}