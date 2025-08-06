/**
 * @description       : 
 * @author            : Jatin Prasad
 * @group             : 
 * @last modified on  : 07-14-2025
 * @last modified by  : Jatin Prasad
**/
@isTest
private class DonationControllerTest {

    static void setupContact(String email, String affiliation) {
    Contact c = new Contact(
        LastName = 'Test User',
        ISB_Email_ID__c = 'isb.' + email,
        Personal_Email_ID_1__c = email,
        hed__Preferred_Email__c = 'Personal Email ID 1',
        Alumni__c = (affiliation == 'Alumni'),
        Associate_Alumni__c = false,
        Student__c = (affiliation == 'Student'),
        Associate_Student__c = false,
        User_ID__c = (affiliation == 'Alumni') ? 'SAP123456' : null 
    );
    insert c;
}

    static void setupOrgWideEmail() {
        OrgWideEmailAddress owea = [SELECT Id, DisplayName, Address FROM OrgWideEmailAddress LIMIT 1];
        System.assertNotEquals(null, owea, 'OrgWideEmailAddress record must exist in the org.');
    }

    @isTest
    static void testFindContactAndSendOtp_Alumni() {
        String email = 'testuser1@example.com';
        setupOrgWideEmail();
        setupContact(email, 'Alumni');

        Test.startTest();
        DonationController.VerificationResult result = DonationController.findContactAndSendOtp(email, 'Alumni');
        Test.stopTest();

        System.assert(result != null);
        System.assert(result.success, 'Expected success');
        System.assertEquals('An OTP has been sent to your email address.', result.message);
    }

    @isTest
    static void testFindContactAndSendOtp_Student() {
        String email = 'student@example.com';
        setupOrgWideEmail();
        setupContact(email, 'Student');

        Test.startTest();
        DonationController.VerificationResult result = DonationController.findContactAndSendOtp(email, 'Student');
        Test.stopTest();

        System.assert(result.success);
        System.assertEquals('An OTP has been sent to your email address.', result.message);
    }

    @isTest
    static void testFindContactAndSendOtp_NonAlumni_NotFound() {
        String email = 'nonalumni@example.com';
        setupOrgWideEmail();

        Test.startTest();
        DonationController.VerificationResult result = DonationController.findContactAndSendOtp(email, 'Non-Alumni');
        Test.stopTest();

        System.assert(result.success);
        System.assert(result.contactNotFound);
        System.assertEquals('Contact not found. User can choose to continue.', result.message);
    }

    @isTest
    static void testFindContactAndSendOtp_InvalidAffiliation() {
        String email = 'invalid@example.com';

        Test.startTest();
        DonationController.VerificationResult result = DonationController.findContactAndSendOtp(email, 'InvalidType');
        Test.stopTest();

        System.assert(!result.success);
        System.assertEquals('Invalid affiliation selected.', result.message);
    }

    @isTest
    static void testVerifyOtpAndFetchContact_Success() {
        String email = 'otpverify@example.com';
        setupContact(email, 'Alumni');
        setupOrgWideEmail();

        // Simulate sending OTP
        DonationController.VerificationResult sendResult = DonationController.findContactAndSendOtp(email, 'Alumni');

        // Recreate cache key to simulate storing OTP manually
        String cacheKey = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-1', Blob.valueOf(email.toLowerCase())));
        Cache.OrgPartition otpPartition = Cache.Org.getPartition('local.DonationOtp');
        otpPartition.put(cacheKey, '123456', 300);

        Test.startTest();
        DonationController.VerificationResult verifyResult = DonationController.verifyOtpAndFetchContact(email, '123456', 'Alumni');
        Test.stopTest();

        System.assert(verifyResult.success);
        System.assertEquals('OTP Verified Successfully.', verifyResult.message);
        System.assertNotEquals(null, verifyResult.contactRecord);
    }

    @isTest
    static void testVerifyOtpAndFetchContact_InvalidOtp() {
        String email = 'wrongotp@example.com';
        setupContact(email, 'Alumni');
        setupOrgWideEmail();

        // Simulate correct OTP generation
        DonationController.findContactAndSendOtp(email, 'Alumni');

        // Try with wrong OTP
        Test.startTest();
        DonationController.VerificationResult result = DonationController.verifyOtpAndFetchContact(email, '999999', 'Alumni');
        Test.stopTest();

        System.assert(!result.success);
        System.assertEquals('The OTP you entered is incorrect. Please try again.', result.message);
    }

    @isTest
    static void testVerifyOtpAndFetchContact_ExpiredOtp() {
        String email = 'expired@example.com';
        setupContact(email, 'Alumni');

        // Do not put OTP in cache
        Test.startTest();
        DonationController.VerificationResult result = DonationController.verifyOtpAndFetchContact(email, '123456', 'Alumni');
        Test.stopTest();

        System.assert(!result.success);
        System.assertEquals('The OTP has expired or was not found. Please request a new OTP.', result.message);
    }
}