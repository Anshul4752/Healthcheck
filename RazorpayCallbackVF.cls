/**
 * @description       : Handles callback from Razorpay for recurring subscription payments.
 * @author            : Anshul Verma
 * @group             : 
 * @last modified on  : 07-22-2025
 * @last modified by  : Anshul Verma
**/
public without sharing class RazorpayCallbackVF {
    static final String PAID = 'Paid';
    static final String NOT_PAID = 'Not Paid';
    public String responseMessage { get; set; }

    public void processCallback() {
        try {
            System.debug('--- RazorpayCallbackVF.processCallback START ---');
            Map<String, String> params = ApexPages.currentPage().getParameters();
            System.debug('Received params: ' + params);
            String paymentId      = params.get('razorpay_payment_id');
            String subscriptionId = params.get('razorpay_subscription_id');
            String signature      = params.get('razorpay_signature');

            if (String.isBlank(paymentId) || String.isBlank(subscriptionId) || String.isBlank(signature)) {
                responseMessage = 'Missing parameters';
                System.debug('Missing parameters: paymentId=' + paymentId + ', subscriptionId=' + subscriptionId + ', signature=' + signature);
                return;
            }

            // Verify signature
            String payload = paymentId + '|' + subscriptionId;
            String secret = System.Label.RazorPayPAssword;
            System.debug('Signature payload: ' + payload);
            Blob mac = Crypto.generateMac('HMACSHA256', Blob.valueOf(payload), Blob.valueOf(secret));
            String expected = EncodingUtil.convertToHex(mac);
            System.debug('Expected signature: ' + expected + ', Received signature: ' + signature);
            if (expected != signature) {
                responseMessage = 'Invalid signature';
                System.debug('Signature mismatch.');
                return;
            }
            responseMessage = 'Signature verified: ' + subscriptionId;
            System.debug('Signature verified for subscriptionId: ' + subscriptionId);

            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Razorpay_NamedCred' + '/v1/payments/' + EncodingUtil.urlEncode(paymentId, 'UTF-8'));
            req.setMethod('GET');
            req.setHeader('Accept', 'application/json');
            System.debug('Sending HTTP GET to Razorpay for paymentId: ' + paymentId);
            HttpResponse res = new Http().send(req);
            System.debug('Razorpay response status: ' + res.getStatusCode() + ', body: ' + res.getBody());
            if (res.getStatusCode() != 200) {
                System.debug('Razorpay callout failed. Status: ' + res.getStatusCode());
                throw new CalloutException('Razorpay error. HTTP Status: ' + res.getStatusCode());
            }
            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String paymentStatus = (String) jsonMap.get('status');
            Decimal paidAmount = ((Decimal)jsonMap.get('amount')).intValue()/100;
            System.debug('Payment status: ' + paymentStatus + ', Paid amount: ' + paidAmount);

            Transaction_Details__c tdObj = [SELECT Name, Pledge_Summary__c, Pledge_detail__c, Pledge_Summary__r.Frequency__c,
                                                Contact__c, Address__c, PIN_Code__c, PAN_Number__c, Passport_Number__c,
                                                This_is_an_anonymous_gift__c, Name_on_online_donation_form__c, Donor_s_Phone_Number__c
                                            FROM Transaction_Details__c WHERE Subscription_Id__c = :subscriptionId LIMIT 1];
            System.debug('Fetched Transaction_Details__c: ' + tdObj);
            
            // DEBUGGING FREQUENCY FIELD
            System.debug('=== DEBUGGING FREQUENCY FIELD ===');
            System.debug('Transaction Details full object: ' + JSON.serialize(tdObj));
            System.debug('Transaction Details getSObjectType: ' + tdObj.getSObjectType());
            System.debug('Pledge_Summary__c ID: ' + tdObj.Pledge_Summary__c);

            Pledges_Summary__c plsObj = [SELECT Id, Transaction_Status__c, Pledge_Received__c, Frequency__c 
                                         FROM Pledges_Summary__c WHERE Id = :tdObj.Pledge_Summary__c];
            System.debug('Fetched Pledges_Summary__c: ' + plsObj);
            System.debug('Pledges_Summary__c full object: ' + JSON.serialize(plsObj));
            System.debug('Pledges_Summary__c getSObjectType: ' + plsObj.getSObjectType());

            // Check all frequency-related fields on Pledges_Summary__c
            if(tdObj.Pledge_Summary__c != null) {
                try {
                    // Query all fields to see what's available
                    String allFieldsQuery = 'SELECT Id';
                    Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Pledges_Summary__c.fields.getMap();
                    for(String fieldName : fieldMap.keySet()) {
                        if(fieldName.toLowerCase().contains('freq') || 
                           fieldName.toLowerCase().contains('period') || 
                           fieldName.toLowerCase().contains('interval') ||
                           fieldName.toLowerCase().contains('recurring') ||
                           fieldName.toLowerCase().contains('monthly') ||
                           fieldName.toLowerCase().contains('quarterly') ||
                           fieldName.toLowerCase().contains('yearly')) {
                            allFieldsQuery += ', ' + fieldName;
                            System.debug('Found potential frequency field on Pledges_Summary__c: ' + fieldName);
                        }
                    }
                    allFieldsQuery += ' FROM Pledges_Summary__c WHERE Id = \'' + tdObj.Pledge_Summary__c + '\' LIMIT 1';
                    System.debug('Debug query for Pledges_Summary__c: ' + allFieldsQuery);
                    
                    Pledges_Summary__c debugPls = Database.query(allFieldsQuery);
                    System.debug('Pledge Summary with all frequency-related fields: ' + JSON.serialize(debugPls));
                } catch(Exception e) {
                    System.debug('Error checking Pledges_Summary__c fields: ' + e.getMessage());
                }
            }

            // Check if frequency is on Subscription__c object
            try {
                List<Subscription__c> subList = [SELECT Id FROM Subscription__c 
                                                 WHERE Id IN (SELECT Subscription__c FROM Pledges_Summary__c WHERE Id = :tdObj.Pledge_Summary__c) 
                                                 LIMIT 1];
                if(!subList.isEmpty()) {
                    // Get all frequency-related fields from Subscription__c
                    String subQuery = 'SELECT Id';
                    Map<String, Schema.SObjectField> subFieldMap = Schema.SObjectType.Subscription__c.fields.getMap();
                    for(String fieldName : subFieldMap.keySet()) {
                        if(fieldName.toLowerCase().contains('freq') || 
                           fieldName.toLowerCase().contains('period') || 
                           fieldName.toLowerCase().contains('interval') ||
                           fieldName.toLowerCase().contains('recurring') ||
                           fieldName.toLowerCase().contains('monthly') ||
                           fieldName.toLowerCase().contains('quarterly') ||
                           fieldName.toLowerCase().contains('yearly')) {
                            subQuery += ', ' + fieldName;
                            System.debug('Found potential frequency field on Subscription__c: ' + fieldName);
                        }
                    }
                    subQuery += ' FROM Subscription__c WHERE Id = \'' + subList[0].Id + '\' LIMIT 1';
                    System.debug('Debug query for Subscription__c: ' + subQuery);
                    
                    Subscription__c debugSub = Database.query(subQuery);
                    System.debug('Subscription object with all frequency-related fields: ' + JSON.serialize(debugSub));
                }
            } catch(Exception e) {
                System.debug('Error checking Subscription__c: ' + e.getMessage());
            }
            System.debug('=== END FREQUENCY DEBUGGING ===');

            Pledge_details__c pldObj;
            List<Pledge_details__c> nextPledgeList = [
                SELECT Id, Name, PLD_Status__c, Subscription_Sub_Pledge_Number__c 
                FROM Pledge_details__c 
                WHERE Pledge_Summary__c = :plsObj.Id AND PLD_Status__c = :NOT_PAID 
                ORDER BY Subscription_Sub_Pledge_Number__c ASC 
                LIMIT 1
            ];
            System.debug('Next unpaid pledge list: ' + nextPledgeList);

            if(nextPledgeList.isEmpty()){
                responseMessage = 'No unpaid installments found for subscription ' + subscriptionId;
                System.debug(responseMessage);
                return;
            }
            pldObj = nextPledgeList[0];
            System.debug('Selected Pledge_details__c: ' + pldObj);

            if (paymentStatus == 'captured') {
                System.debug('Payment status is captured. Updating records.');
                plsObj.Transaction_Status__c = 'Partially Paid';
                plsObj.Pledge_Received__c = (plsObj.Pledge_Received__c == null ? 0 : plsObj.Pledge_Received__c) + paidAmount;

                pldObj.PLD_Status__c = PAID;
                pldObj.Classification_of_Gift__c = 'Other Gift';
                pldObj.Amount_received_in_pledge_currency__c = paidAmount;
                pldObj.Amount__c = paidAmount;
                pldObj.Transaction_date__c = System.today();
                pldObj.Duedate__c = System.today();

                update plsObj;
                update pldObj;
                System.debug('Updated Pledges_Summary__c and Pledge_details__c.');
                
                System.debug('>>> Starting future pledge due date update logic <<<');
                System.debug('Current pledge Subscription_Sub_Pledge_Number__c: ' + pldObj.Subscription_Sub_Pledge_Number__c);
                
                if (pldObj.Subscription_Sub_Pledge_Number__c == 1) {
                    System.debug('This is the FIRST installment - will update future pledge due dates');
                    
                    // Try multiple ways to get frequency
                    String pledgeFrequency = null;
                    
                    // Method 1: From Transaction Details relationship
                    if(tdObj.Pledge_Summary__r != null && tdObj.Pledge_Summary__r.Frequency__c != null) {
                        pledgeFrequency = tdObj.Pledge_Summary__r.Frequency__c;
                        System.debug('Got frequency from tdObj.Pledge_Summary__r: ' + pledgeFrequency);
                    }
                    
                    // Method 2: From Pledges_Summary__c directly
                    if(String.isBlank(pledgeFrequency) && plsObj.Frequency__c != null) {
                        pledgeFrequency = plsObj.Frequency__c;
                        System.debug('Got frequency from plsObj: ' + pledgeFrequency);
                    }
                    
                    // Method 3: Query Subscription__c if frequency is stored there
                    if(String.isBlank(pledgeFrequency)) {
                        try {
                            List<Subscription__c> subs = [SELECT Id, Frequency__c FROM Subscription__c 
                                                          WHERE Id IN (SELECT Subscription__c FROM Pledges_Summary__c WHERE Id = :plsObj.Id)
                                                          LIMIT 1];
                            if(!subs.isEmpty() && subs[0].Frequency__c != null) {
                                pledgeFrequency = subs[0].Frequency__c;
                                System.debug('Got frequency from Subscription__c: ' + pledgeFrequency);
                            }
                        } catch(Exception e) {
                            System.debug('Error getting frequency from Subscription: ' + e.getMessage());
                        }
                    }
                    
                    Integer dayInterval = 0;
                    System.debug('Final Pledge frequency value: ' + pledgeFrequency);

                    if (String.isNotBlank(pledgeFrequency)) {
                        System.debug('Pledge frequency is NOT blank: ' + pledgeFrequency);
                        if (pledgeFrequency.equalsIgnoreCase('Monthly')) {
                            dayInterval = 30;
                            System.debug('Set dayInterval to 30 for Monthly');
                        } else if (pledgeFrequency.equalsIgnoreCase('Quarterly')) {
                            dayInterval = 90;
                            System.debug('Set dayInterval to 90 for Quarterly');
                        } else if (pledgeFrequency.equalsIgnoreCase('Yearly')) {
                            dayInterval = 365;
                            System.debug('Set dayInterval to 365 for Yearly');
                        } else {
                            System.debug('WARNING: Unrecognized frequency: ' + pledgeFrequency);
                        }
                    } else {
                        System.debug('WARNING: Pledge frequency is BLANK - cannot update future due dates');
                    }
                    
                    System.debug('Final dayInterval value: ' + dayInterval);

                    if (dayInterval > 0) {
                        System.debug('Day interval is valid, querying future pledges...');
                        List<Pledge_details__c> futurePledges = [
                            SELECT Id, Name, Duedate__c, Subscription_Sub_Pledge_Number__c 
                            FROM Pledge_details__c 
                            WHERE Pledge_Summary__c = :plsObj.Id AND PLD_Status__c = :NOT_PAID 
                            ORDER BY Subscription_Sub_Pledge_Number__c ASC
                        ];
                        System.debug('Found ' + futurePledges.size() + ' future unpaid pledges');
                        System.debug('Future pledge details: ' + futurePledges);

                                                List<Pledge_details__c> pledgesToUpdate = new List<Pledge_details__c>();
                        Integer installmentMultiplier = 1;
                        Date baseDate = System.today();
                        System.debug('Base date for calculations: ' + baseDate);
                        
                        for (Pledge_details__c futurePld : futurePledges) {
                            Date oldDueDate = futurePld.Duedate__c;
                            Date newDueDate = baseDate.addDays(dayInterval * installmentMultiplier);
                            futurePld.Duedate__c = newDueDate;
                            pledgesToUpdate.add(futurePld);
                            
                            System.debug('>>> Pledge #' + futurePld.Subscription_Sub_Pledge_Number__c + 
                                       ' (Id: ' + futurePld.Id + ', Name: ' + futurePld.Name + ')' +
                                       ' - Old Due Date: ' + oldDueDate + 
                                       ', New Due Date: ' + newDueDate + 
                                       ' (Base + ' + (dayInterval * installmentMultiplier) + ' days)');
                            
                            installmentMultiplier++;
                        }
                        
                        System.debug('Total pledges to update: ' + pledgesToUpdate.size());
                        if (!pledgesToUpdate.isEmpty()) {
                            System.debug('Attempting to update pledges...');
                            try {
                                update pledgesToUpdate;
                                System.debug('SUCCESS: Updated due dates for ' + pledgesToUpdate.size() + ' future pledges');
                                System.debug('Updated pledges: ' + pledgesToUpdate);
                                
                                // Verify the update by re-querying
                                List<Pledge_details__c> verifyPledges = [
                                    SELECT Id, Name, Duedate__c, Subscription_Sub_Pledge_Number__c 
                                    FROM Pledge_details__c 
                                    WHERE Id IN :pledgesToUpdate
                                ];
                                System.debug('VERIFICATION - Re-queried pledges after update: ' + verifyPledges);
                            } catch (Exception e) {
                                System.debug('ERROR updating pledges: ' + e.getMessage());
                                System.debug('Stack trace: ' + e.getStackTraceString());
                            }
                        } else {
                            System.debug('WARNING: No pledges to update (pledgesToUpdate list is empty)');
                        }
                    } else {
                        System.debug('WARNING: Day interval is 0 or negative, skipping future pledge updates');
                    }
                } else {
                    System.debug('This is NOT the first installment (Sub pledge #' + pldObj.Subscription_Sub_Pledge_Number__c + '), skipping future pledge due date updates');
                }
                System.debug('>>> Completed future pledge due date update logic <<<');
                
                Id donationRecordTypeId = Schema.SObjectType.Donation__c.getRecordTypeInfosByName().get('One time Donation').getRecordTypeId();
                System.debug('Donation record type Id: ' + donationRecordTypeId);
            
                Donation__c donationObj = new Donation__c(
                    Name = pldObj.Name + '- ' + pldObj.Subscription_Sub_Pledge_Number__c,
                    Pledge_detail__c = pldObj.Id,
                    Pledge__c = plsObj.Id,
                    Name__c = tdObj.Contact__c,
                    Remittance_Amount__c = paidAmount,
                    Amount__c = paidAmount,
                    Donation_Status__c = PAID,
                    RecordTypeId = donationRecordTypeId,
                    Cheque_Transaction_Ref_no__c = paymentId,
                    Address_Line_1__c = tdObj.Address__c,
                    Postal_Code__c = tdObj.PIN_Code__c,
                    PAN_No__c = tdObj.PAN_Number__c,
                    Passport_No__c = tdObj.Passport_Number__c,
                    gift_to_be_anonymous__c = tdObj.This_is_an_anonymous_gift__c,
                    Name_on_the_donation_form__c = tdObj.Name_on_online_donation_form__c,
                    Donor_s_Phone_Number__c = tdObj.Donor_s_Phone_Number__c
                );
                insert donationObj;
                System.debug('Inserted Donation__c: ' + donationObj);
                
                Receipts__c recObj = new Receipts__c(
                    Name__c = tdObj.Contact__c,
                    Pledge_detail__c = pldObj.Id,
                    Pledge_Summary__c = plsObj.Id,
                    Donation__c = donationObj.Id,
                    Receipt_Amount__c = paidAmount,
                    Transaction_status__c = PAID,
                    Mode_of_Payment__c = 'Payment Gateway',
                    Transaction_Number__c = paymentId,
                    Receipt_Date__c = System.today()
                );
                insert recObj;
                System.debug('Inserted Receipts__c: ' + recObj);
                
                donationObj.Receipt__c = recObj.Id;
                update donationObj;
                System.debug('Updated Donation__c with receipt.');
            }
            System.debug('--- RazorpayCallbackVF.processCallback END ---');
        } catch (Exception ex) {
            responseMessage = 'Error: ' + ex.getMessage() + ' at line ' + ex.getLineNumber();
            System.debug(LoggingLevel.ERROR, 'RazorpayCallbackVF Error: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
        }
    }
}