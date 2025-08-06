/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 07-08-2025
 * @last modified by  : Anshul Verma
**/
public with sharing class RazorpaySubscriptionAuthentication {
    public static void handleWebhook(RazorpayWebhookWrapper webhook) {
        if (webhook == null || 
            webhook.payload == null || 
            webhook.payload.subscription == null || 
            webhook.payload.subscription.entity == null) {
            return;
        }

        RazorpayWebhookWrapper.Subscription sub = webhook.payload.subscription.entity;

        // Find the existing subscription by Subscription_Id__c
        List<Subscription__c> existingSubs = [
            SELECT Id, Status__c,Contact__c,Ended_At__c,Contact__r.Email FROM Subscription__c WHERE Subscription_Id__c = :sub.id LIMIT 1
        ];

        if (existingSubs.isEmpty()) return;

        Subscription__c subRecord = existingSubs[0];

        // Update fields possibly related to authentication
        subRecord.Auth_Attempts__c = sub.auth_attempts;
      //  subRecord.Status__c = sub.status;
        subRecord.Customer_Notify__c = sub.customer_notify;
     

        update subRecord;
    }
}