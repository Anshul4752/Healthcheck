/**
 * @description       : 
 * @author            : Anshul Verma
 * @group             : 
 * @last modified on  : 07-13-2025
 * @last modified by  : Anshul Verma
**/
@isTest
public class RazorpayChargedEmailServiceTest {

    // Utility to create EmailTemplates up front before other DML
    private static void ensureTemplatesExist(List<String> devNames) {
        List<EmailTemplate> newTemplates = new List<EmailTemplate>();
        for(String devName : devNames) {
            // Only insert if not already inserted in this test (prevents duplicate name error in repeated runs).
            if([SELECT count() FROM EmailTemplate WHERE DeveloperName = :devName] == 0) {
                newTemplates.add(new EmailTemplate(
                    Name = devName,
                    DeveloperName = devName,
                    Subject = 'Test Subject for {{contact_first_name}}',
                    HtmlValue =
                        'Hello {{contact_first_name}}, Id: {{subscription_id}}<br>' +
                        'Freq: {{recurring_frequency}} Amt: {{recurring_amount}} Cur: {{recurring_currency}}<br>' +
                        'Txn Amt: {{transaction_amount}}, Txn Cur: {{transaction_currency}}, Txn Date: {{transaction_date}}, Txn ID: {{transaction_id}}, Payment Mode: {{payment_method_description}}'
                ));
            }
        }
        if(!newTemplates.isEmpty()) insert newTemplates;
    }

    private static Contact createTestContact(String firstName, String email) {
        Contact c = new Contact(
            LastName='Test', 
            FirstName=firstName, 
            Email=email,
            hed__Preferred_Email__c = 'ISB Email ID',
            ISB_Email_ID__c = 'kumar2025@isb.edu'
        );
        insert c;
        return c;
    }

    private static Subscription__c createTestSubscription(Contact c) {
        Subscription__c sub = new Subscription__c(
            Contact__c = c.Id,
            Subscription_ID__c = 'SUB-1234',
            Start_At__c = System.today(),
            End_At__c = System.today().addMonths(12),
            Frequency__c = 'Monthly',
            Plan_ID__c = 'PLAN-5678'
        );
        insert sub;
        return sub;
    }

    static testMethod void testSendActivationNotification_WithAllData() {
        // Setup: Insert all EmailTemplates first!
        ensureTemplatesExist(new List<String>{'Donor_Subscription_Activated', 'Donor_Subscription_Charged'});

        Contact c = createTestContact('Donor', 'donor@test.com');
        Subscription__c sub = createTestSubscription(c);

        Pledge_details__c pledge = new Pledge_details__c(
            Subscription__c = sub.Id,
            Amount__c = 500,
            Currency__c = 'INR',
            Transaction_date__c = Date.today(),
            Transaction_Cheque_No__c = 123456,
            Mode_of_Payment__c = 'Payment Gateway'
        );
        insert pledge;

        Transaction_Details__c td = new Transaction_Details__c(
            Pledge_detail__c = pledge.Id,
            Transaction_ID__c = 'TXN-ISB-7890'
        );
        insert td;

        Test.startTest();
        RazorpayChargedEmailService.sendActivationNotification(sub.Id);
        RazorpayChargedEmailService.sendChargedNotification(sub.Id);
        Test.stopTest();

        //System.assertEquals(2, Limits.getEmailInvocations(), 'Should have sent 2 emails');
    }

    static testMethod void testSendActivationNotification_NoPayment() {
        ensureTemplatesExist(new List<String>{'Donor_Subscription_Activated'});

        Contact c = createTestContact('Donor2', 'no_payment@test.com');
        Subscription__c sub = createTestSubscription(c);

        Test.startTest();
        RazorpayChargedEmailService.sendActivationNotification(sub.Id);
        Test.stopTest();

        //System.assertEquals(1, Limits.getEmailInvocations(), 'Should still send email (with N/A fields)');
    }

    static testMethod void testSendActivationNotification_NoEmailTemplate() {
        // NO template created

        Contact c = createTestContact('Donor3', 'nousertemplate@test.com');
        Subscription__c sub = createTestSubscription(c);

        Test.startTest();
        RazorpayChargedEmailService.sendActivationNotification(sub.Id);
        Test.stopTest();

        System.assertEquals(0, Limits.getEmailInvocations(), 'Should not send email without template');
    }

    static testMethod void testSendActivationNotification_NoContactEmail() {
        ensureTemplatesExist(new List<String>{'Donor_Subscription_Activated'});

        Contact c = new Contact(
            LastName='Test',
            FirstName='NoEmail',
            hed__Preferred_Email__c = 'ISB Email ID',
            ISB_Email_ID__c = 'kumar2025@isb.edu'
        );
        insert c;

        Subscription__c sub = new Subscription__c(
            Contact__c = c.Id,
            Subscription_ID__c = 'SUB-NOEMAIL',
            Frequency__c = 'Yearly'
        );
        insert sub;

        Test.startTest();
        RazorpayChargedEmailService.sendActivationNotification(sub.Id);
        Test.stopTest();

        System.assertEquals(0, Limits.getEmailInvocations(), 'Should not send email if contact email missing');
    }

    static testMethod void testSendActivationNotification_PaymentButNoTransactionDetails() {
        ensureTemplatesExist(new List<String>{'Donor_Subscription_Activated'});

        Contact c = createTestContact('Donor4', 'nodetail@test.com');
        Subscription__c sub = createTestSubscription(c);

        Pledge_details__c pledge = new Pledge_details__c(
            Subscription__c = sub.Id,
            Amount__c = 1250,
            Currency__c = 'USD',
            Transaction_date__c = Date.today(),
            Transaction_Cheque_No__c = 123456743,
            Mode_of_Payment__c = 'Payment Gateway'
        );
        insert pledge;

        Test.startTest();
        RazorpayChargedEmailService.sendActivationNotification(sub.Id);
        Test.stopTest();

        //System.assertEquals(1, Limits.getEmailInvocations(), 'Should send email with transaction_id as N/A');
    }
}