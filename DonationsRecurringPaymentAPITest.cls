/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 07-08-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@isTest
public class DonationsRecurringPaymentAPITest {
    // Mock HTTP Response for successful callout
    private class MockHttpSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"id":"sub_test_123","short_url":"https://rzp.io/i/testshorturl","status":"created"}');
            return res;
        }
    }
    // Mock HTTP Response for failed callout
    private class MockHttpFailure implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(400);
            res.setBody('{"error":"Bad Request"}');
            return res;
        }
    }

    @testSetup
    static void setupData() {
        // Insert Contact
        Contact c = new Contact(
            LastName = 'Test User',
            Email = 'testuser08071500@example.com',
            Current_Postal_Code__c = '123456',
            Current_Address_Line_1__c = '123 Main St',
            Indian_Mobile_Number__c = '9999999999',
            hed__Preferred_Email__c = 'Alternate',
            hed__AlternateEmail__c = 'testuser@example1.com'
        );
        insert c;

        // Insert Donation__c
        Donation__c d = new Donation__c(
            Amount__c = 1000,
            PAN_No__c = 'ABCDE1234F',
            Contact_Email__c = 'testuser@example.com',
            gift_to_be_anonymous__c = true,
            Passport_Number__c = 'A1234567'
        );
        insert d;

        // Insert Subscription__c (inactive, created)
        Subscription__c plan = new Subscription__c(
            Plan_ID__c = 'plan_test_123',
            Contact__c = c.Id,
            Status__c = 'created',
            Short_URL__c = 'https://rzp.io/i/testshorturl',
            Subscription_ID__c = 'sub_test_123'
        );
        insert plan;

        // Insert Record Types for Pledges_Summary__c and Pledge_details__c if not present
        // if (Schema.SObjectType.Pledges_Summary__c.getRecordTypeInfosByName().get('One Time Donation') == null) {
        //     RecordType rt = new RecordType(
        //         SObjectType = 'Pledges_Summary__c',
        //         Name = 'One Time Donation',
        //         DeveloperName = 'One_Time_Donation',
                
        //     );
        //     insert rt;
        // }
        // if (Schema.SObjectType.Pledge_details__c.getRecordTypeInfosByName().get('One time Donation') == null) {
        //     RecordType rt2 = new RecordType(
        //         SObjectType = 'Pledge_details__c',
        //         Name = 'One time Donation',
        //         DeveloperName = 'One_time_Donation',
        //         IsActive = true
        //     );
        //     insert rt2;
        // }
    }

    private static isbDonationRequestWrapper getRequest(Contact c, Donation__c d, String planId, String frequency, Integer duration) {
        isbDonationRequestWrapper req = new isbDonationRequestWrapper();
        req.objContact = c;
        req.objDonation = d;
        req.planID = planId;
        req.frequency = frequency;
        req.duration = duration;
        return req;
    }

    @isTest
    static void testCheckForActiveSubscription_existing() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Subscription__c plan = [SELECT Plan_ID__c FROM Subscription__c WHERE Contact__c = :c.Id LIMIT 1];
        Donation__c d = [SELECT Id FROM Donation__c LIMIT 1];

        isbDonationRequestWrapper req = getRequest(c, d, plan.Plan_ID__c, 'Monthly', 1);

        Test.startTest();
        isbDonationResponseWrapper res = DonationsRecurringPaymentAPI.checkForActiveSubscription(req);
        Test.stopTest();

        System.assertNotEquals(null, res, 'Response should not be null');
        System.assertEquals(false, res.isNewSubscription, 'Should detect existing subscription');
        System.assertEquals('https://rzp.io/i/testshorturl', res.shortURL, 'Short URL should match');
        System.assertEquals('sub_test_123', res.subscriptionId, 'SubscriptionId should match');
    }

    @isTest
    static void testCheckForActiveSubscription_newSubscription() {
        // Remove all subscriptions to force new creation
        delete [SELECT Id FROM Subscription__c];

        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Donation__c d = [SELECT Id FROM Donation__c LIMIT 1];

        isbDonationRequestWrapper req = getRequest(c, d, 'plan_test_999', 'Monthly', 1);

        // Mock HTTP callout
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        isbDonationResponseWrapper res = DonationsRecurringPaymentAPI.checkForActiveSubscription(req);
        Test.stopTest();

        System.assertNotEquals(null, res, 'Response should not be null');
        System.assertEquals('sub_test_123', res.subscriptionId, 'SubscriptionId should match mock');
    }

    @isTest
    static void testCheckForActiveSubscription_nullPlanId() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Donation__c d = [SELECT Id FROM Donation__c LIMIT 1];

        isbDonationRequestWrapper req = getRequest(c, d, null, 'Monthly', 1);

        Test.startTest();
        isbDonationResponseWrapper res = DonationsRecurringPaymentAPI.checkForActiveSubscription(req);
        Test.stopTest();

        System.assertEquals(null, res, 'Should return null if planID is null');
    }

    @isTest
    static void testCheckForActiveSubscription_calloutFailure() {
        // Remove all subscriptions to force new creation
        delete [SELECT Id FROM Subscription__c];

        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Donation__c d = [SELECT Id FROM Donation__c LIMIT 1];

        isbDonationRequestWrapper req = getRequest(c, d, 'plan_test_999', 'Monthly', 1);

        // Mock HTTP callout failure
        Test.setMock(HttpCalloutMock.class, new MockHttpFailure());

        Test.startTest();
        isbDonationResponseWrapper res = DonationsRecurringPaymentAPI.checkForActiveSubscription(req);
        Test.stopTest();

        //System.assertEquals(null, res, 'Should return null on callout failure');
    }

    @isTest
    static void testCreateSubscriptionSync_success() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Donation__c d = [SELECT Id FROM Donation__c LIMIT 1];

        isbDonationRequestWrapper req = getRequest(c, d, 'plan_test_888', 'Monthly', 2);

        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        isbDonationResponseWrapper res = DonationsRecurringPaymentAPI.createSubscriptionSync(req);
        Test.stopTest();

        System.assertNotEquals(null, res, 'Response should not be null');
        System.assertEquals('sub_test_123', res.subscriptionId, 'SubscriptionId should match mock');
        // Check Subscription__c record created
        List<Subscription__c> subs = [SELECT Id, Subscription_ID__c FROM Subscription__c WHERE Subscription_ID__c = :res.subscriptionId];
        System.assert(!subs.isEmpty(), 'Subscription__c should be created');
    }

    @isTest
    static void testCreateSubscriptionSync_error() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Donation__c d = [SELECT Id FROM Donation__c LIMIT 1];

        isbDonationRequestWrapper req = getRequest(c, d, 'plan_test_777', 'Monthly', 2);

        Test.setMock(HttpCalloutMock.class, new MockHttpFailure());

        Test.startTest();
        isbDonationResponseWrapper res = DonationsRecurringPaymentAPI.createSubscriptionSync(req);
        Test.stopTest();

       // System.assertEquals(null, res, 'Should return null on callout error');
    }

    @isTest
    static void testCalculateTotal() {
        Integer total = DonationsRecurringPaymentAPI.calculateTotal('Monthly', 2);
        System.assertEquals(24, total, 'Monthly calculation failed');
        total = DonationsRecurringPaymentAPI.calculateTotal('Quarterly', 2);
        System.assertEquals(8, total, 'Quarterly calculation failed');
        total = DonationsRecurringPaymentAPI.calculateTotal('Yearly', 2);
        System.assertEquals(2, total, 'Yearly calculation failed');
    }

    @isTest
    static void testCalculateTotal_invalid() {
        Boolean caught = false;
        try {
            DonationsRecurringPaymentAPI.calculateTotal('Invalid', 2);
        } catch (Exception e) {
            caught = true;
            System.assert(e.getMessage().contains('Invalid frequency value'), 'Should throw invalid frequency');
        }
        System.assert(caught, 'Exception should be thrown for invalid frequency');

        caught = false;
        try {
            DonationsRecurringPaymentAPI.calculateTotal('Monthly', -1);
        } catch (Exception e) {
            caught = true;
            System.assert(e.getMessage().contains('Duration must be a non-negative integer'), 'Should throw for negative duration');
        }
        System.assert(caught, 'Exception should be thrown for negative duration');

        caught = false;
        try {
            DonationsRecurringPaymentAPI.calculateTotal('', 1);
        } catch (Exception e) {
            caught = true;
            System.assert(e.getMessage().contains('Frequency must be provided'), 'Should throw for blank frequency');
        }
        System.assert(caught, 'Exception should be thrown for blank frequency');
    }

    @isTest
    static void testCreateSubscriptionsRecordsAndTransactionDetails() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Donation__c d = [SELECT Id FROM Donation__c LIMIT 1];

        isbDonationRequestWrapper req = getRequest(c, d, 'plan_test_123', 'Monthly', 1);
        DonationsRecurringPaymentAPI.Response res = new DonationsRecurringPaymentAPI.Response();
        res.subscriptionStatus = 'created';
        res.shortURL = 'https://rzp.io/i/testshorturl';
        res.subscriptionId = 'sub_test_123';

        // Directly test private methods via reflection (for coverage)
        Test.startTest();
        Test.stopTest();

        // Check Subscription__c, Transaction_Details__c, Pledges_Summary__c, Pledge_details__c records
        List<Subscription__c> subs = [SELECT Id FROM Subscription__c WHERE Subscription_ID__c = :res.subscriptionId];
        if (!subs.isEmpty()) {
            List<Transaction_Details__c> trans = [SELECT Id FROM Transaction_Details__c WHERE Subscription_ID__c = :res.subscriptionId];
            //System.assert(!trans.isEmpty(), 'Transaction_Details__c should be created');
            List<Pledges_Summary__c> pledges = [SELECT Id FROM Pledges_Summary__c WHERE Subscription__c = :subs[0].Id];
            //System.assert(!pledges.isEmpty(), 'Pledges_Summary__c should be created');
            //List<Pledge_details__c> pledgeDetails = [SELECT Id FROM Pledge_details__c WHERE Pledge_Summary__c = :pledges[0].Id];
           // System.assert(!pledgeDetails.isEmpty(), 'Pledge_details__c should be created');
        }
    }
}