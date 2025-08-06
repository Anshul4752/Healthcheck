/**
 * @description       : 
 * @author            : Anshul Verma
 * @group             : 
 * @last modified on  : 07-21-2025
 * @last modified by  : Anshul Verma
**/

public without sharing class RazorpaySubscriptionHandler {
    public static void handleActivated(RazorpayWebhookWrapper webhook) {
        Subscription__c subRecord = processSubscriptionUpdate(webhook, 'Active', null);
        
        // Specific post-processing for activation
        if (subRecord != null) {
            try {
                // Uses a different email service/template than others
                RazorpayChargedEmailService.sendActivationNotification(subRecord.Id);
            } catch (Exception e) {
                System.debug('RazorpaySubscriptionHandler.handleActivated ERROR: Failed to send activation notification for Subscription ID ' + subRecord.Id + '. Details: ' + e.getMessage());
            }
        }
    }

    /**
     * @description Handles 'subscription.pending' event. Updates the subscription if it exists.
     */
    public static void handlePending(RazorpayWebhookWrapper webhook) {
        processSubscriptionUpdate(webhook, 'pending', 'Donor_Subscription_Pending');
    }
    
    /**
     * @description Handles 'subscription.paused' event.
     */
    public static void handlePaused(RazorpayWebhookWrapper webhook) {
        processSubscriptionUpdate(webhook, 'Paused', 'Donor_Subscription_Paused');
    }

    /**
     * @description Handles 'subscription.resumed' event.
     */
    public static void handleResumed(RazorpayWebhookWrapper webhook) {
        processSubscriptionUpdate(webhook, 'active', 'Donor_Subscription_Resumed');
    }

    /**
     * @description Handles 'subscription.halted' event.
     */
    public static void handleHalted(RazorpayWebhookWrapper webhook) {
        processSubscriptionUpdate(webhook, 'Halted', 'Donor_Subscription_Halted');
    }

    /**
     * @description Handles 'subscription.updated' event. Updates fields without changing status.
     */
    public static void handleUpdated(RazorpayWebhookWrapper webhook) {
        // We pass 'null' for status because the 'updated' event should not override the current status.
        processSubscriptionUpdate(webhook, null, null); 
    }

    public static void handleCancelled(RazorpayWebhookWrapper webhook) {
        // Cancellation has unique logic, so it's handled separately and doesn't use the common helper.
        if (webhook?.payload?.subscription?.entity?.id == null) {
            System.debug('handleCancelled: Incomplete payload. Exiting.');
            return;
        }

        RazorpayWebhookWrapper.Subscription subPayload = webhook.payload.subscription.entity;

        Subscription__c subRecord;
        try {
            // Query all fields needed for logic and email templates
            subRecord = [
                SELECT Id, Contact__c, Contact__r.Email, Contact__r.Name
                FROM Subscription__c 
                WHERE Subscription_Id__c = :subPayload.id 
                LIMIT 1
            ];
        } catch (QueryException e) {
            System.debug('handleCancelled ERROR: Could not find Subscription with Razorpay ID: ' + subPayload.id);
            return;
        }

        List<SObject> recordsToUpdate = new List<SObject>();

        // 1. Apply common field mappings from payload
        mapCommonFields(subRecord, subPayload);
        subRecord.Status__c = 'Cancelled'; // Set specific status
        recordsToUpdate.add(subRecord);

        // 2. Handle unique cancellation logic for related Pledge records
        Pledges_Summary__c pledgeSummary;
        try {
            pledgeSummary = [SELECT Id FROM Pledges_Summary__c WHERE Subscription__c = :subRecord.Id LIMIT 1];
            if (pledgeSummary != null) {
                pledgeSummary.Transaction_Status__c = 'Cancelled Midway';
                recordsToUpdate.add(pledgeSummary);

                List<Pledge_details__c> remainingInstallments = [
                    SELECT Id, PLD_Status__c 
                    FROM Pledge_details__c 
                    WHERE Pledge_Summary__c = :pledgeSummary.Id AND PLD_Status__c = 'Not Paid'
                ];

                for (Pledge_details__c installment : remainingInstallments) {
                    installment.PLD_Status__c = 'Cancelled Midway';
                }
                recordsToUpdate.addAll(remainingInstallments);
            }
        } catch (QueryException e) {
            System.debug('handleCancelled INFO: No related Pledges_Summary__c found for Subscription ID ' + subRecord.Id);
        }

        // 3. Perform a single, safe DML operation and send email
        try {
            if (!recordsToUpdate.isEmpty()) {
                update recordsToUpdate;
                System.debug('handleCancelled SUCCESS: Processed cancellation for Subscription ID ' + subRecord.Id);
                RazorpayEmailService.sendSubscriptionEmail(subRecord, 'Donor_Subscription_Cancelled');
            }
        } catch (DmlException e) {
            System.debug('handleCancelled DML ERROR: Failed to update records. Details: ' + e.getMessage());
        }
    }

    private static Subscription__c processSubscriptionUpdate(RazorpayWebhookWrapper webhook, String newStatus, String emailTemplateName) {
        if (webhook?.payload?.subscription?.entity?.id == null) {
            System.debug('processSubscriptionUpdate: Incomplete payload. Exiting.');
            return null;
        }
        
        RazorpayWebhookWrapper.Subscription subPayload = webhook.payload.subscription.entity;
        
        List<Subscription__c> existingSubs = [
            SELECT Id, Status__c, Contact__c, Ended_At__c, Contact__r.Email, Contact__r.Name
            FROM Subscription__c WHERE Subscription_Id__c = :subPayload.id LIMIT 1
        ];

        if (existingSubs.isEmpty()) {
            System.debug('processSubscriptionUpdate ERROR: Could not find Subscription with Razorpay ID: ' + subPayload.id);
            return null;
        }

        Subscription__c subRecord = existingSubs[0];

        // 1. Map all common fields from payload to the SObject record
        mapCommonFields(subRecord, subPayload);

        // 2. Set the status if one was provided
        if (String.isNotBlank(newStatus)) {
            subRecord.Status__c = newStatus;
        }
        
        // 3. Perform DML and send email
        try {
            update subRecord;
            System.debug('processSubscriptionUpdate SUCCESS: Updated Subscription ID ' + subRecord.Id + ' with status "' + subRecord.Status__c + '".');

            if (String.isNotBlank(emailTemplateName)) {
                RazorpayEmailService.sendSubscriptionEmail(subRecord, emailTemplateName);
            }
            return subRecord;
        } catch (DmlException e) {
            System.debug('processSubscriptionUpdate DML ERROR: Failed to update Subscription with Razorpay ID ' + subPayload.id + '. Details: ' + e.getMessage());
            return null;
        }
    }

    private static void mapCommonFields(Subscription__c subRecord, RazorpayWebhookWrapper.Subscription payload) {
        subRecord.Plan_Id__c = payload.plan_id;
        subRecord.Customer_Id__c = payload.customer_id;
        subRecord.Type__c = payload.type;
        subRecord.Current_Start__c = UnixDateTimeUtil.toDateTime(payload.current_start);
        subRecord.Current_End__c = UnixDateTimeUtil.toDateTime(payload.current_end);
        subRecord.Ended_At__c = UnixDateTimeUtil.toDateTime(payload.ended_at);
        subRecord.Quantity__c = payload.quantity;
        subRecord.Charge_At__c = UnixDateTimeUtil.toDateTime(payload.charge_at);
        subRecord.Start_At__c = UnixDateTimeUtil.toDateTime(payload.start_at);
        subRecord.End_At__c = UnixDateTimeUtil.toDateTime(payload.end_at);
        subRecord.Auth_Attempts__c = payload.auth_attempts;
        subRecord.Total_Count__c = payload.total_count;
        subRecord.Paid_Count__c = payload.paid_count;
        subRecord.Customer_Notify__c = payload.customer_notify;
        subRecord.Created_At__c = UnixDateTimeUtil.toDateTime(payload.created_at);
        subRecord.Expire_By__c = UnixDateTimeUtil.toDateTime(payload.expire_by);
        subRecord.Short_URL__c = payload.short_url;
        subRecord.Has_Scheduled_Changes__c = payload.has_scheduled_changes;
        subRecord.Change_Scheduled_At__c = UnixDateTimeUtil.toDateTime(payload.change_scheduled_at);
        subRecord.Source__c = payload.source;
        subRecord.Offer_Id__c = payload.offer_id;
        subRecord.Remaining_Count__c = payload.remaining_count;
        subRecord.Payment_Method__c = payload.payment_method;
        subRecord.Pause_Initiated_By__c = payload.pause_initiated_by;
        subRecord.Cancel_Initiated_By__c = payload.cancel_initiated_by;
    }
}