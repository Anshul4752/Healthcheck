/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 07-09-2025
 * @last modified by  : Anshul Verma
**/
@RestResource(urlMapping='/razorpay/webhook')
global with sharing class razorpayWebhookController {
    @HttpPost
    global static void handleWebhook() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String body = req.requestBody.toString();
            System.debug('body : '+ body);
            if (String.isBlank(body)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('Empty request body');
                return;
            }

            RazorpayWebhookWrapper webhook = (RazorpayWebhookWrapper) JSON.deserialize(body, RazorpayWebhookWrapper.class);
            if (webhook == null || String.isBlank(webhook.event)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('Invalid payload or missing event');
                return;
            }

            // Dispatch to appropriate handler based on event type
            switch on webhook.event {
                when 'subscription.activated' {
                    RazorpaySubscriptionHandler.handleActivated(webhook);
                }
                when 'subscription.completed' {
                    RazorpaySubscriptionCompleted.handleWebhook(webhook);
                }
                when 'subscription.charged' {
                    RazorpaySubscriptionCharged.handleWebhook(webhook);
                }
                when 'subscription.pending' {
                    RazorpaySubscriptionHandler.handlePending(webhook);
                }
                when 'subscription.updated' {
                    RazorpaySubscriptionHandler.handleUpdated(webhook);
                }
                when 'subscription.halted' {
                    RazorpaySubscriptionHandler.handleHalted(webhook);
                }
                when 'subscription.paused' {
                    RazorpaySubscriptionHandler.handlePaused(webhook);
                }
                when 'subscription.resumed' {
                    RazorpaySubscriptionHandler.handleResumed(webhook);
                }
                when 'subscription.cancelled' {
                    RazorpaySubscriptionHandler.handleCancelled(webhook);
                }
                when 'subscription.authenticated' {
                    RazorpaySubscriptionAuthentication.handleWebhook(webhook);
                }
                when else {
                    res.statusCode = 400;
                    res.responseBody = Blob.valueOf('Unhandled event type: ' + webhook.event);
                    return;
                }
            }

            // Boolean valid = verifySignature(req.requestBody.toString(), req.headers.get('x-razorpay-signature'));

            // if (valid) {
            //     // Process your business logic...
            //     res.statusCode = 200;
            //     res.responseBody = Blob.valueOf('OK');
            // } else {
            //     res.statusCode = 400;
            //     res.responseBody = Blob.valueOf('Invalid signature');
            // }

            res.statusCode = 200;
            // RestContext.response.statusCode = 200;
            res.responseBody = Blob.valueOf('200');
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error processing webhook: ' + e.getMessage());
        }
    }
}