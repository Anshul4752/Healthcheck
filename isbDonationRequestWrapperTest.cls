/**
 * @description       : 
 * @author            : Jatin Prasad
 * @group             : 
 * @last modified on  : 07-10-2025
 * @last modified by  : Jatin Prasad
**/
@isTest
public class isbDonationRequestWrapperTest {
    
    @isTest
    static void testWrapperConstructionAndFieldAssignment() {
        isbDonationRequestWrapper wrapper = new isbDonationRequestWrapper();
        
        wrapper.affiliation = 'non-alumni';
        wrapper.geography = 'India';
        wrapper.paymentMode = 'Online';
        wrapper.name = 'Test User';
        wrapper.email = 'test@example.com';
        wrapper.phone = '9999999999';
        wrapper.bankName = 'HDFC';
        wrapper.chequeDate = '2025-07-10';
        wrapper.transactionDate = '2025-07-09';
        wrapper.transactionOrChequeNumber = 'TXN123456';
        wrapper.panNumber = 'ABCDE1234F';
        wrapper.donationCurrency = 'INR';
        wrapper.anonymousDonation = false;
        wrapper.amount = 5000;
        wrapper.programName = 'PGP';
        wrapper.contactClass = '2025';
        wrapper.pincode = '500001';
        wrapper.currentAddress = 'Hyderabad';
        wrapper.receiptPreference = 'Email';
        wrapper.frequency = 'monthly';
        wrapper.duration = 12;
        wrapper.planID = 'plan_123456';
        wrapper.paymentType = 'onetime';
        wrapper.subscriptionAmountType = 'predefined';
        wrapper.totalCount = 3;
        wrapper.transactionID = 'txn_001';

        System.assertEquals('Test User', wrapper.name);
        System.assertEquals('PGP', wrapper.programName);
        System.assertEquals(5000, wrapper.amount);
        System.assertEquals('onetime', wrapper.paymentType);
    }
}