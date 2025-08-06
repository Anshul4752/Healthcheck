/**
 * @description       : Controller for the donation form, handling contact lookup and OTP verification.
 *                      This version uses Platform Cache to correctly store the OTP between calls.
 * @author            : Anshul Verma
 * @group             : 
 * @last modified on  : 07-29-2025
 * @last modified by  : Jatin Prasad
**/
public without sharing class DonationController {

    public class VerificationResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Contact contactRecord;
        @AuraEnabled public String contactId;
        @AuraEnabled public Boolean contactNotFound;
    }

    @AuraEnabled(cacheable=false)
    public static VerificationResult findContactAndSendOtp(String email, String affiliation) {
        VerificationResult result = new VerificationResult();
        result.success = false;
        result.contactNotFound = false;
    
        if (String.isBlank(email) || String.isBlank(affiliation)) {
            result.message = 'Email and Affiliation are required.';
            return result;
        }
    
        String sanitizedEmail = email.trim().toLowerCase();
        List<Contact> contacts;
        String contactName = 'Valued Supporter';
    
        try {
            // Match email across all specified fields
            String emailMatch = 'Almashines_EmailID__c = :sanitizedEmail OR ' +
                                'DL_ISB_EmailID__c = :sanitizedEmail OR ' +
                                'EE_ISB_EmailID__c = :sanitizedEmail OR ' +
                                'Email = :sanitizedEmail OR ' +
                                'hed__AlternateEmail__c = :sanitizedEmail OR ' +
                                'hed__WorkEmail__c = :sanitizedEmail OR ' +
                                'InvoiceEmail__c = :sanitizedEmail OR ' +
                                'ISB_Email_ID__c = :sanitizedEmail OR ' +
                                'Official_Email_ID__c = :sanitizedEmail OR ' +
                                'Personal_Email__c = :sanitizedEmail OR ' +
                                'Personal_Email_ID_1__c = :sanitizedEmail OR ' +
                                'Personal_Email_ID_2__c = :sanitizedEmail';
    
            if (affiliation.equalsIgnoreCase('Alumni')) {
                contacts = Database.query(
                    'SELECT Id, Name FROM Contact WHERE (' + emailMatch + ') AND (Alumni__c = TRUE OR Associate_Alumni__c = TRUE) LIMIT 1'
                );
                if (contacts.isEmpty()) {
                    result.success = true;
                    result.contactNotFound = true;
                    result.message = 'No alumni record exists for entered email.';
                    return result;
                }
            } else if (affiliation.equalsIgnoreCase('Student')) {
                contacts = Database.query(
                    'SELECT Id, Name FROM Contact WHERE (' + emailMatch + ') AND (Student__c = TRUE OR Associate_Student__c = TRUE) LIMIT 1'
                );
                if (contacts.isEmpty()) {
                    result.message = 'No student record exists for entered email.';
                    result.success = true;
                    result.contactNotFound = true;
                    return result;
                }
            } else if (affiliation.equalsIgnoreCase('Non-Alumni') || affiliation.equalsIgnoreCase('Corporate')) {
                contacts = Database.query('SELECT Id, Name FROM Contact WHERE ' + emailMatch + ' LIMIT 1');
                if (contacts.isEmpty()) {
                    result.success = true;
                    result.contactNotFound = true;
                    result.message = 'Contact not found. User can choose to continue.';
                    return result;
                }
            } else {
                result.message = 'Invalid affiliation selected.';
                return result;
            }
    
            contactName = contacts[0].Name;
    
            String generatedOtp = String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 6);
            String cacheKey = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-1', Blob.valueOf(sanitizedEmail)));
    
            String partitionName = 'local.DonationOtp';
            Cache.OrgPartition otpPartition = Cache.Org.getPartition(partitionName);
            if (otpPartition == null) {
                throw new AuraHandledException('Verification service is not configured. Please contact the administrator.');
            }
    
            otpPartition.put(cacheKey, generatedOtp, 300);
            sendOtpEmail(sanitizedEmail, contactName, generatedOtp);
    
            result.success = true;
            result.message = 'An OTP has been sent to your registered email ID.';
            return result;
    
        } catch (Exception e) {
            result.message = 'An unexpected server error occurred: ' + e.getMessage();
            return result;
        }
    }
    

    /**
     * @description Private helper method to construct and send the OTP email.
     */
    private static void sendOtpEmail(String recipientEmail, String contactName, String otp) {
        List<OrgWideEmailAddress> lstEmailAddress = [
            SELECT Id FROM OrgWideEmailAddress WHERE Address = 'give@isb.edu' LIMIT 1
        ];
        if (lstEmailAddress.isEmpty()) {
            throw new AuraHandledException('Email service is not configured. Please contact your administrator.');
        }

        // Determine additional recipient email based on hed__Preferred_Email__c
    //     List<Contact> contactDetails = [SELECT ISB_Email_ID__c, hed__Preferred_Email__c, Personal_Email_ID_1__c, Personal_Email_ID_2__c, Personal_Email__c,Email,
    //                                      Official_Email_ID__c, hed__AlternateEmail__c 
    //                                      FROM Contact WHERE ISB_Email_ID__c = :recipientEmail OR Email=:recipientEmail LIMIT 1];
    //     String additionalEmail = null;
    //     if (!contactDetails.isEmpty()) {
    //         Contact contact = contactDetails[0];
           
            
    //         if (contact.hed__Preferred_Email__c == 'Personal Email ID 1' && contact.Personal_Email_ID_1__c != null) {
    //             additionalEmail = contact.Personal_Email_ID_1__c;
    //         } else if (contact.hed__Preferred_Email__c == 'Personal Email ID 2' && contact.Personal_Email_ID_2__c != null) {
    //             additionalEmail = contact.Personal_Email_ID_2__c;
    //         } else if (contact.hed__Preferred_Email__c == 'Official Email ID' && contact.Official_Email_ID__c != null) {
    //             additionalEmail = contact.Official_Email_ID__c;
    //         } else if (contact.hed__Preferred_Email__c == 'Alternate' && contact.hed__AlternateEmail__c != null) {
    //             additionalEmail = contact.hed__AlternateEmail__c;
    //         }
    //         else if (contact.hed__Preferred_Email__c == 'Personal Email' && contact.Personal_Email__c != null) {
    //             additionalEmail = contact.Personal_Email__c;
    //         }
    //         else {
    //             // Fallback logic if no valid preferred email is found
    //             additionalEmail = contact.Email ; // or null or any default handling
    //         }

    //     }

    //     Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    //     List<String> toAddresses = new List<String> { recipientEmail };
    //     if (additionalEmail != null) {
    //         toAddresses.add(additionalEmail);
    //     }
    //     mail.setToAddresses(toAddresses);
    //     mail.setOrgWideEmailAddressId(lstEmailAddress[0].Id);
    //     mail.setSubject('Your One-Time Password (OTP) from ISB');
        
    //     String body = 'Dear ' + contactName + ',\n\n' +
    //                   'Thank you for your interest in supporting the Indian School of Business. Please use the following One-Time Password (OTP) to verify your identity:\n\n' +
    //                   'Your OTP is: ' + otp + '\n\n' +
    //                   'This OTP is valid for 5 minutes. Please enter this on the donation verification page.\n\n' +
    //                   'If you did not initiate this request, please disregard this email or contact us at give@isb.edu.\n\n' +
    //                   'We sincerely appreciate your generosity.\n\n' +
    //                   'Regards,\n' +
    //                   'Office of Advancement\n' +
    //                   'Indian School of Business';
                      
    //     mail.setPlainTextBody(body);
    //     Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    // }

    List<Contact> contacts = [
        SELECT Almashines_EmailID__c, DL_ISB_EmailID__c, EE_ISB_EmailID__c,
               Email, hed__AlternateEmail__c, hed__WorkEmail__c, InvoiceEmail__c,
               ISB_Email_ID__c, Official_Email_ID__c, Personal_Email__c,
               Personal_Email_ID_1__c, Personal_Email_ID_2__c
        FROM Contact
        WHERE Almashines_EmailID__c = :recipientEmail OR
              DL_ISB_EmailID__c = :recipientEmail OR
              EE_ISB_EmailID__c = :recipientEmail OR
              Email = :recipientEmail OR
              hed__AlternateEmail__c = :recipientEmail OR
              hed__WorkEmail__c = :recipientEmail OR
              InvoiceEmail__c = :recipientEmail OR
              ISB_Email_ID__c = :recipientEmail OR
              Official_Email_ID__c = :recipientEmail OR
              Personal_Email__c = :recipientEmail OR
              Personal_Email_ID_1__c = :recipientEmail OR
              Personal_Email_ID_2__c = :recipientEmail
        LIMIT 1
    ];

    Set<String> toAddresses = new Set<String>();

    if (!contacts.isEmpty()) {
        Contact c = contacts[0];

        if (c.Almashines_EmailID__c == recipientEmail) toAddresses.add(c.Almashines_EmailID__c);
        if (c.DL_ISB_EmailID__c == recipientEmail) toAddresses.add(c.DL_ISB_EmailID__c);
        if (c.EE_ISB_EmailID__c == recipientEmail) toAddresses.add(c.EE_ISB_EmailID__c);
        if (c.Email == recipientEmail) toAddresses.add(c.Email);
        if (c.hed__AlternateEmail__c == recipientEmail) toAddresses.add(c.hed__AlternateEmail__c);
        if (c.hed__WorkEmail__c == recipientEmail) toAddresses.add(c.hed__WorkEmail__c);
        if (c.InvoiceEmail__c == recipientEmail) toAddresses.add(c.InvoiceEmail__c);
        if (c.ISB_Email_ID__c == recipientEmail) toAddresses.add(c.ISB_Email_ID__c);
        if (c.Official_Email_ID__c == recipientEmail) toAddresses.add(c.Official_Email_ID__c);
        if (c.Personal_Email__c == recipientEmail) toAddresses.add(c.Personal_Email__c);
        if (c.Personal_Email_ID_1__c == recipientEmail) toAddresses.add(c.Personal_Email_ID_1__c);
        if (c.Personal_Email_ID_2__c == recipientEmail) toAddresses.add(c.Personal_Email_ID_2__c);
    }

    if (!toAddresses.isEmpty()) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>(toAddresses));
        mail.setOrgWideEmailAddressId(lstEmailAddress[0].Id);
        mail.setSubject('Your One-Time Password (OTP) from ISB');

        String body = 'Dear ' + contactName + ',\n\n' +
                      'Thank you for your interest in supporting the Indian School of Business. Please use the following One-Time Password (OTP) to verify your identity:\n\n' +
                      'Your OTP is: ' + otp + '\n\n' +
                      'This OTP is valid for 5 minutes. Please enter this on the donation verification page.\n\n' +
                      'If you did not initiate this request, please disregard this email or contact us at give@isb.edu.\n\n' +
                      'We sincerely appreciate your generosity.\n\n' +
                      'Regards,\n' +
                      'Office of Advancement\n' +
                      'Indian School of Business';

        mail.setPlainTextBody(body);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    } else {
        throw new AuraHandledException('No matching email field found to send OTP.');
    }
}

@AuraEnabled(cacheable=false)
public static VerificationResult verifyOtpAndFetchContact(String email, String otp, String affiliation) {
    VerificationResult result = new VerificationResult();
    result.success = false;

    String sanitizedEmail = email.trim().toLowerCase();
    String sanitizedOtp = otp.trim();

    // Create cache key from email
    String cacheKey = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-1', Blob.valueOf(sanitizedEmail)));

    // Retrieve OTP from cache
    Cache.OrgPartition otpPartition = Cache.Org.getPartition('local.DonationOtp');
    if (otpPartition == null) {
        result.message = 'Verification service is temporarily unavailable. Please try again later.';
        return result;
    }

    String storedOtp = (String) otpPartition.get(cacheKey);

    if (storedOtp != null && storedOtp.equals(sanitizedOtp)) {
        otpPartition.remove(cacheKey);

        try {
            List<Contact> contacts;
            String emailMatch = 'Almashines_EmailID__c = :sanitizedEmail OR ' +
                                'DL_ISB_EmailID__c = :sanitizedEmail OR ' +
                                'EE_ISB_EmailID__c = :sanitizedEmail OR ' +
                                'Email = :sanitizedEmail OR ' +
                                'hed__AlternateEmail__c = :sanitizedEmail OR ' +
                                'hed__WorkEmail__c = :sanitizedEmail OR ' +
                                'InvoiceEmail__c = :sanitizedEmail OR ' +
                                'ISB_Email_ID__c = :sanitizedEmail OR ' +
                                'Official_Email_ID__c = :sanitizedEmail OR ' +
                                'Personal_Email__c = :sanitizedEmail OR ' +
                                'Personal_Email_ID_1__c = :sanitizedEmail OR ' +
                                'Personal_Email_ID_2__c = :sanitizedEmail';

            String baseFields = 'Id, Name, FirstName, LastName, Email, ISB_Email_ID__c, Phone, PAN_Number__c, ' +
                                'Class__c, Program__r.Name, Current_Address_Line_1__c, Current_Postal_Code__c, ' +
                                'hed__Preferred_Email__c';

            if (affiliation.equalsIgnoreCase('Alumni') || affiliation.equalsIgnoreCase('Student')) {
                contacts = Database.query(
                    'SELECT ' + baseFields + ' FROM Contact WHERE (' + emailMatch + ') LIMIT 1'
                );
            } else {
                contacts = Database.query(
                    'SELECT ' + baseFields + ' FROM Contact WHERE (' + emailMatch + ') LIMIT 1'
                );
            }

            if (!contacts.isEmpty()) {
                result.success = true;
                result.message = 'The OTP has been verified.';
                result.contactRecord = contacts[0];
                result.contactId = contacts[0].Id;
            } else {
                result.message = 'Could not retrieve contact details after verification.';
            }

        } catch (Exception e) {
            result.message = 'Error fetching contact details: ' + e.getMessage();
        }

    } else {
        if (storedOtp == null) {
            result.message = 'The OTP has expired or was not found. Please request a new OTP.';
        } else {
            result.message = 'The OTP entered is incorrect. Please try again.';
        }
    }

    return result;
}

}