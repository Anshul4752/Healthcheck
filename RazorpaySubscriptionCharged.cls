/**
 * @description       : Handles recurring subscription charges (2nd payment onwards) from Razorpay.
 * @author            : Anshul Verma
 * @group             : 
 * @last modified on  : 07-16-2025
 * @last modified by  : Anshul Verma
**/
public without sharing class RazorpaySubscriptionCharged {

    public static void handleWebhook(RazorpayWebhookWrapper webhook) {
        if (webhook?.payload?.subscription?.entity == null || webhook?.payload?.payment?.entity == null) {
            System.debug('Razorpay Webhook: Incomplete payload received. Exiting.');
            return;
        }

        RazorpayWebhookWrapper.Subscription subPayload = webhook.payload.subscription.entity;
        RazorpayWebhookWrapper.Payment paymentPayload = webhook.payload.payment.entity;

        if (subPayload.paid_count == null || subPayload.paid_count <= 1) {
            System.debug('Razorpay Webhook: Ignoring first payment (paid_count=' + subPayload.paid_count + ') as per business logic.');
            return;
        }

        Subscription__c subSalesforceRecord;
        // try {
        //     subSalesforceRecord = [
        //         SELECT Id, (SELECT Id FROM Subscription_Payments__r WHERE Payment_Id__c = :paymentPayload.id) 
        //         FROM Subscription__c 
        //         WHERE Subscription_Id__c = :subPayload.id LIMIT 1
        //     ];
        // } catch (QueryException e) {
        //     System.debug('Razorpay Error: Could not find the Subscription record in Salesforce with Razorpay ID: ' + subPayload.id);
        //     return;
        // }

        // if (subSalesforceRecord != null && !subSalesforceRecord.Subscription_Payments__r.isEmpty()) {
        //     System.debug('Razorpay Webhook: Duplicate recurring payment webhook received and ignored for Payment ID: ' + paymentPayload.id);
        //     return;
        // }
        
        Pledges_Summary__c pledgeSummaryRecord;
        try {
            pledgeSummaryRecord = [
                SELECT Id, Subscription__c 
                FROM Pledges_Summary__c 
                WHERE Subscription__c = :subSalesforceRecord.Id LIMIT 1
            ];
        } catch(QueryException e) {
            System.debug('Razorpay Error: Found subscription ' + subSalesforceRecord.Id + ' but could not find a Pledge Summary that links to it.');
            return;
        }
        
        processRecurringInstallment(paymentPayload, pledgeSummaryRecord, subPayload.paid_count);
    }

    private static void processRecurringInstallment(RazorpayWebhookWrapper.Payment paymentPayload, Pledges_Summary__c pledgeSummary, Integer paidCount) {
        
        if (paymentPayload.status != 'captured') {
            System.debug('Razorpay Info: Payment status is "' + paymentPayload.status + '". No records will be created.');
            return;
        }

        Pledge_details__c targetInstallment;
        try {
            targetInstallment = [
                SELECT Id, Name, PLD_Status__c, Pledge_Summary__c, 
                       Pledge_Summary__r.Name, Pledge_Summary__r.Contact__c, Pledge_Summary__r.Contact__r.Name, 
                       Pledge_Summary__r.Contact__r.Program__r.Name, Pledge_Summary__r.Contact__r.Associate_Alumni_Programme__r.Name, 
                       Pledge_Summary__r.Contact__r.Class__c
                FROM Pledge_details__c 
                WHERE Pledge_Summary__c = :pledgeSummary.Id 
                  AND Subscription_Sub_Pledge_Number__c = :paidCount
                LIMIT 1
            ];
        } catch (QueryException e) {
            System.debug('Razorpay Error: Could not find a Pledge Detail record for Pledge Summary ID: ' + pledgeSummary.Id + ' matching paid_count: ' + paidCount);
            return;
        }
        
        if (targetInstallment.PLD_Status__c == 'Paid') {
            System.debug('Razorpay Warning: The target installment ' + targetInstallment.Id + ' for paid_count ' + paidCount + ' is already marked as Paid. Ignoring webhook.');
            return;
        }

        Decimal paidAmount = paymentPayload.amount != null ? Decimal.valueOf(paymentPayload.amount)/100 : 0;
        Id donationRecordTypeId = Schema.SObjectType.Donation__c.getRecordTypeInfosByName().get('One time Donation').getRecordTypeId();
        // *** REMOVED ***: This line was getting the Guest User ID.
        // Id automationUserId = UserInfo.getUserId();

        try {
            Transaction_Details__c tdObj = new Transaction_Details__c(
                Pledge_detail__c = targetInstallment.Id, Pledge_Summary__c = targetInstallment.Pledge_Summary__c,
                Contact__c = targetInstallment.Pledge_Summary__r.Contact__c, Payment_ID__c = paymentPayload.id,
                Transaction_ID__c = paymentPayload.order_id, Payment_Status__c = 'Paid',
                Paid_Amount__c = paidAmount, Payment_Successful__c = true
            );
            insert tdObj;

            Donation__c donationObj = new Donation__c(
                RecordTypeId = donationRecordTypeId, Name = targetInstallment.Name + '-Donation',
                Pledge_detail__c = targetInstallment.Id, Pledge__c = targetInstallment.Pledge_Summary__c,
                Name__c = targetInstallment.Pledge_Summary__r.Contact__c, Donation_Status__c = 'Paid',
                Amount__c = paidAmount, Currency__c = 'INR', Transaction_Detail__c = tdObj.Id
                
            );
            insert donationObj;

            Receipts__c recObj = new Receipts__c(
            Name__c = targetInstallment.Pledge_Summary__r.Contact__c,
            Pledge_detail__c = targetInstallment.Id,
            Pledge_Summary__c = targetInstallment.Pledge_Summary__c,
            Donation__c = donationObj.Id,
            Transaction_Number__c = paymentPayload.id, // Sourced from the payment webhook payload

            // Fields with calculated values
            Pludge_Summary_Amount_Val__c = paidAmount, // Corrected typo from 'Pludge' to 'Pledge'
            Pledge_Detail_Amount_Val__c = paidAmount,
            Receipt_Amount__c = paidAmount,
            Donation_Amount_Val__c = paidAmount,
            Receipt_Amount_Pledge_Currency__c = paidAmount,
            Receipt_Date__c = Date.today(),
            Transaction_date__c = Date.today(),
            
            // Fields with hardcoded values as requested
            Transaction_status__c = 'Paid',
            Mode_of_Payment__c = 'Payment Gateway',
            Funds_received_in__c = 'Regular Account',
            Currency__c = 'INR',
            Remittance_Currency__c = 'INR',
            Currency_Exchange_Rate__c = 1
                
            );
            insert recObj;

            tdObj.Donation__c = donationObj.Id;
            tdObj.Receipt__c = recObj.Id;
            donationObj.Receipt__c = recObj.Id;
            update new List<SObject>{tdObj, donationObj};


            targetInstallment.Amount__c = paidAmount;
            targetInstallment.PLD_Status__c = 'Paid';
            targetInstallment.Transaction_date__c = System.today();
            update targetInstallment;
            

            Integer remainingInstallments = [SELECT COUNT() FROM Pledge_details__c WHERE Pledge_Summary__c = :pledgeSummary.Id AND PLD_Status__c != 'Paid'];
            if (remainingInstallments == 0) {
                Pledges_Summary__c finalPledgeUpdate = new Pledges_Summary__c(Id = pledgeSummary.Id, Transaction_Status__c = 'Paid');
                update finalPledgeUpdate;
            }

            // Send activation notification email using template
            RazorpayChargedEmailService.sendChargedNotification(pledgeSummary.Subscription__c);

            System.debug('Razorpay Webhook: Successfully processed recurring payment. Created Donation: ' + donationObj.Id);

        } catch (Exception e) {
            System.debug('Razorpay Error: Failed to process recurring installment. Details: ' + e.getMessage() + ' Stacktrace: ' + e.getStackTraceString());
        }
    }
}