/**
 * @description       : Test class for razorpayWebhookController.
 * @author            : Anshul Verma
 * @group             : 
 * @last modified on  : 07-09-2025
 * @last modified by  : Anshul Verma
**/
@isTest
private class RazorpayWebhookControllerTest {

    /**
     * @description Helper method to create a mock JSON body for a given event.
    **/
    private static String createJsonBody(String eventName) {
        if (String.isBlank(eventName)) {
            // Payload with a null event
            return '{"payload": {"subscription": {"id": "sub_123"}}}';
        }
        return JSON.serialize(new Map<String, Object>{
            'event' => eventName,
            'payload' => new Map<String, Object> {
                'subscription' => new Map<String, Object> {
                    'id' => 'sub_12345',
                    'status' => 'active'
                }
            }
        });
    }

    @isTest
    static void testHandleWebhook_SubscriptionActivated_Success() {
        // GIVEN: A valid request for 'subscription.activated'
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/razorpay/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(createJsonBody('subscription.activated'));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        // WHEN: The webhook handler is called
        Test.startTest();
        razorpayWebhookController.handleWebhook();
        Test.stopTest();

        // THEN: The response should be successful (200 OK)
        System.assertEquals(200, RestContext.response.statusCode, 'Status code should be 200 for a handled event.');
        System.assertEquals('200', RestContext.response.responseBody.toString());
    }
    
    @isTest
    static void testHandleWebhook_SubscriptionCharged_Success() {
        // GIVEN: A valid request for 'subscription.charged'
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/razorpay/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(createJsonBody('subscription.charged'));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        // WHEN: The webhook handler is called
        Test.startTest();
        razorpayWebhookController.handleWebhook();
        Test.stopTest();

        // THEN: The response should be successful (200 OK)
        System.assertEquals(200, RestContext.response.statusCode, 'Status code should be 200 for a handled event.');
    }
    
    @isTest
    static void testHandleWebhook_EmptyBody_Returns400() {
        // GIVEN: A request with an empty body
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/razorpay/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        // WHEN: The webhook handler is called
        Test.startTest();
        razorpayWebhookController.handleWebhook();
        Test.stopTest();

        // THEN: The response should be a Bad Request (400)
        System.assertEquals(400, RestContext.response.statusCode, 'Status code should be 400 for an empty body.');
        System.assertEquals('Empty request body', RestContext.response.responseBody.toString());
    }
    
    @isTest
    static void testHandleWebhook_InvalidPayload_Returns400() {
        // GIVEN: A request with a payload missing the 'event' attribute
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/razorpay/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(createJsonBody(null)); // Helper creates a payload with a null event
        RestContext.request = req;
        RestContext.response = new RestResponse();

        // WHEN: The webhook handler is called
        Test.startTest();
        razorpayWebhookController.handleWebhook();
        Test.stopTest();

        // THEN: The response should be a Bad Request (400)
        System.assertEquals(400, RestContext.response.statusCode, 'Status code should be 400 for a missing event.');
        System.assertEquals('Invalid payload or missing event', RestContext.response.responseBody.toString());
    }
    
    @isTest
    static void testHandleWebhook_UnhandledEvent_Returns400() {
        // GIVEN: A request with an event that is not handled by the switch statement
        String unhandledEvent = 'payment.failed';
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/razorpay/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(createJsonBody(unhandledEvent));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        // WHEN: The webhook handler is called
        Test.startTest();
        razorpayWebhookController.handleWebhook();
        Test.stopTest();

        // THEN: The response should be a Bad Request (400)
        System.assertEquals(400, RestContext.response.statusCode, 'Status code should be 400 for an unhandled event.');
        System.assert(RestContext.response.responseBody.toString().contains('Unhandled event type'), 'Response body should indicate an unhandled event.');
    }
    
    @isTest
    static void testHandleWebhook_JsonException_Returns500() {
        // GIVEN: A request with a malformed JSON body
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/razorpay/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"event": "invalid"'); // Malformed JSON
        RestContext.request = req;
        RestContext.response = new RestResponse();

        // WHEN: The webhook handler is called
        Test.startTest();
        razorpayWebhookController.handleWebhook();
        Test.stopTest();

        // THEN: The response should be an Internal Server Error (500)
        System.assertEquals(500, RestContext.response.statusCode, 'Status code should be 500 for a JSON parsing error.');
        System.assert(RestContext.response.responseBody.toString().contains('Error processing webhook'), 'Response body should indicate a processing error.');
    }
}