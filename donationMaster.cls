/**
 * @description       : Donation processing logic
 * @last modified on  : 07-29-2025
 * @last modified by  : Jatin Prasad
**/

public without sharing class donationMaster {
    @AuraEnabled
    //method to process donation wrapper
    public static isbDonationRequestWrapper processWrapper(isbDonationRequestWrapper wrapper) {
        try {
            // Step 1: Create contact/account if contact ID is not present
            if (wrapper.objContact == null || String.isBlank(wrapper.objContact.Id)) {
                createContactAndAccount(wrapper);
            }
            
            // Step 2: Route to the appropriate payment processor
           System.debug('wrapper : '+ wrapper.objContact);
            return wrapper;

        } catch (Exception e) {
            System.debug('Error in processWrapper: ' + e.getMessage());
            // Use a generic AuraHandledException or just rethrow as an Exception
            throw new AuraHandledException('Failed to process donation wrapper: ' + e.getMessage());
        }
    }
    
    // Method to route to the appropriate payment processor
    @AuraEnabled
    public static isbDonationResponseWrapper routeToPaymentProcessor(isbDonationRequestWrapper wrapper) {
        if (String.isBlank(wrapper.paymentType)) {
            throw new AuraHandledException('Payment type is required');
        }
        isbDonationResponseWrapper response;

        switch on wrapper.paymentType.toLowerCase() {
            when 'onetime' {
               //Id transactionId =  donationOneTime.createTransactionDetailNew(wrapper);
               response =  donationOneTime.donationFormNew(wrapper);
               return response;
            }
            when 'recurring' {
                 response = DonationsRecurringPaymentAPI.checkForActiveSubscription(wrapper);
                 return response;
            }
            when 'offline' {
                // OfflinePaymentProcessor.processPayment(wrapper);
                createDonationsFromSite.createOfflineDonationFromSite(wrapper);
                
            }
            when else {
                throw new AuraHandledException('Invalid payment type: ' + wrapper.paymentMode + 
                                               '. Valid types are: onetime, subscription, offline');
            }
        }
        return response;
    }
    
    // Method to create contact and account based on affiliation
    public static void createContactAndAccount(isbDonationRequestWrapper wrapper) {
        try {
            System.debug('Starting createContactAndAccount method');
            if (wrapper == null) {
                System.debug('Wrapper is null');
                throw new AuraHandledException('Wrapper cannot be null');
            }
            if (String.isBlank(wrapper.affiliation)) {
                System.debug('Affiliation is blank');
                throw new AuraHandledException('Affiliation is required');
            }
            if (String.isBlank(wrapper.name)) {
                System.debug('Name is blank');
                throw new AuraHandledException('Name is required');
            }
            if (String.isBlank(wrapper.email)) {
                System.debug('Email is blank');
                throw new AuraHandledException('Email is required');
            }
            System.debug('Wrapper details: ' + JSON.serialize(wrapper));
            if (wrapper.affiliation == 'non-alumni'|| wrapper.affiliation == 'Other Individuals') {
                createNonAlumniContactAndAccount(wrapper);
            } else if (wrapper.affiliation == 'corporate'||wrapper.affiliation == 'Organisation'||wrapper.affiliation=='student'||wrapper.affiliation=='alumni'||wrapper.affiliation=='Alumni'||wrapper.affiliation=='Student') {
                createCorporateContactAndAccount(wrapper);
            } else {
                System.debug('Invalid affiliation: ' + wrapper.affiliation);
                throw new AuraHandledException('Invalid affiliation: ' + wrapper.affiliation + 
                                               '. Valid affiliations are: Non Alumni, Corporate');
            }
        } catch (Exception e) {
            System.debug('Error in createContactAndAccount: ' + e.getMessage());
            throw new AuraHandledException('Failed to create contact and account: ' + e.getMessage());
        }
    }
    
    // Create contact and account for Non Alumni affiliation
    private static void createNonAlumniContactAndAccount(isbDonationRequestWrapper wrapper) {
        System.debug('Starting createNonAlumniContactAndAccount method');
        if (wrapper == null || String.isBlank(wrapper.name) || String.isBlank(wrapper.email)) {
            System.debug('Wrapper, name, or email is null/blank');
            throw new AuraHandledException('Wrapper, name, and email cannot be null or blank');
        }
        if (wrapper.phone == null) {
            System.debug('Phone is null');
            throw new AuraHandledException('Phone number is required for Non Alumni affiliation');
        }
        // System.debug('Wrapper details: ' + JSON.serialize(wrapper));
        Id contactRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('ISB_Admission_process').getRecordTypeId();
        Id accountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Administrative').getRecordTypeId();
        
        Account newAccount = new Account(
            // Name = wrapper.name + ' Account',
            Name = wrapper.name.substring(0, Math.min(6, wrapper.name.length())) + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 6),

            RecordTypeId = accountRecordTypeId
        );
        insert newAccount;
        
        // Use the helper method to parse the name
        Map<String, String> nameParts = parseFullName(wrapper.name);
        
        Contact newContact = new Contact(
            FirstName = nameParts.get('firstName'),
            LastName = nameParts.get('lastName'),
            Email = wrapper.email,
            Phone = wrapper.phone,
            AccountId = newAccount.Id,
            RecordTypeId = contactRecordTypeId,
            Personal_Email__c = wrapper.email, 
            hed__Preferred_Email__c = 'Personal Email'
        );
        
        insert newContact;

        wrapper.objContact = newContact;
        System.debug('Created Non Alumni Contact and Account - Contact ID: ' + newContact.Id);
    }
    
    // Create contact and account for Corporate affiliation
    private static void createCorporateContactAndAccount(isbDonationRequestWrapper wrapper) {
        System.debug('Starting createCorporateContactAndAccount method');
        if (wrapper == null || String.isBlank(wrapper.name) || String.isBlank(wrapper.email)) {
            System.debug('Wrapper, name, or email is null/blank');
            throw new AuraHandledException('Wrapper, name, and email cannot be null or blank');
        }
        if (wrapper.phone == null) {
            System.debug('Phone is null');
            throw new AuraHandledException('Phone number is required for Corporate affiliation');
        }
        // System.debug('Wrapper details: ' + JSON.serialize(wrapper));
        Id contactRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Others').getRecordTypeId();
        Id accountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Developments').getRecordTypeId();
        
        Account newAccount = new Account(
            // Name = wrapper.name,
            Name = wrapper.name.substring(0, Math.min(6, wrapper.name.length())) + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 6),

            RecordTypeId = accountRecordTypeId
        );
        insert newAccount;

        Map<String, String> nameParts = parseFullName(wrapper.name);

        Contact newContact = new Contact(
            FirstName = nameParts.get('firstName'),
            LastName = nameParts.get('lastName'),
            Email = wrapper.email,
            Phone = wrapper.phone,
            AccountId = newAccount.Id,
            RecordTypeId = contactRecordTypeId,
            Personal_Email__c = wrapper.email, 
            hed__Preferred_Email__c = 'Personal Email'
        );
        if (String.isNotBlank(wrapper.organizationname)) {
            newContact.Current_Organization__c = wrapper.organizationname;
        }
        insert newContact;

        wrapper.objContact = newContact;
        System.debug('Created Corporate Contact and Account - Contact ID: ' + newContact.Id);
    }
    private static Map<String, String> parseFullName(String fullName) {
        Map<String, String> nameParts = new Map<String, String>{
            'firstName' => '',
            'lastName' => ''
        };
        
        if (String.isBlank(fullName)) {
            return nameParts;
        }

        String trimmedName = fullName.trim();
        Integer firstSpace = trimmedName.indexOf(' ');

        if (firstSpace > 0) {
            // If there's a space, split the name
            nameParts.put('firstName', trimmedName.substring(0, firstSpace));
            nameParts.put('lastName', trimmedName.substring(firstSpace + 1).trim());
        } else {
            // If there's no space, use the whole string as the last name.
            nameParts.put('lastName', trimmedName);
        }
        return nameParts;
    }
}