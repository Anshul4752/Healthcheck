/**
 * @description       : Handles sending templated emails for Razorpay subscription events,
 *                      such as initial activation and subsequent charges.
 * @author            : Anshul Verma
 * @group             : 
 * @last modified on  : 07-01-2025
 * @last modified by  : Anshul Verma
**/
public class RazorpayChargedEmailService {
    public static void sendActivationNotification(Id subscriptionId) {
        // Calls the private worker method with the specific 'Activated' template name
        sendEmailFromTemplate(subscriptionId, 'Donor_Subscription_Activated');
    }
    public static void sendChargedNotification(Id subscriptionId) {
        // Calls the private worker method with the specific 'Charged' template name
        sendEmailFromTemplate(subscriptionId, 'Donor_Subscription_Charged');
    }

    // --- PRIVATE WORKER METHOD ---
    // This private method contains all the shared logic to prevent code duplication.
    private static void sendEmailFromTemplate(Id subscriptionId, String templateDeveloperName) {

        // Step 1: Query all the necessary data.
        Subscription__c sub = [
            SELECT Id, Subscription_ID__c, Start_At__c, End_At__c, Frequency__c, Plan_ID__c,
                   Contact__r.Id, Contact__r.FirstName, Contact__r.Email
            FROM Subscription__c 
            WHERE Id = :subscriptionId 
            LIMIT 1
        ];

        if (sub == null || String.isBlank(sub.Contact__r.Email)) {
            System.debug('RazorpayChargedEmailService: Error - Subscription or Contact email not found for ID: ' + subscriptionId);
            return;
        }
        
        // Find the most recent payment record linked to this subscription
        List<Pledge_details__c> latestPaymentList = [
            SELECT Id, Amount__c, Currency__c, Transaction_date__c, Transaction_Cheque_No__c, Mode_of_Payment__c
            FROM Pledge_details__c 
            WHERE Subscription__c = :subscriptionId 
            ORDER BY LastModifiedDate DESC 
            LIMIT 1
        ];

        Transaction_Details__c transactionDetail = null;

        if (!latestPaymentList.isEmpty()) {
            Pledge_details__c latestPayment = latestPaymentList[0];
            try {
                // Find the corresponding Transaction_Details__c record
                transactionDetail = [
                    SELECT Id, Transaction_ID__c 
                    FROM Transaction_Details__c 
                    WHERE Pledge_detail__c = :latestPayment.Id
                    ORDER BY CreatedDate DESC 
                    LIMIT 1
                ];
                System.debug('RazorpayChargedEmailService: Found Transaction_Details__c for Pledge_detail__c ' + latestPayment.Id + '. TD ID: ' + transactionDetail.Id);
            } catch (QueryException e) {
                System.debug('RazorpayChargedEmailService: Could not find Transaction_Details__c for Pledge_detail__c ID: ' + latestPayment.Id + '. Error: ' + e.getMessage());
            }
        } else {
            System.debug('RazorpayChargedEmailService: No Pledge_details__c found for subscription ID: ' + subscriptionId + '. Payment-related fields will be N/A.');
        }

        // Step 2: Get the specified email template.
        EmailTemplate et;
        try {
            et = [SELECT Subject, HtmlValue FROM EmailTemplate WHERE DeveloperName = :templateDeveloperName LIMIT 1];
        } catch (QueryException e) {
            System.debug('RazorpayChargedEmailService: FATAL ERROR - Email Template with DeveloperName "' + templateDeveloperName + '" not found. ' + e.getMessage());
            return; // Stop execution if template doesn't exist
        }

        String htmlBody = et.HtmlValue;
        String subject = et.Subject;

        // Step 3: Perform replacements for all placeholders.
        // Replace Contact and Subscription data
        htmlBody = htmlBody.replace('{{contact_first_name}}', sub.Contact__r.FirstName != null ? sub.Contact__r.FirstName : 'Valued Donor');
        htmlBody = htmlBody.replace('{{subscription_id}}', sub.Subscription_ID__c != null ? sub.Subscription_ID__c : 'N/A');
        htmlBody = htmlBody.replace('{{recurring_frequency}}', sub.Frequency__c != null ? sub.Frequency__c : 'N/A');

        // Replace payment-related data if a payment record was found
        if (!latestPaymentList.isEmpty()) {
            Pledge_details__c latestPayment = latestPaymentList[0];
            
            String amountStr = (latestPayment.Amount__c != null) ? String.valueOf(latestPayment.Amount__c.toPlainString()) : 'N/A';
            htmlBody = htmlBody.replace('{{recurring_amount}}', amountStr);
            htmlBody = htmlBody.replace('{{transaction_amount}}', amountStr);

            String currencyStr = (latestPayment.Currency__c != null) ? latestPayment.Currency__c : '';
            htmlBody = htmlBody.replace('{{recurring_currency}}', currencyStr);
            htmlBody = htmlBody.replace('{{transaction_currency}}', currencyStr);

            String transDateStr = (latestPayment.Transaction_date__c != null) ? latestPayment.Transaction_date__c.format() : 'N/A';
            htmlBody = htmlBody.replace('{{transaction_date}}', transDateStr);
            
            String paymentMethodDesc = (latestPayment.Mode_of_Payment__c != null) ? latestPayment.Mode_of_Payment__c : 'N/A';
            htmlBody = htmlBody.replace('{{payment_method_description}}', paymentMethodDesc);
            
            String transIdStr = (transactionDetail != null && transactionDetail.Transaction_ID__c != null) ? transactionDetail.Transaction_ID__c : 'N/A';
            htmlBody = htmlBody.replace('{{transaction_id}}', transIdStr);
        } else {
            // Fallback if no payment record is found
            htmlBody = htmlBody.replace('{{recurring_amount}}', 'N/A');
            htmlBody = htmlBody.replace('{{recurring_currency}}', '');
            htmlBody = htmlBody.replace('{{transaction_amount}}', 'N/A');
            htmlBody = htmlBody.replace('{{transaction_currency}}', '');
            htmlBody = htmlBody.replace('{{transaction_date}}', 'N/A');
            htmlBody = htmlBody.replace('{{payment_method_description}}', 'N/A');
            htmlBody = htmlBody.replace('{{transaction_id}}', 'N/A');
        }

        // Step 4: Assemble and send the final email.
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        OrgWideEmailAddress[] owea = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'give@isb.edu' LIMIT 1];
        if (!owea.isEmpty()) {
            mail.setOrgWideEmailAddressId(owea[0].Id);
        }
        mail.setToAddresses(new List<String>{ sub.Contact__r.Email });
        mail.setSubject(subject);
        mail.setHtmlBody(htmlBody);
        mail.setSaveAsActivity(true);
        mail.setTargetObjectId(sub.Contact__r.Id);
        mail.setWhatId(sub.Id);

        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            System.debug('RazorpayChargedEmailService: Email from template "' + templateDeveloperName + '" sent successfully for Subscription ID: ' + sub.Id);
        } catch (Exception e) {
            System.debug('RazorpayChargedEmailService: Error sending email message: ' + e.getMessage());
        }
    }
}