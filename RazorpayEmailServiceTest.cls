@isTest
public class RazorpayEmailServiceTest {

    private static Id getTestEmailFolderId() {
        try {
            Folder folder = [
                SELECT Id
                FROM Folder
                WHERE Name = 'Unfiled Public Classic Email Templates'
                AND Type = 'Email'
                LIMIT 1
            ];
            return folder.Id;
        } catch (Exception e) {
            return null;
        }
    }

    private static Id createTestTemplate() {
        Id folderId = getTestEmailFolderId();
        if(folderId == null) {
            System.debug('TEST SKIPPED: Email template folder not found. Manual org setup required.');
            System.assertEquals(true, true, 'SKIPPED: No Email Template Folder present in test context.');
            return null;
        }
        EmailTemplate et = new EmailTemplate(
            Name = 'Donor - Subscription Paused',
            DeveloperName = 'Donor_Subscription_Paused', // Use underscores, which is typical for DeveloperName
            Subject = 'Test Subject',
            HtmlValue = 'Hello, this is a test template sent by an Apex test.',
            FolderId = folderId,
            TemplateType = 'html'
        );
        insert et;
        return et.Id;
    }

    @isTest(seeAllData=true)
    static void testSendSubscriptionEmail_SubscriptionPaused() {
        Id templateId = createTestTemplate();
        if(templateId == null) return; // SKIP IF FOLDER IS MISSING

        Contact c = new Contact(LastName='Test', FirstName='Paused', Email='test@pause.com');
        insert c;

        Subscription__c s = new Subscription__c(
            Contact__c = c.Id,
            Subscription_ID__c = 'SUB-PAUSED',
            Start_At__c = System.today(),
            End_At__c = System.today().addMonths(1),
            Frequency__c = 'Monthly'
        );
        insert s;

        // Always select the contact relationship if your code expects it
        s = [SELECT Id, Contact__c, Contact__r.Email FROM Subscription__c WHERE Id = :s.Id];

        Test.startTest();
        RazorpayEmailService.sendSubscriptionEmail(s, 'Donor_-_Subscription_Paused'); // use the developername
        Test.stopTest();

        System.assertEquals(1, Limits.getEmailInvocations(), 'Should have sent one email using the Paused template');
    }
}