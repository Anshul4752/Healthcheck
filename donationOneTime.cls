/**
 * @description       : 
 * @author            : Jatin Prasad
 * @group             : 
 * @last modified on  : 07-10-2025
 * @last modified by  : Jatin Prasad
**/
public without sharing class donationOneTime {
    //Public static string userId =[Select id,name from user where Email ='susi_mary@isb.edu.invalid 'LIMIT 1].Id;
    public static Datetime otpExpirationTime;
    public static string generatedOtp;
    
    @AuraEnabled
    public static isbDonationResponseWrapper donationFormNew(isbDonationRequestWrapper donationRequest) {
        system.debug('donationRequest=>>>' + donationRequest);
       
        String transcationId = donationRequest.transactionID;
         system.debug('TransactionId=>>>' + transcationId);
        string payU_Url;
         isbDonationResponseWrapper res = new isbDonationResponseWrapper();
        try {
            // Validate transactionId
            if (String.isBlank(transcationId)) {
                throw new AuraHandledException('Transaction ID is missing.');
            }

            // Fetch transaction details
            List<Transaction_Details__c> transacionName = [SELECT Id, Name FROM Transaction_Details__c WHERE Id = :transcationId LIMIT 1];
            if (transacionName.isEmpty()) {
                throw new AuraHandledException('Transaction not found for the given ID.');
            }

            string TransactionObj = transacionName[0].Name;
            system.debug('TransactionObj: ' + TransactionObj);  

            // Prepare API request
            Decimal longAmount = (donationRequest.objDonation.Amount__c) * 100;
            String strName = donationRequest.name;
            String strEmail = donationRequest.email;
            String strContactNo = donationRequest.phone;
            String strReferenceId = TransactionObj;
            Integer IntExpirationDays = 60;
            Long longExpiryMilliseconds = 0;

            if (IntExpirationDays != 0) {
                DateTime datetExpiryDate = System.now() + IntExpirationDays;
                longExpiryMilliseconds = datetExpiryDate.getTime() / 1000;
            }

            String strBody = '{"reference_id": "' + strReferenceId + '", "accept_partial": false,' +
                             '"amount": ' + longAmount + ',"currency": "INR","description": "Payment towards Donation ",';
            strBody += '"customer": {"name": "' + strName + '","email": "' + strEmail + '"';
            if (String.isNotBlank(strContactNo)) {
                strBody += ',"contact": "' + strContactNo + '"';
            }
            strBody += '},';
            strBody += '"notes": {"Opportunity Name-Line Item Number": "' + strReferenceId + '"},';
            strBody += '"callback_url": "' + System.Label.Alumini_Callback_From_PaymentSite + '",';
            strBody += '"notify": {"sms": false,"email": false}';
            if (IntExpirationDays != 0) {
                strBody += ',"expire_by":' + longExpiryMilliseconds + '}';
            } else {
                strBody += '}';
            }

            system.debug('API Request Body: ' + strBody);

            // Send API request
            HttpRequest httpRequest = new HttpRequest();
            httpRequest.setEndpoint('https://api.razorpay.com/v1/payment_links');
            httpRequest.setMethod('POST');
            httpRequest.setHeader('Content-Type', 'application/json');
            httpRequest.setHeader('Accept', 'application/json');
            String username = System.Label.RazorPayUsername;
            String password = System.Label.RazorPayPAssword;
            Blob headerValue = Blob.valueOf(username + ':' + password);
            String strAuthorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
            httpRequest.setHeader('Authorization', strAuthorizationHeader);
            httpRequest.setBody(strBody);

            Http http = new Http();
            HTTPResponse httpResponse = http.send(httpRequest);
            system.debug('API Response Status: ' + httpResponse.getStatus());
            system.debug('API Response Body: ' + httpResponse.getBody());
           
            if (httpResponse.getStatusCode() == 200) {
                String strBodyDATA = httpResponse.getBody();
                strBodyDATA = strBodyDATA.replace('"currency":', '"currency1":');
                Donation_wrapper wrapperPaymentlinkResponse = (Donation_wrapper) JSON.deserialize(strBodyDATA, Donation_wrapper.class);
                system.debug('Payment Link: ' + wrapperPaymentlinkResponse.short_url);

                payU_Url = wrapperPaymentlinkResponse.short_url;
                
                res.shortURL = payU_Url;
                transacionName[0].Payment_Gateway_URL__c = payU_Url;
                update transacionName;
            } else {
                throw new AuraHandledException('Failed to generate payment link. API Response: ' + httpResponse.getBody());
            }
        } catch (Exception e) {
            system.debug('Exception in donationFormNew: ' + e.getMessage());
            throw new AuraHandledException('Error generating payment link: ' + e.getMessage());
        }

        return res;
    }
    
    
    // private static Contact processContactLogic(isbDonationRequestWrapper donationRequest) {
    //     Contact processedContact;
        
     
    //     if(donationRequest.objContact != null && String.isNotBlank(donationRequest.objContact.Id)) {
            
    //         system.debug('ContactId provided: ' + donationRequest.objContact.Id);
    //         processedContact = donationRequest.objContact;
    //     } else {
            
    //         system.debug('ContactId not provided, creating new Contact and Account');
    //         processedContact = createNewContactAndAccount(donationRequest);
    //     }
        
    //     return processedContact;
    // }
    
    
    // private static Contact createNewContactAndAccount(isbDonationRequestWrapper donationRequest) {
    //     Contact newContact;
        
    //     try {
           
    //         Account newAccount = new Account();
    //         newAccount.Name = donationRequest.name + ' - Individual Account';
    //         newAccount.Type = 'Individual';
           
    //         insert newAccount;
            
           
    //         newContact = new Contact();
    //         newContact.FirstName = getFirstName(donationRequest.name);
    //         newContact.LastName = getLastName(donationRequest.name);
    //         newContact.Email = donationRequest.email;
    //         newContact.Indian_Mobile_Number__c = donationRequest.phone;
    //         newContact.PAN_Number__c = donationRequest.panNumber;
    //         newContact.AccountId = newAccount.Id;
           
    //         if(donationRequest.objContact != null) {
    //             if(String.isNotBlank(donationRequest.objContact.User_ID__c)) {
    //                 newContact.User_ID__c = donationRequest.objContact.User_ID__c;
    //             }
    //             if(String.isNotBlank(donationRequest.objContact.Class__c)) {
    //                 newContact.Class__c = donationRequest.objContact.Class__c;
    //             }
    //             if(String.isNotBlank(donationRequest.objContact.Current_Address_Line_1__c)) {
    //                 newContact.Current_Address_Line_1__c = donationRequest.objContact.Current_Address_Line_1__c;
    //             }
    //             if(String.isNotBlank(donationRequest.objContact.Current_Postal_Code__c)) {
    //                 newContact.Current_Postal_Code__c = donationRequest.objContact.Current_Postal_Code__c;
    //             }
    //             if(String.isNotBlank(donationRequest.objContact.Program__c)) {
    //                 try {
                       
    //                     Academic_Program__c programRecord = [SELECT Id FROM Academic_Program__c WHERE Name = :donationRequest.objContact.Program__c LIMIT 1];
    //                     newContact.Program__c = programRecord.Id;
    //                 } catch (QueryException e) {
    //                     system.debug('Error fetching Program__c ID: ' + e.getMessage());
    //                     throw new AuraHandledException('Invalid Program Name: ' + donationRequest.objContact.Program__c);
    //                 }
    //             } else {
    //                 system.debug('Program__c is not provided for non-alumni.');
    //             }
                
    //         }
            
    //         insert newContact;
    //         system.debug('New Contact created with Id: ' + newContact.Id);
            
    //     } catch(Exception e) {
    //         system.debug('Exception in createNewContactAndAccount: ' + e.getMessage());
    //         throw new AuraHandledException('Error creating new contact and account: ' + e.getMessage());
    //     }
        
    //     return newContact;
    // }
    
   
    // private static String getFirstName(String fullName) {
    //     if(String.isBlank(fullName)) return 'Unknown';
        
    //     List<String> nameParts = fullName.split(' ');
    //     if(nameParts.size() > 1) {
    //         return nameParts[0];
    //     }
    //     return fullName;
    // }
    
    
    // private static String getLastName(String fullName) {
    //     if(String.isBlank(fullName)) return 'Unknown';
        
    //     List<String> nameParts = fullName.split(' ');
    //     if(nameParts.size() > 1) {
    //         return nameParts[nameParts.size() - 1];
    //     }
    //     return fullName;
    // }
    
    
    
    @AuraEnabled
    public static isbDonationRequestWrapper createTransactionDetailNew(isbDonationRequestWrapper donationRequest){
        system.debug('donationRequest received in Apex: ' + donationRequest);
        
        // Process Contact logic first
        Contact processedContact = donationRequest.objContact;//processContactLogic(donationRequest);
        
        // Use processed contact and wrapper data for transaction creation
        Donation__c objDonation = donationRequest.objDonation;
        string emailadress = donationRequest.email;
        
        Transaction_Details__c objTranscation = new Transaction_Details__c();
        objTranscation.Transaction_Date__c = system.today();
        objTranscation.Payment_Status__c= 'Not Paid';
        //objTranscation.OwnerId=userId;
        objTranscation.This_is_an_anonymous_gift__c = donationRequest.anonymousDonation;
        
        system.debug('Processed Contact: ' + processedContact);
        system.debug('Transaction Details: ' + objTranscation);
        
        if(objDonation != null && objDonation.Passport_Number__c != null){
            objTranscation.Passport_Number__c = objDonation.Passport_Number__c;
        }
        
        // String SAPNum = processedContact.User_ID__c;
        String conEmail = donationRequest.email;
        
        // Account Acc = [select id from Account where Name= 'Development'AND recordtype.name ='Business Organization'];
        // Id contactrecordtype = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Others').getRecordTypeId();
        
        // Use the processed contact for further logic
        List<Contact> conList1 = new List<Contact>{processedContact};
        system.debug('conlist1' +conList1);
        string name3;
        Id Pledgerecordtype = Schema.SObjectType.Pledges_Summary__c.getRecordTypeInfosByName().get('One Time Donation').getRecordTypeId();
        Id subPledgerecordtype = Schema.SObjectType.Pledge_details__c.getRecordTypeInfosByName().get('One time Donation').getRecordTypeId();
        
        List<Pledges_Summary__c> listPledgeSummary = new List<Pledges_Summary__c>();
        List<Pledge_details__c> listPledgeDetails = new List<Pledge_details__c>();
        List<Transaction_Details__c> listTransactions = new List<Transaction_Details__c>();
        
        // if (!conList1.isEmpty()) {
        //     listPledgeSummary = [select id,name,Pledged_Amount_In_donor_currency__c,Name__c from Pledges_Summary__c where Transaction_Status__c ='Not Paid' AND Pledged_Amount_In_donor_currency__c =: donationRequest.amount AND Name__c =: conList1[0].Id AND RecordTypeId=:Pledgerecordtype];
        //     system.debug('listplegdesummaryt' +listPledgeSummary);
        //     if (!listPledgeSummary.isEmpty()) {
        //         listPledgeDetails = [select id,name,Sub_Pledge_Amount__c,Contact_Email__c,PLD_Status__c, Name__c from Pledge_details__c where PLD_Status__c  ='Not Paid' AND Sub_Pledge_Amount__c =: donationRequest.amount AND Name__c =: conList1[0].id AND RecordTypeId=:subPledgerecordtype AND Pledge_Summary__c = :listPledgeSummary[0].Id];
        //         if (!listPledgeDetails.isEmpty()) {
        //             listTransactions = [select id,name,Pledge_detail__c,Pledge_Summary__c,Contact__c,Payment_Gateway_URL__c, Payment_Status__c FROM Transaction_Details__c WHERE Contact__c = :conList1[0].Id AND Pledge_detail__c =:listPledgeDetails[0].Id AND Pledge_Summary__c =:listPledgeSummary[0].Id AND Payment_Status__c = 'Not Paid'];
        //         }
        //     }
        // }
        
        Pledges_Summary__c PS = new Pledges_Summary__c();
        try {
            // Ensure all fields have valid values
            PS.Pledged_Amount_In_donor_currency__c = donationRequest.amount != null ? donationRequest.amount : 0;
            PS.NoOfSubPledges__c = 1;
            PS.RecordTypeId = Pledgerecordtype;
            PS.Transaction_Status__c = 'Not Paid';
            PS.Contact_Email__c = String.isNotBlank(emailadress) ? emailadress : 'default@example.com';
            PS.PAN_No__c = String.isNotBlank(donationRequest.panNumber) ? donationRequest.panNumber : 'Default PAN';
            PS.Address_Line_1__c = String.isNotBlank(donationRequest.currentAddress) ? donationRequest.currentAddress : 'Default Address';
            // PS.Mode_of_Payment__c = donationRequest.paymentMode != null ? donationRequest.paymentMode : 'Payment Gateway';
            PS.Mode_of_Payment__c = 'Payment Gateway';
            PS.Name__c = conList1[0].Id;
            PS.Currency__c = donationRequest.donationCurrency != null ? donationRequest.donationCurrency : 'INR';
            PS.ForexRatetoINR__c = 1;
            PS.Pledge__c = donationRequest.amount != null ? donationRequest.amount : 0; 
            PS.No_of_Installments__c = 1;
            //PS.OwnerId = userId;
            PS.Is_donation_Anonymous__c = donationRequest.anonymousDonation == true ? 'Yes' : 'No';
            PS.Contact_Email__c=donationRequest.email;
            PS.Postal_Code__c=donationRequest.pincode;
            PS.Address_Line_1__c = donationRequest.currentAddress;

            system.debug('Pledges_Summary__c before insert: ' + PS);
            

            // Insert the record
            insert PS;
            system.debug('Pledges_Summary__c inserted successfully: ' + PS.Id);
        } catch (DmlException e) {
            system.debug('Error inserting Pledges_Summary__c: ' + e.getMessage());
            throw new AuraHandledException('Error creating Pledges Summary: ' + e.getMessage());
        }
        
        Pledges_Summary__c psname = [SELECT Id,Name from Pledges_Summary__c where Id =: ps.Id];
        Pledge_details__c pd = new Pledge_details__c();
        system.debug('ps.Name'+psname.Name);
        if (!listPledgeDetails.isEmpty()) {
            pd.Id = listPledgeDetails[0].Id;
        }
        // pd.Name = psname.Name + '-' + 1;
        // pd.currency__c = donationRequest.donationCurrency != null ? donationRequest.donationCurrency : 'INR';
        // pd.Sub_Pledge_Amount__c = donationRequest.amount;
        // pd.Pledge_Summary__c = PS.Id;
        // pd.PLD_Status__c  ='Not Paid';
        // system.debug('email test'+donationRequest.email);
        // pd.Contact_Email__c = emailadress;
        // pd.RecordTypeId = subPledgerecordtype;
        // pd.Mode_of_Payment__c = donationRequest.paymentMode != null ? donationRequest.paymentMode : 'Payment Gateway';
        // pd.Name__c = conList1[0].Id;
        // pd.Sub_Pledge_Amount__c = donationRequest.amount;
        // pd.NoOfInstallments__c =1;
        // Pd.OwnerId=userId;
        
        try {
            // Ensure all fields have valid values
            pd.Name = psname.Name + '-' + 1;
            pd.currency__c = donationRequest.donationCurrency != null ? donationRequest.donationCurrency : 'INR';
            pd.Sub_Pledge_Amount__c = donationRequest.amount != null ? donationRequest.amount : 0;
            pd.Pledge_Summary__c = PS.Id;
            pd.PLD_Status__c = 'Not Paid';
            pd.Contact_Email__c = String.isNotBlank(emailadress) ? emailadress : 'default@example.com';
            pd.RecordTypeId = subPledgerecordtype;
            pd.Mode_of_Payment__c =  'Payment Gateway';
            pd.Name__c = conList1[0].Id;
            pd.NoOfInstallments__c = 1;

            //pd.OwnerId = userId;

            system.debug('Pledge_details__c before upsert: ' + pd);

            // Upsert the record
            upsert pd;
            system.debug('Pledge_details__c upserted successfully: ' + pd.Id);
        } catch (DmlException e) {
            system.debug('Error upserting Pledge_details__c: ' + e.getMessage());
            throw new AuraHandledException('Error creating Pledge Details: ' + e.getMessage());
        }
        
        try{
            List<Transaction_Details__c> listTransactionsToDelete = new List<Transaction_Details__c>();
            if (!listTransactions.isEmpty()) {
                for (Transaction_Details__c transactionInstance: listTransactions) {
                    if (String.isBlank(transactionInstance.Payment_Gateway_URL__c)) {
                        objTranscation.Id = transactionInstance.Id;
                    } else if (String.isNotBlank(transactionInstance.Payment_Gateway_URL__c)) {
                        listTransactionsToDelete.add(transactionInstance);
                    }
                }
            }
            if (!listTransactionsToDelete.isEmpty()) {
                delete listTransactionsToDelete;
            }
            
            objTranscation.Pledge_detail__c = pd.id;
            objTranscation.Pledge_Summary__c = ps.id;
            objTranscation.Contact__c = conList1[0].Id;
            objTranscation.Mode_of_Payment__c = donationRequest.paymentMode != null ? donationRequest.paymentMode : 'Payment Gateway';
            // objTranscation.PIN_Code__c = processedContact.Current_Postal_Code__c;
            objTranscation.PIN_Code__c = donationRequest.pincode ;
            system.debug('PIN_Code__c: ' + objTranscation.PIN_Code__c);
            // objTranscation.Address__c = processedContact.Current_Address_Line_1__c;
            objTranscation.Address__c = donationRequest.currentAddress;
            objTranscation.PAN_Number__c = donationRequest.panNumber;
            
            objTranscation.Name_on_online_donation_form__c = donationRequest.name;
            objTranscation.Donor_s_Phone_Number__c = donationRequest.phone;
            objTranscation.Contact_Email__c = donationRequest.email;
            // objTranscation.PIN_Code__c=donationRequest.pincode;
            
            
            upsert objTranscation;
            
        }
        catch(exception e){
            system.debug('738'+e);
        }      
        donationRequest.transactionID = objTranscation.id;
        return donationRequest;
    }
}