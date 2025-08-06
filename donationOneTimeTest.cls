/**
 * @description       : 
 * @author            : Jatin Prasad
 * @group             : 
 * @last modified on  : 07-14-2025
 * @last modified by  : Jatin Prasad
**/
@isTest
public class donationOneTimeTest {

    @testSetup
    static void setupTestData() {
        // Create test Contact
        Contact testContact = new Contact(
        FirstName = 'Test',
        LastName = 'User',
        Email = 'testuser@example.com',
        hed__Preferred_Email__c = 'Personal Email ID 1',
        Personal_Email_ID_1__c = 'testuser@example.com'
    );
        insert testContact;

        // Create custom label placeholders (set manually in org or mocked in test)
        if (Test.isRunningTest()) {
            System.Test.setMock(HttpCalloutMock.class, new MockRazorpayResponse());
        }
    }

    @isTest
    static void testCreateTransactionDetailNew() {
        Contact con = [SELECT Id, FirstName,LastName, Email FROM Contact LIMIT 1];

        isbDonationRequestWrapper requestWrapper = new isbDonationRequestWrapper();
        requestWrapper.email = con.Email;
        requestWrapper.name = con.FirstName + ' ' + con.LastName;
        requestWrapper.phone = '9999999999';
        requestWrapper.amount = (Long) 500.00;
        requestWrapper.panNumber = 'ABCDE1234F';
        requestWrapper.currentAddress = '123, Test Lane';
        requestWrapper.pincode = '123456';
        requestWrapper.anonymousDonation = true;
        requestWrapper.donationCurrency = 'INR';

        // Mock donation object
        Donation__c donation = new Donation__c();
        donation.Amount__c = (Long) 500.00;
        donation.Passport_Number__c = 'P1234567';
        requestWrapper.objDonation = donation;
        requestWrapper.objContact = con;

        Test.startTest();
        isbDonationRequestWrapper response = donationOneTime.createTransactionDetailNew(requestWrapper);
        Test.stopTest();

        System.assertNotEquals(null, response.transactionID, 'Transaction ID should not be null.');
    }

    @isTest
static void testDonationFormNew() {
    System.Test.setMock(HttpCalloutMock.class, new MockRazorpayResponse()); 

    Contact con = [SELECT Id, Email, FirstName, LastName FROM Contact LIMIT 1];

    isbDonationRequestWrapper requestWrapper = new isbDonationRequestWrapper();
    requestWrapper.email = con.Email;
    requestWrapper.name = con.FirstName + ' ' + con.LastName;
    requestWrapper.phone = '9999999999';
    requestWrapper.amount = (Long) 500.00;
    requestWrapper.panNumber = 'ABCDE1234F';
    requestWrapper.currentAddress = '123, Test Lane';
    requestWrapper.pincode = '123456';
    requestWrapper.anonymousDonation = false;
    requestWrapper.donationCurrency = 'INR';

    Donation__c donation = new Donation__c();
    donation.Amount__c = (Long) 500.00;
    requestWrapper.objDonation = donation;
    requestWrapper.objContact = con;

    isbDonationRequestWrapper createdWrapper = donationOneTime.createTransactionDetailNew(requestWrapper);
    requestWrapper.transactionID = createdWrapper.transactionID;

    Test.startTest();
    isbDonationResponseWrapper response = donationOneTime.donationFormNew(requestWrapper);
    Test.stopTest();

    System.assertNotEquals(null, response.shortURL, 'Short URL should be populated from mock.');
}


    // Mock HTTP Response for Razorpay API
    class MockRazorpayResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"short_url":"https://rzp.io/i/test123", "currency1":"INR"}');
            res.setStatusCode(200);
            return res;
        }
    }
}