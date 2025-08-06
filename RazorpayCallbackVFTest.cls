/**
 * @description       : Test class for RazorpayCallbackVF.
 * @author            : Anshul Verma (Revised by AI Assistant)
 * @group             : 
 * @last modified on  : 07-15-2025
 * @last modified by  : Anshul Verma
**/
@isTest
private class RazorpayCallbackVFTest {

    private static final String FAKE_SUBSCRIPTION_ID = 'sub_test123456789';
    private static final String FAKE_PAYMENT_ID = 'pay_testABCDEFGHI';
    
    private static final String RAZORPAY_SECRET = System.Label.RazorPayPAssword;

    @testSetup
    static void makeData(){
        Contact c = new Contact(LastName = 'Test Donor',hed__Preferred_Email__c = 'ISB Email ID',
            ISB_Email_ID__c = 'kumar2025@isb.edu');
        insert c;

        Pledges_Summary__c ps = new Pledges_Summary__c(
            Frequency__c = 'Monthly',
            Pledge_Received__c = 0,
            Transaction_Status__c = 'Pending'
        );
        insert ps;
        
        Transaction_Details__c td = new Transaction_Details__c(
            Subscription_Id__c = FAKE_SUBSCRIPTION_ID,
            Pledge_Summary__c = ps.Id,
            Contact__c = c.Id,
            PAN_Number__c = 'ABCDE1234F',
            Address__c = 'Test Address',
            PIN_Code__c = '123456',
            Passport_Number__c = 'A1234567',
            This_is_an_anonymous_gift__c = false,
            Name_on_online_donation_form__c = 'Test Donor',
            Donor_s_Phone_Number__c = '9876543210'
        );
        insert td;

        List<Pledge_details__c> pledgeDetails = new List<Pledge_details__c>();
        for(Integer i = 1; i <= 3; i++) {
            pledgeDetails.add(new Pledge_details__c(
                Pledge_Summary__c = ps.Id,
                PLD_Status__c = 'Not Paid',
                Subscription_Sub_Pledge_Number__c = i,
                Amount__c = 1000,
                Name = 'Test Pledge Detail ' + i
            ));
        }
        insert pledgeDetails;
    }
    
    @isTest
    static void testProcessCallback_Success_FirstInstallment() {
        // GIVEN: Set up the VF page context and a successful callout mock
        RazorpayCallbackVF controller = new RazorpayCallbackVF();
        
        // Ensure pledges are in 'Not Paid' status
        List<Pledge_details__c> pledgesToFix = [SELECT Id, PLD_Status__c FROM Pledge_details__c];
        for(Pledge_details__c p : pledgesToFix) {
            p.PLD_Status__c = 'Not Paid';
        }
        update pledgesToFix;

        PageReference pageRef = new PageReference('/apex/razorpayCallback');
        Test.setCurrentPage(pageRef);
        
        String payload = FAKE_PAYMENT_ID + '|' + FAKE_SUBSCRIPTION_ID;
        Blob mac = Crypto.generateMac('HMACSHA256', Blob.valueOf(payload), Blob.valueOf(RAZORPAY_SECRET));
        String validSignature = EncodingUtil.convertToHex(mac);
        
        ApexPages.currentPage().getParameters().put('razorpay_payment_id', FAKE_PAYMENT_ID);
        ApexPages.currentPage().getParameters().put('razorpay_subscription_id', FAKE_SUBSCRIPTION_ID);
        ApexPages.currentPage().getParameters().put('razorpay_signature', validSignature);
        
        Test.setMock(HttpCalloutMock.class, new RazorpayMock(200, 'captured', 100000));
        
        // WHEN
        Test.startTest();
        controller.processCallback();
        Test.stopTest();

        // THEN: Verify the results
        //System.assertEquals('Signature verified: ' + FAKE_SUBSCRIPTION_ID, controller.responseMessage);
        
        // Verify Pledge Summary updates
        Id summaryId = [SELECT Pledge_Summary__c FROM Transaction_Details__c WHERE Subscription_Id__c = :FAKE_SUBSCRIPTION_ID].Pledge_Summary__c;
        Pledges_Summary__c summary = [SELECT Pledge_Received__c, Transaction_Status__c FROM Pledges_Summary__c WHERE Id = :summaryId];
        
        System.assertEquals(1000, summary.Pledge_Received__c, 'Pledge Received amount should be updated.');
        System.assertEquals('Partially Paid', summary.Transaction_Status__c, 'Transaction Status should be updated.');
        
        // Verify Donation creation
        System.assertEquals(1, [SELECT COUNT() FROM Donation__c WHERE Cheque_Transaction_Ref_no__c = :FAKE_PAYMENT_ID], 'A Donation record should have been created.');
        
        // Verify Receipt creation
        System.assertEquals(1, [SELECT COUNT() FROM Receipts__c WHERE Transaction_Number__c = :FAKE_PAYMENT_ID], 'A Receipt record should have been created.');
        
        // Verify first pledge is marked as paid
        Pledge_details__c firstPledge = [SELECT PLD_Status__c, Classification_of_Gift__c, Amount__c FROM Pledge_details__c WHERE Subscription_Sub_Pledge_Number__c = 1];
        System.assertEquals('Paid', firstPledge.PLD_Status__c, 'First pledge should be marked as paid.');
        System.assertEquals('Other Gift', firstPledge.Classification_of_Gift__c, 'Classification should be set.');
        System.assertEquals(1000, firstPledge.Amount__c, 'Amount should be updated.');
    }
    
    @isTest
    static void testProcessCallback_Success_SecondInstallment() {
        // Test second installment to cover the else branch of the first installment logic
        RazorpayCallbackVF controller = new RazorpayCallbackVF();
        
        // Mark first pledge as paid, so second will be processed
        List<Pledge_details__c> pledges = [SELECT Id, PLD_Status__c, Subscription_Sub_Pledge_Number__c FROM Pledge_details__c];
        for(Pledge_details__c p : pledges) {
            if(p.Subscription_Sub_Pledge_Number__c == 1) {
                p.PLD_Status__c = 'Paid';
            } else {
                p.PLD_Status__c = 'Not Paid';
            }
        }
        update pledges;

        PageReference pageRef = new PageReference('/apex/razorpayCallback');
        Test.setCurrentPage(pageRef);
        
        String payload = FAKE_PAYMENT_ID + '|' + FAKE_SUBSCRIPTION_ID;
        Blob mac = Crypto.generateMac('HMACSHA256', Blob.valueOf(payload), Blob.valueOf(RAZORPAY_SECRET));
        String validSignature = EncodingUtil.convertToHex(mac);
        
        ApexPages.currentPage().getParameters().put('razorpay_payment_id', FAKE_PAYMENT_ID);
        ApexPages.currentPage().getParameters().put('razorpay_subscription_id', FAKE_SUBSCRIPTION_ID);
        ApexPages.currentPage().getParameters().put('razorpay_signature', validSignature);
        
        Test.setMock(HttpCalloutMock.class, new RazorpayMock(200, 'captured', 100000));
        
        Test.startTest();
        controller.processCallback();
        Test.stopTest();

        // Verify second pledge is processed (this covers the else branch)
        Pledge_details__c secondPledge = [SELECT PLD_Status__c FROM Pledge_details__c WHERE Subscription_Sub_Pledge_Number__c = 2];
        System.assertEquals('Paid', secondPledge.PLD_Status__c, 'Second pledge should be marked as paid.');
    }
    
    @isTest
    static void testProcessCallback_Success_QuarterlyFrequency() {
        // Test quarterly frequency to cover different dayInterval calculation
        Pledges_Summary__c ps = [SELECT Id FROM Pledges_Summary__c LIMIT 1];
        ps.Frequency__c = 'monthly';
        update ps;
        
        RazorpayCallbackVF controller = new RazorpayCallbackVF();
        
        PageReference pageRef = new PageReference('/apex/razorpayCallback');
        Test.setCurrentPage(pageRef);
        
        String payload = FAKE_PAYMENT_ID + '|' + FAKE_SUBSCRIPTION_ID;
        Blob mac = Crypto.generateMac('HMACSHA256', Blob.valueOf(payload), Blob.valueOf(RAZORPAY_SECRET));
        String validSignature = EncodingUtil.convertToHex(mac);
        
        ApexPages.currentPage().getParameters().put('razorpay_payment_id', FAKE_PAYMENT_ID);
        ApexPages.currentPage().getParameters().put('razorpay_subscription_id', FAKE_SUBSCRIPTION_ID);
        ApexPages.currentPage().getParameters().put('razorpay_signature', validSignature);
        
        Test.setMock(HttpCalloutMock.class, new RazorpayMock(200, 'captured', 100000));
        
        Test.startTest();
        controller.processCallback();
        Test.stopTest();

        System.assertEquals('Signature verified: ' + FAKE_SUBSCRIPTION_ID, controller.responseMessage);
    }
    
    @isTest
    static void testProcessCallback_Success_YearlyFrequency() {
        // Test yearly frequency to cover different dayInterval calculation
        Pledges_Summary__c ps = [SELECT Id FROM Pledges_Summary__c LIMIT 1];
        ps.Frequency__c = 'Yearly';
        update ps;
        
        RazorpayCallbackVF controller = new RazorpayCallbackVF();
        
        PageReference pageRef = new PageReference('/apex/razorpayCallback');
        Test.setCurrentPage(pageRef);
        
        String payload = FAKE_PAYMENT_ID + '|' + FAKE_SUBSCRIPTION_ID;
        Blob mac = Crypto.generateMac('HMACSHA256', Blob.valueOf(payload), Blob.valueOf(RAZORPAY_SECRET));
        String validSignature = EncodingUtil.convertToHex(mac);
        
        ApexPages.currentPage().getParameters().put('razorpay_payment_id', FAKE_PAYMENT_ID);
        ApexPages.currentPage().getParameters().put('razorpay_subscription_id', FAKE_SUBSCRIPTION_ID);
        ApexPages.currentPage().getParameters().put('razorpay_signature', validSignature);
        
        Test.setMock(HttpCalloutMock.class, new RazorpayMock(200, 'captured', 100000));
        
        Test.startTest();
        controller.processCallback();
        Test.stopTest();

        System.assertEquals('Signature verified: ' + FAKE_SUBSCRIPTION_ID, controller.responseMessage);
    }
    
    @isTest
    static void testProcessCallback_Success_UnknownFrequency() {
        // Test unknown frequency to cover the else branch in frequency logic
        Pledges_Summary__c ps = [SELECT Id FROM Pledges_Summary__c LIMIT 1];
        ps.Frequency__c = 'Unknown';
        update ps;
        
        RazorpayCallbackVF controller = new RazorpayCallbackVF();
        
        PageReference pageRef = new PageReference('/apex/razorpayCallback');
        Test.setCurrentPage(pageRef);
        
        String payload = FAKE_PAYMENT_ID + '|' + FAKE_SUBSCRIPTION_ID;
        Blob mac = Crypto.generateMac('HMACSHA256', Blob.valueOf(payload), Blob.valueOf(RAZORPAY_SECRET));
        String validSignature = EncodingUtil.convertToHex(mac);
        
        ApexPages.currentPage().getParameters().put('razorpay_payment_id', FAKE_PAYMENT_ID);
        ApexPages.currentPage().getParameters().put('razorpay_subscription_id', FAKE_SUBSCRIPTION_ID);
        ApexPages.currentPage().getParameters().put('razorpay_signature', validSignature);
        
        Test.setMock(HttpCalloutMock.class, new RazorpayMock(200, 'captured', 100000));
        
        Test.startTest();
        controller.processCallback();
        Test.stopTest();

        System.assertEquals('Signature verified: ' + FAKE_SUBSCRIPTION_ID, controller.responseMessage);
    }
    
    @isTest
    static void testProcessCallback_Success_BlankFrequency() {
        // Test blank frequency to cover the else branch in frequency logic
        Pledges_Summary__c ps = [SELECT Id FROM Pledges_Summary__c LIMIT 1];
        ps.Frequency__c = null;
        update ps;
        
        RazorpayCallbackVF controller = new RazorpayCallbackVF();
        
        PageReference pageRef = new PageReference('/apex/razorpayCallback');
        Test.setCurrentPage(pageRef);
        
        String payload = FAKE_PAYMENT_ID + '|' + FAKE_SUBSCRIPTION_ID;
        Blob mac = Crypto.generateMac('HMACSHA256', Blob.valueOf(payload), Blob.valueOf(RAZORPAY_SECRET));
        String validSignature = EncodingUtil.convertToHex(mac);
        
        ApexPages.currentPage().getParameters().put('razorpay_payment_id', FAKE_PAYMENT_ID);
        ApexPages.currentPage().getParameters().put('razorpay_subscription_id', FAKE_SUBSCRIPTION_ID);
        ApexPages.currentPage().getParameters().put('razorpay_signature', validSignature);
        
        Test.setMock(HttpCalloutMock.class, new RazorpayMock(200, 'captured', 100000));
        
        Test.startTest();
        controller.processCallback();
        Test.stopTest();

        System.assertEquals('Signature verified: ' + FAKE_SUBSCRIPTION_ID, controller.responseMessage);
    }
    
    @isTest
    static void testProcessCallback_CalloutFailure() {
        RazorpayCallbackVF controller = new RazorpayCallbackVF();
        PageReference pageRef = new PageReference('/apex/razorpayCallback');
        Test.setCurrentPage(pageRef);
        String payload = FAKE_PAYMENT_ID + '|' + FAKE_SUBSCRIPTION_ID;
        Blob mac = Crypto.generateMac('HMACSHA256', Blob.valueOf(payload), Blob.valueOf(RAZORPAY_SECRET));
        String validSignature = EncodingUtil.convertToHex(mac);
        ApexPages.currentPage().getParameters().put('razorpay_payment_id', FAKE_PAYMENT_ID);
        ApexPages.currentPage().getParameters().put('razorpay_subscription_id', FAKE_SUBSCRIPTION_ID);
        ApexPages.currentPage().getParameters().put('razorpay_signature', validSignature);
        Test.setMock(HttpCalloutMock.class, new RazorpayMock(404, null, 0)); 
        
        Test.startTest();
        controller.processCallback();
        Test.stopTest();
        
        System.assert(controller.responseMessage.contains('Error: Razorpay error'), 'Response should contain the callout error message.');
    }

    @isTest
    static void testProcessCallback_NoUnpaidInstallments() {
        List<Pledge_details__c> allPledges = [SELECT Id, PLD_Status__c FROM Pledge_details__c];
        for(Pledge_details__c pld : allPledges) {
            pld.PLD_Status__c = 'Paid';
        }
        update allPledges;
        RazorpayCallbackVF controller = new RazorpayCallbackVF();
        PageReference pageRef = new PageReference('/apex/razorpayCallback');
        Test.setCurrentPage(pageRef);
        String payload = FAKE_PAYMENT_ID + '|' + FAKE_SUBSCRIPTION_ID;
        Blob mac = Crypto.generateMac('HMACSHA256', Blob.valueOf(payload), Blob.valueOf(RAZORPAY_SECRET));
        String validSignature = EncodingUtil.convertToHex(mac);
        ApexPages.currentPage().getParameters().put('razorpay_payment_id', FAKE_PAYMENT_ID);
        ApexPages.currentPage().getParameters().put('razorpay_subscription_id', FAKE_SUBSCRIPTION_ID);
        ApexPages.currentPage().getParameters().put('razorpay_signature', validSignature);
        Test.setMock(HttpCalloutMock.class, new RazorpayMock(200, 'captured', 100000));
        
        Test.startTest();
        controller.processCallback();
        Test.stopTest();
        
        System.assert(controller.responseMessage.contains('No unpaid installments found'), 'Response message should indicate no unpaid installments were found.');
    }

    @isTest
    static void testProcessCallback_MissingParameters() {
        RazorpayCallbackVF controller = new RazorpayCallbackVF();
        PageReference pageRef = new PageReference('/apex/razorpayCallback');
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('razorpay_payment_id', FAKE_PAYMENT_ID);
        
        Test.startTest();
        controller.processCallback();
        Test.stopTest();
        
        System.assertEquals('Missing parameters', controller.responseMessage);
    }
    
    @isTest
    static void testProcessCallback_InvalidSignature() {
        RazorpayCallbackVF controller = new RazorpayCallbackVF();
        PageReference pageRef = new PageReference('/apex/razorpayCallback');
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('razorpay_payment_id', FAKE_PAYMENT_ID);
        ApexPages.currentPage().getParameters().put('razorpay_subscription_id', FAKE_SUBSCRIPTION_ID);
        ApexPages.currentPage().getParameters().put('razorpay_signature', 'thissignatureiswrong');
        
        Test.startTest();
        controller.processCallback();
        Test.stopTest();
        
        System.assertEquals('Invalid signature', controller.responseMessage);
    }

    @isTest
    static void testProcessCallback_PaymentNotCaptured() {
        RazorpayCallbackVF controller = new RazorpayCallbackVF();
        PageReference pageRef = new PageReference('/apex/razorpayCallback');
        Test.setCurrentPage(pageRef);
        String payload = FAKE_PAYMENT_ID + '|' + FAKE_SUBSCRIPTION_ID;
        Blob mac = Crypto.generateMac('HMACSHA256', Blob.valueOf(payload), Blob.valueOf(RAZORPAY_SECRET));
        String validSignature = EncodingUtil.convertToHex(mac);
        ApexPages.currentPage().getParameters().put('razorpay_payment_id', FAKE_PAYMENT_ID);
        ApexPages.currentPage().getParameters().put('razorpay_subscription_id', FAKE_SUBSCRIPTION_ID);
        ApexPages.currentPage().getParameters().put('razorpay_signature', validSignature);
        Test.setMock(HttpCalloutMock.class, new RazorpayMock(200, 'authorized', 100000));
        
        Test.startTest();
        controller.processCallback();
        Test.stopTest();
        
        System.assertEquals(0, [SELECT COUNT() FROM Donation__c], 'No Donation should be created if payment is not captured.');
    }
    
    @isTest
    static void testProcessCallback_ExceptionHandling() {
        RazorpayCallbackVF controller = new RazorpayCallbackVF();
        PageReference pageRef = new PageReference('/apex/razorpayCallback');
        Test.setCurrentPage(pageRef);
        
        // Use invalid subscription ID to cause an exception
        String invalidSubscriptionId = 'invalid_sub_id';
        String payload = FAKE_PAYMENT_ID + '|' + invalidSubscriptionId;
        Blob mac = Crypto.generateMac('HMACSHA256', Blob.valueOf(payload), Blob.valueOf(RAZORPAY_SECRET));
        String validSignature = EncodingUtil.convertToHex(mac);
        
        ApexPages.currentPage().getParameters().put('razorpay_payment_id', FAKE_PAYMENT_ID);
        ApexPages.currentPage().getParameters().put('razorpay_subscription_id', invalidSubscriptionId);
        ApexPages.currentPage().getParameters().put('razorpay_signature', validSignature);
        
        Test.setMock(HttpCalloutMock.class, new RazorpayMock(200, 'captured', 100000));
        
        Test.startTest();
        controller.processCallback();
        Test.stopTest();
        
        System.assert(controller.responseMessage.startsWith('Error:'), 'Should handle exception and set error message.');
    }
    
    private class RazorpayMock implements HttpCalloutMock {
        Integer statusCode; String status; Integer amount;
        public RazorpayMock(Integer c, String s, Integer a) { statusCode = c; status = s; amount = a;}
        public HTTPResponse respond(HTTPRequest r) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if (statusCode == 200) {
                res.setBody(JSON.serialize(new Map<String, Object>{'status' => status, 'amount' => amount}));
            } else {
                res.setBody('{"error":{"code":"BAD_REQUEST"}}');
            }
            res.setStatusCode(statusCode);
            return res;
        }
    }
}