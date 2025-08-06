/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 07-14-2025
 * @last modified by  : Jatin Prasad
**/
public without sharing class DonationMetadataController {
    
    /**
     * Fetches donation configuration metadata based on country code
     * @param countryCode - The country code (IN, US, OT)
     * @return DonationConfigWrapper containing all metadata fields
     */
    @AuraEnabled(cacheable=true)
    public static DonationConfigWrapper getDonationConfigByCountry(String countryCode) {
        try {
            // Map country names to codes
            String mappedCountryCode = mapCountryToCode(countryCode);

            // Query custom metadata - using correct metadata type name
            List<Donation_Country_Configuration__mdt> configs = [
                SELECT Id, Label, Country_Code__c, Payable_To_Content__c, 
                       Tax_Notice_Content__c, Bank_Details__c, tax_line__c, 
                       tax_line_bank__c, tax_line_upi__c, text_below__c
                FROM Donation_Country_Configuration__mdt 
                WHERE Country_Code__c = :mappedCountryCode 
                LIMIT 1
            ];

            if (configs.isEmpty()) {
                throw new AuraHandledException('No configuration found for country code: ' + mappedCountryCode);
            }

            return new DonationConfigWrapper(configs[0]);

        } catch (Exception e) {
            System.debug('Error fetching donation config: ' + e.getMessage());
            throw new AuraHandledException('Unable to fetch donation configuration: ' + e.getMessage());
        }
    }
    
    /**
     * Maps country names to metadata codes
     * @param countryName - Country name from the UI
     * @return String - Corresponding metadata code
     */
    private static String mapCountryToCode(String countryName) {
        Map<String, String> countryCodeMap = new Map<String, String>{
            'India' => 'IN',
            'USA' => 'US',
            'Australia' => 'OT',
            'UK' => 'OT',
            'Canada' => 'OT',
            'Germany' => 'OT'
        };
        
        return countryCodeMap.get(countryName) != null ? 
               countryCodeMap.get(countryName) : 'OT'; // Default to 'OT' for other countries
    }
    
    /**
     * Fetches all available donation configurations
     * @return List of DonationConfigWrapper
     */
    @AuraEnabled(cacheable=true)
    public static List<DonationConfigWrapper> getAllDonationConfigs() {
        try {
            List<Donation_Country_Configuration__mdt> configs = [
                SELECT Id, Label, Country_Code__c, Payable_To_Content__c, 
                   Tax_Notice_Content__c, Bank_Details__c,
                   tax_line__c, tax_line_bank__c, tax_line_upi__c, text_below__c
            FROM Donation_Country_Configuration__mdt
            ORDER BY Label
            ];
            
            List<DonationConfigWrapper> wrappers = new List<DonationConfigWrapper>();
            for (Donation_Country_Configuration__mdt config : configs) {
                wrappers.add(new DonationConfigWrapper(config));
            }
            
            return wrappers;
            
        } catch (Exception e) {
            System.debug('Error fetching all donation configs: ' + e.getMessage());
            throw new AuraHandledException('Unable to fetch donation configurations: ' + e.getMessage());
        }
    }
    
    /**
     * Fetches Razorpay plan mappings based on frequency
     * @param frequency - The frequency (Monthly, Quarterly, Annually)
     * @param amount
     * @return List of RazorpayPlanWrapper containing all metadata fields
     */
    @AuraEnabled(cacheable=true)
    public static List<RazorpayPlanWrapper> getRazorpayPlansByFrequency(String frequency, double amount) {
        try {
            // Query Razorpay_Plan_Mapping__mdt
            List<Razorpay_Plan_Mapping__mdt> razorpayPlans = [
                SELECT Amount__c, Frequency__c, Plan_ID__c
                FROM Razorpay_Plan_Mapping__mdt
                WHERE Frequency__c = :frequency
                ORDER BY Amount__c ASC
            ];

            // Combine results into wrappers
            List<RazorpayPlanWrapper> wrappers = new List<RazorpayPlanWrapper>();
            for (Razorpay_Plan_Mapping__mdt plan : razorpayPlans) {
                wrappers.add(new RazorpayPlanWrapper(plan));
            }

            // Return null if no data is found
            return wrappers.isEmpty() ? null : wrappers;

        } catch (Exception e) {
            System.debug('Error fetching Razorpay plans: ' + e.getMessage());
            throw new AuraHandledException('Unable to fetch Razorpay plans: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAvailableCurrencies() {
        try {
            List<Map<String, String>> options = new List<Map<String, String>>();

            for (Donation_Amount_Conversion__mdt meta : [
                SELECT Donar_Currency__c, Name__c 
                FROM Donation_Amount_Conversion__mdt 
                ORDER BY Name__c
            ]) {
                if (String.isNotBlank(meta.Donar_Currency__c) && String.isNotBlank(meta.Name__c)) {
                    options.add(new Map<String, String>{
                        'label' => meta.Name__c,
                        'value' => meta.Donar_Currency__c
                    });
                }
            }

            return options;

        } catch (Exception e) {
            System.debug('Error fetching currency metadata: ' + e.getMessage());
            throw new AuraHandledException('Unable to fetch currency list: ' + e.getMessage());
        }
    }

    /**
     * Wrapper class for donation metadata
     */
    public class DonationConfigWrapper {
        @AuraEnabled
        public String payableToContent;
        @AuraEnabled
        public String taxNoticeContent;
        @AuraEnabled
        public String bankDetails;
        @AuraEnabled
        public String taxLine;
        @AuraEnabled
        public String taxLineBank;
        @AuraEnabled
        public String taxLineUpi;
        @AuraEnabled
        public String textBelow;

        public DonationConfigWrapper(Donation_Country_Configuration__mdt config) {
            this.payableToContent = config.Payable_To_Content__c;
            this.taxNoticeContent = config.Tax_Notice_Content__c;
            this.bankDetails = config.Bank_Details__c;
            this.taxLine = config.tax_line__c;
            this.taxLineBank = config.tax_line_bank__c;
            this.taxLineUpi = config.tax_line_upi__c;
            this.textBelow = config.text_below__c;
        }
    }
    
    /**
     * Wrapper class for Razorpay plan metadata
     */
    public class RazorpayPlanWrapper {
        @AuraEnabled
        public Double amount;
        @AuraEnabled
        public String frequency;
        @AuraEnabled
        public String planId;

        // Constructor for Razorpay_Plan_Mapping__mdt
        public RazorpayPlanWrapper(Razorpay_Plan_Mapping__mdt plan) {
            this.amount = plan.Amount__c;
            this.frequency = plan.Frequency__c;
            this.planId = plan.Plan_ID__c;
        }

        // Constructor for Custom_Subscription_PlanId__c
        public RazorpayPlanWrapper(Custom_Subscription_PlanId__c customPlan) {
            this.amount = customPlan.Amount__c;
            this.frequency = customPlan.Frequency__c;
            this.planId = customPlan.Plan_Id__c;
        }
    }
}