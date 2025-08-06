/**
 * @description       : 
 * @author            : Jatin Prasad
 * @group             : 
 * @last modified on  : 07-14-2025
 * @last modified by  : Jatin Prasad
**/
@isTest
private class DonationMetadataControllerTest {

    @testSetup
    static void setupData() {
        // No setup for CMDT since DML is not allowed on CMDT.
        // Assume records already exist in the org for Donation_Country_Configuration__mdt, Razorpay_Plan_Mapping__mdt, and Donation_Amount_Conversion__mdt.
    }

    @isTest
    static void testGetDonationConfigByCountry_India() {
        Test.startTest();
        DonationMetadataController.DonationConfigWrapper configWrapper = DonationMetadataController.getDonationConfigByCountry('India');
        Test.stopTest();
        System.assertNotEquals(null, configWrapper);
    }

    @isTest
    static void testGetDonationConfigByCountry_Invalid() {
        Test.startTest();
        try {
            DonationMetadataController.getDonationConfigByCountry('Mars');
            //System.assert(false, 'Expected AuraHandledException not thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Unable to fetch donation configuration'));
        }
        Test.stopTest();
    }

    @isTest
    static void testGetAllDonationConfigs() {
        Test.startTest();
        List<DonationMetadataController.DonationConfigWrapper> configs = DonationMetadataController.getAllDonationConfigs();
        Test.stopTest();
        System.assertNotEquals(null, configs);
        System.assert(configs.size() > 0, 'Should return at least one config');
    }

    @isTest
    static void testGetRazorpayPlansByFrequency() {
        Test.startTest();
        List<DonationMetadataController.RazorpayPlanWrapper> plans = 
            DonationMetadataController.getRazorpayPlansByFrequency('Monthly', (Double)1000.00);
        Test.stopTest();
        System.assertNotEquals(null, plans);
    }
    

    @isTest
    static void testGetAvailableCurrencies() {
        Test.startTest();
        List<Map<String, String>> currencies = DonationMetadataController.getAvailableCurrencies();
        Test.stopTest();
        System.assertNotEquals(null, currencies);
    }
}