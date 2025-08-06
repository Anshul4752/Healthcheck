/**
 * @description       : 
 * @author            : Anshul Verma
 * @group             : 
 * @last modified on  : 07-02-2025
 * @last modified by  : Anshul Verma
**/

public without sharing class RazorpaySubscriptionCompleted {

    public static void handleWebhook(RazorpayWebhookWrapper webhook) {
        if (webhook?.payload?.subscription?.entity?.id == null) {
            System.debug('RazorpaySubscriptionCompleted: Incomplete payload or missing subscription ID. Exiting.');
            return;
        }

        String subscriptionId = webhook.payload.subscription.entity.id;

        // Step 1: Find the Subscription__c record from the payload.
        Subscription__c subRecord;
        try {
            subRecord = [
                SELECT Id, Status__c,Contact__c,Ended_At__c,Contact__r.Email
                FROM Subscription__c 
                WHERE Subscription_Id__c = :subscriptionId 
                LIMIT 1
            ];
        } catch (QueryException e) {
            System.debug('RazorpaySubscriptionCompleted ERROR: Could not find Subscription with Razorpay ID: ' + subscriptionId);
            return;
        }
        
        // If the status is already 'Completed', no need to update again.
        if (subRecord.Status__c == 'Completed') {
            System.debug('RazorpaySubscriptionCompleted INFO: Subscription ' + subRecord.Id + ' is already marked as Completed. No update needed.');
            return;
        }

        // Step 2: Update the status field.
        subRecord.Status__c = 'Completed';
        
        // Step 3: Perform the DML update safely.
        try {
            update subRecord;
            System.debug('RazorpaySubscriptionCompleted SUCCESS: Updated status to Completed for Subscription ID ' + subRecord.Id);
            RazorpayEmailService.sendSubscriptionEmail(subRecord, 'Donor_Subscription_completed');
        } catch (DmlException e) {
            System.debug('RazorpaySubscriptionCompleted DML ERROR: Failed to update Subscription ' + subRecord.Id + '. Details: ' + e.getMessage());
        }
    }
}