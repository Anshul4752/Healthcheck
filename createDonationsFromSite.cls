/**
 * @description       : Offline Donation creation from ISB Site. Includes robust email sending and currency conversion for all related records.
 * @author            : Anshul Verma
 * @group             : 
 * @last modified on  : 08-04-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class createDonationsFromSite {
 
    @AuraEnabled
    public static void createOfflineDonationFromSite(isbDonationRequestWrapper input) {
        System.debug('STARTED createOfflineDonationFromSite with input: ' + input);
        
        Savepoint sp = Database.setSavepoint();
        Contact cont;

        try {
            Decimal amountInINR = input.amount;
            Decimal forexRate = 1;

            // Check if the currency is not INR and is provided. If it's INR, no conversion is needed.
            if (String.isNotBlank(input.donationCurrency) && !'INR'.equalsIgnoreCase(input.donationCurrency)) {
                System.debug('Donation is in ' + input.donationCurrency + '. Querying for conversion rate.');

                // Dynamically query for the conversion rate based on the input currency
                List<Donation_Amount_Conversion__mdt> rates = [
                    SELECT Forex_Rate_to_INR__c
                    FROM Donation_Amount_Conversion__mdt
                    WHERE Donar_Currency__c = :input.donationCurrency
                    LIMIT 1
                ];

                // If a rate is found, apply it
                if (!rates.isEmpty() && rates[0].Forex_Rate_to_INR__c != null) {
                    forexRate = rates[0].Forex_Rate_to_INR__c;
                    amountInINR = input.amount * forexRate;
                    System.debug('Conversion rate for ' + input.donationCurrency + ' found: ' + forexRate + '. Converted amount to INR: ' + amountInINR);
                } else {
                    // Log a warning if no specific rate was found in the metadata
                    System.debug('WARNING: No ' + input.donationCurrency + ' conversion rate found in Custom Metadata. Using a 1:1 rate.');
                }
            } else {
                System.debug('Donation is in INR or currency is not specified. No conversion needed.');
            }
            
            // Fetch Record Types
            Id pledgRecordType = Schema.SObjectType.Pledges_Summary__c.getRecordTypeInfosByName().get('Offline Donation').getRecordTypeId();
            Id subPledgeRecType = Schema.SObjectType.Pledge_details__c.getRecordTypeInfosByName().get('Offline Donation').getRecordTypeId();
            Id contactRecTypeOther = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Others').getRecordTypeId();
            Id accntRecTypeAdmin = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Administrative').getRecordTypeId();
            Id donationRecType = Schema.SObjectType.Donation__c.getRecordTypeInfosByName().get('Offline Donation').getRecordTypeId();
            
            Account accnt;
    
            // If Contact is not existing, create one
            if (input.objContact == null || input.objContact.Id == null) {
                System.debug('Creating new contact for email: ' + input.email);
                
                List<Account> devAccs = [SELECT Id FROM Account WHERE Name = 'Development' AND RecordType.Name = 'Business Organization' LIMIT 1];

                cont = new Contact(
                    FirstName = input.name, LastName = input.name, RecordTypeId = contactRecTypeOther,
                    Email = input.email, MobilePhone = input.phone, PAN_Number__c = input.panNumber
                );

                if (input.affiliation == System.Label.DonationAffOrganization || input.affiliation == System.Label.DonationAffAlumni) {
                    if(!devAccs.isEmpty()) { cont.AccountId = devAccs[0].Id; }
                    insert cont;
                } else if (input.affiliation == System.Label.DonationAffNonAlum || input.affiliation == System.Label.DonationAffCo) {
                    accnt = new Account(Name = input.name + ' Account', RecordTypeId = accntRecTypeAdmin);
                    insert accnt;
                    cont.AccountId = accnt.Id;
                    insert cont;
                }
            } else {
                cont = [SELECT Id, Email FROM Contact WHERE Id = :input.objContact.Id];
                System.debug('Using Existing Contact: ' + cont.Id + ' with Email: ' + cont.Email);
            }

            Map<String, String> paymentModes = getPaymentModeMappings(input.paymentMode, input.geography);
            // Insert Pledges_Summary__c
            Pledges_Summary__c ps = new Pledges_Summary__c(
                Pledged_Amount_In_donor_currency__c = input.amount, // Original donor amount
                Pledge__c = amountInINR,                            // Converted INR amount
                Pledge_Received__c = amountInINR,  
                ForexRatetoINR__c = forexRate,                  // Converted INR amount
                NoOfSubPledges__c = 1, RecordTypeId = pledgRecordType, Transaction_Status__c = 'Not Paid', 
                Purpose__c = 'General', PledgeType__c = 'Cash', Date_to_Pledge__c = System.today(), 
                PledgeEnddate__c = System.today(), Contact_Email__c = input.email, PAN_No__c = input.panNumber, 
                Currency__c = input.donationCurrency, Name__c = cont.Id,
                Mode_of_Payment__c = paymentModes.get('summary'), 
                Is_donation_Anonymous__c = input.anonymousDonation ? 'Yes' : 'No'
            );
            insert ps;
            System.debug('Inserted Pledge Summary: ' + ps.Id);
            Pledges_Summary__c psname = [SELECT Id,Name from Pledges_Summary__c where Id =: ps.Id];
            system.debug('Pledge Summary Name: ' + psname.Name);

            // Insert Pledge_details__c
            Pledge_details__c pd = new Pledge_details__c(
                Name = psname.Name + '-' + 1,
                Currency__c = input.donationCurrency,
                Sub_Pledge_Amount__c = input.amount, 
                //ForEx_Rate_to_INR__c = forexRate,               // Original donor amount
                //Sub_Pledge_Amount_in_INR__c = amountInINR,          // Converted INR amount (See Note Below)
                Pledge_Summary__c = ps.Id, PLD_Status__c = 'Not Paid', Contact_Email__c = input.email, 
                RecordTypeId = subPledgeRecType, Classification_of_Gift__c = 'Other Gift',
                Restricted_Gift__c = 'No', No_Of_Installments_Left__c = 0, Endowment__c = 'General',
                Mode_of_Payment__c = paymentModes.get('detail'), 
                Name__c = cont.Id, NoOfInstallments__c = 1
            );
            insert pd;
            System.debug('Inserted Pledge Details: ' + pd.Id);
            System.debug('Pledge Detail Name: ' + psname.Name);
            // Insert Donation__c
            Donation__c donation = new Donation__c(
                Name = psname.Name + '-' + 1 +'-'+ 1, Pledge_detail__c = pd.Id, Pledge__c = ps.Id, Name__c = cont.Id, 
                //Remittance_Amount__c = input.amount,
                Amount__c = input.amount,
                Outstanding_Amount__c = input.amount,              // Original donor amount
                Installment_Amount_In_Pledge_Currency__c = input.amount, // Original donor amount
                Installment_Amount_INR__c = amountInINR,              // Converted INR
                ForexRatetoINR__c = forexRate,                      // The conversion rate used
                Currency__c = input.donationCurrency, Donation_Status__c = 'Not Paid', PAN_No__c = input.panNumber,
                RecordTypeId = donationRecType, gift_to_be_anonymous__c = input.anonymousDonation, 
                Cheque_Transaction_Ref_no__c = input.transactionOrChequeNumber,
                Name_on_the_donation_form__c = input.name, Donor_s_Phone_Number__c = input.phone,
                Outstanding_Amount_INR__c = amountInINR
            );
            insert donation;
            System.debug('Donation process completed successfully. Preparing to send email for Donation ID: ' + donation.Id);

            // Call the separate email sending method with the correct Donation ID
            sendConfirmationEmail(cont, donation.Id,input.geography);

        } catch (Exception e) {
            Database.rollback(sp);
            System.debug('An error occurred during donation creation. Transaction rolled back. Error: ' + e.getMessage() + ' at line ' + e.getLineNumber());
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static void sendConfirmationEmail(Contact recipient, Id whatId, String geography) {
        if (recipient == null || String.isBlank(recipient.Email)) {
            System.debug('Email not sent. The contact record or the email address is blank.');
            return;
        }

        // Determine email template based on geography
        String templateDeveloperName = getEmailTemplateByGeography(geography);
        System.debug('Selected email template: ' + templateDeveloperName + ' for geography: ' + geography);

        List<EmailTemplate> templates = [SELECT Id FROM EmailTemplate WHERE DeveloperName = :templateDeveloperName LIMIT 1];
        if (templates.isEmpty()) {
            System.debug('Email not sent. The template "' + templateDeveloperName + '" was not found.');
            return;
        }
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        OrgWideEmailAddress[] owea = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'give@isb.edu' LIMIT 1];
        if (!owea.isEmpty()) {
            mail.setOrgWideEmailAddressId(owea[0].Id);
        }
        mail.setTemplateId(templates[0].Id);
        mail.setTargetObjectId(recipient.Id);
        mail.setWhatId(whatId);
        mail.setToAddresses(new List<String>{ recipient.Email });
        mail.setSaveAsActivity(false);
        System.debug('Attempting to send confirmation email to: ' + recipient.Email + ' using template: ' + templateDeveloperName);

        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            System.debug('Confirmation email sent successfully using template: ' + templateDeveloperName);
        } catch (Exception e) {
            // Log the email error but do NOT throw an exception, as the donation was already created.
            System.debug('CRITICAL: Donation was created, but failed to send confirmation email. Error: ' + e.getMessage());
        }
    }

    private static String getEmailTemplateByGeography(String geography) {
        if (String.isBlank(geography)) {
            System.debug('Geography is blank, defaulting to India template');
            return 'Offline_Donation_Pledge_Confirmation';
        }

        String normalizedGeography = geography.toLowerCase().trim();
        
        switch on normalizedGeography {
            when 'usa', 'united states', 'us' {
                return 'offline_donation_mail_for_usa';
            }
            when 'india', 'in' {
                return 'Offline_Donation_Pledge_Confirmation';
            }
            when else {
                // For all other countries/regions
                return 'offline_donation_mail_for_others';
            }
        }
    }

     private static Map<String, String> getPaymentModeMappings(String mode, String geography) {
        Map<String, String> paymentModes = new Map<String, String>{
            'summary' => 'Other',
            'detail' => 'Other'
        };

        if (String.isBlank(mode)) {
            return paymentModes;
        }

        switch on mode.toLowerCase() {
            when 'cheque' {
                paymentModes.put('summary', 'Cheque/ DD');
                paymentModes.put('detail', 'Cheque');
            }
            when 'bank' {
                paymentModes.put('summary', 'Bank Transfer');
                paymentModes.put('detail', 'Payment Gateway');
            }
            when 'wire transfer' {
                paymentModes.put('summary', 'Wire Transfer');
                paymentModes.put('detail', 'Wire Transfer');
            }
        }
        return paymentModes;
    }
}