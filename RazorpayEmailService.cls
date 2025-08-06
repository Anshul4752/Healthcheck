/**
 * @description       : 
 * @author            : Anshul Verma
 * @group             : 
 * @last modified on  : 07-02-2025
 * @last modified by  : Anshul Verma
**/

public class RazorpayEmailService {
    
    public static void sendSubscriptionEmail(Subscription__c subscription, String templateDeveloperName) {

        
        // 1. Basic validation to ensure we can send an email.
        system.debug('RazorpayEmailService: Preparing to send email for Subscription ' + subscription.Id + ' using template "' + templateDeveloperName + '"');
        if (subscription == null || subscription.Contact__c == null) {
            System.debug('RazorpayEmailService ERROR: Cannot send email. Subscription or Contact is null.');
            return;
        }

        // 2. Find the Email Template record by its DeveloperName (API Name).
        EmailTemplate template;
        try {
            template = [SELECT Id, DeveloperName, HtmlValue FROM EmailTemplate WHERE DeveloperName = :templateDeveloperName LIMIT 1];
        } catch (QueryException e) {
            System.debug('RazorpayEmailService ERROR: Could not find Email Template with DeveloperName: ' + templateDeveloperName);
            return;
        }
        
        // 3. Prepare the email message.
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        OrgWideEmailAddress[] owea = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'give@isb.edu' LIMIT 1];
        if (!owea.isEmpty()) {
            mail.setOrgWideEmailAddressId(owea[0].Id);
        }
        // 4. Set the key parameters to use the template system.
        // The 'target' is the recipient (Contact, Lead, or User). Merge fields like {!Contact.FirstName} work.
        mail.setTargetObjectId(subscription.Contact__c); 
        system.debug('RazorpayEmailService: Target Object ID set to Contact ' + subscription.Contact__c);

        mail.setToAddresses(new List<String>{ subscription.Contact__r.Email });
        system.debug('RazorpayEmailService: To Address set to ' + subscription.Contact__r.Email);
        
        // The 'what' is the related record. Merge fields like {!Subscription__c.Status__c} work.
        mail.setWhatId(subscription.Id);
        system.debug('RazorpayEmailService: What Object ID set to Subscription ' + subscription.Id);
        
        // Use the template we found.
        mail.setTemplateId(template.Id);
        system.debug('RazorpayEmailService: Email Template ID set to ' + template.Id);
        
        // Set this to false to prevent cluttering the contact's activity history with automated notifications.
        mail.setSaveAsActivity(false);
        system.debug(mail);

        

        // 5. Send the email and handle any errors.
        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            System.debug('RazorpayEmailService SUCCESS: Sent email using template "' + templateDeveloperName + '" for Subscription ' + subscription.Id);
        } catch (Exception e) {
            System.debug('RazorpayEmailService DML ERROR: Failed to send email. Details: ' + e.getMessage());
        }
    }
}