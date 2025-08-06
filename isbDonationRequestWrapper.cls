/**
 * @description       : 
 * @author            : Jatin Prasad
 * @group             : 
 * @last modified on  : 07-20-2025
 * @last modified by  : Jatin Prasad
**/
public class isbDonationRequestWrapper {
    
    @AuraEnabled public Donation__c objDonation { get; set; }
    @AuraEnabled public Contact objContact { get; set; }
    @AuraEnabled public String affiliation { get; set; }
    @AuraEnabled public String geography { get; set; }
    @AuraEnabled public String paymentMode { get; set; }
    @AuraEnabled public String name { get; set; }
    @AuraEnabled public String email { get; set; }
    @AuraEnabled public String phone { get; set; }
    @AuraEnabled public String bankName { get; set; }
    @AuraEnabled public String chequeDate { get; set; }
    @AuraEnabled public String transactionDate { get; set; }
    @AuraEnabled public String transactionOrChequeNumber { get; set; }
    @AuraEnabled public String panNumber { get; set; }
    @AuraEnabled public String donationCurrency { get; set; }
    @AuraEnabled public Boolean anonymousDonation { get; set; }
    @AuraEnabled public Long amount { get; set; }
    @AuraEnabled public String programName { get; set; } // Added for program input
    @AuraEnabled public String contactClass { get; set; } // Added for class input
    @AuraEnabled public String pincode { get; set; } // Added for pincode input
    @AuraEnabled public String currentAddress { get; set; } // Added for current address input
    @AuraEnabled public String receiptPreference { get; set; } // Added for receipt preference
    @AuraEnabled public String frequency { get; set; } // Added for recurring payment frequency
    @AuraEnabled public Integer duration { get; set; } // Added for recurring payment duration
    @AuraEnabled public String planID {get; set;} //Added for planId for subscriptions
    @AuraEnabled public String paymentType {get; set;} //Added to track the payment type selected by user i.e oneTime/Recurrings
    @AuraEnabled public String subscriptionAmountType {get; set;} //To track predefined amount or other for subscription
    @AuraEnabled public Integer totalCount =0;
    @AuraEnabled public String transactionID {get; set;}
    @AuraEnabled public String organizationname {get; set;}
   // @AuraEnabled public Long startAtUnix;
   // @AuraEnabled public Decimal upfrontAmount;
    
    

    // Constructor to initialize and debug values
    public isbDonationRequestWrapper() {
        System.debug('affiliation: ' + affiliation);
       
        System.debug('phone: ' + phone);
        System.debug('bankName: ' + bankName);
        System.debug('chequeDate: ' + chequeDate);
        System.debug('transactionDate: ' + transactionDate);
        System.debug('transactionOrChequeNumber: ' + transactionOrChequeNumber);
        System.debug('panNumber: ' + panNumber);
        System.debug('donationCurrency: ' + donationCurrency);
        System.debug('anonymousDonation: ' + anonymousDonation);
        System.debug('amount: ' + amount);
        System.debug('programName: ' + programName);
        System.debug('contactClass: ' + contactClass);
        System.debug('pincode: ' + pincode);
        System.debug('currentAddress: ' + currentAddress);
        System.debug('receiptPreference: ' + receiptPreference);
        System.debug('frequency: ' + frequency);
        System.debug('duration: ' + duration);
    }
}