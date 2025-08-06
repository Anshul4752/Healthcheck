/**
 * @description       : Test class for donationMaster
 * @author            : Jatin Prasad
 * @last modified on  : 07-10-2025
**/
@isTest
public class donationMasterTest {

    static testMethod void testProcessWrapper_NonAlumni() {
        isbDonationRequestWrapper wrapper = new isbDonationRequestWrapper();
        wrapper.name = 'John Doe';
        wrapper.email = 'john.doe@example.com';
        wrapper.phone = '9876543210';
        wrapper.affiliation = 'non-alumni';
        

        Test.startTest();
        isbDonationRequestWrapper result;
        try {
            result = donationMaster.processWrapper(wrapper);
        } catch (Exception ex) {
           // System.assert(false, 'Unexpected exception during Non-Alumni processing: ' + ex.getMessage());
        }
        Test.stopTest();

       // System.assertNotEquals(null, result.objContact, 'Contact should be created');
       // System.assertEquals('john.doe@example.com', result.objContact.Email);
    }

    static testMethod void testProcessWrapper_Corporate() {
        isbDonationRequestWrapper wrapper = new isbDonationRequestWrapper();
        wrapper.name = 'Jane Smith';
        wrapper.email = 'jane.smith@corp.com';
        wrapper.phone = '9988776655';
        wrapper.affiliation = 'corporate';

        Test.startTest();
        isbDonationRequestWrapper result;
        try {
            result = donationMaster.processWrapper(wrapper);
        } catch (Exception ex) {
            System.assert(false, 'Unexpected exception during Corporate processing: ' + ex.getMessage());
        }
        Test.stopTest();

        System.assertNotEquals(null, result.objContact);
        System.assertEquals('jane.smith@corp.com', result.objContact.Email);
    }

    static testMethod void testProcessWrapper_InvalidAffiliation() {
        isbDonationRequestWrapper wrapper = new isbDonationRequestWrapper();
        wrapper.name = 'Fake Name';
        wrapper.email = 'fake@example.com';
        wrapper.phone = '1234567890';
        wrapper.affiliation = 'invalidValue'; 
        wrapper.objContact = null;

        Boolean exceptionThrown = false;
        try {
            donationMaster.processWrapper(wrapper);
        } catch (Exception ex) {
            exceptionThrown = true;
            System.debug('Caught expected exception: ' + ex.getMessage());
        }

        System.assert(exceptionThrown, 'Expected an exception to be thrown for invalid affiliation');
    }

    static testMethod void testRouteToPaymentProcessor_EmptyType() {
        isbDonationRequestWrapper wrapper = new isbDonationRequestWrapper();
        wrapper.paymentType = '';

        Boolean exceptionThrown = false;
        try {
            donationMaster.routeToPaymentProcessor(wrapper);
        } catch (Exception e) {
            exceptionThrown = true;
            System.debug('Caught expected exception: ' + e.getMessage());
        }
        System.assert(exceptionThrown, 'Expected exception for empty payment type');
    }

    static testMethod void testRouteToPaymentProcessor_InvalidType() {
        isbDonationRequestWrapper wrapper = new isbDonationRequestWrapper();
        wrapper.paymentType = 'invalidType';

        Boolean exceptionThrown = false;
        try {
            donationMaster.routeToPaymentProcessor(wrapper);
        } catch (Exception e) {
            exceptionThrown = true;
            System.debug('Caught expected exception: ' + e.getMessage());
        }
        System.assert(exceptionThrown, 'Expected exception for invalid payment type');
    }
}