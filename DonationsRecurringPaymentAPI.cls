public class DonationsRecurringPaymentAPI {
    //TODO:
    //for the custom amount planID is checked
    //based on planID -> create planId or use existing one
    //Calculate total count based on duration and frequency
    //create subscription
    //on success pass the subId to lwc to use in the checkout button
    //Schedule a class to check on the subscription if it is abandoned and delete from sf and rp
    // use the existing vf page for callback --> to be checked for the parameters
    // To check for the existing inactive not expired subscriptions
    // Custom Subscription plan object to store the custom combo of the plans
    // Transactions, Pledge and sub pledge should be created based on the subscription
    public enum FrequencyType {
        Monthly,
        Quarterly,
        Yearly
    }
    @AuraEnabled
    public static isbDonationResponseWrapper checkForActiveSubscription(isbDonationRequestWrapper req){
        List<Subscription__c > inactiveSubscription = new List<Subscription__c >();
        
     
       if(req.objContact.Id != null && req.planID != null){
            inactiveSubscription = [SELECT ID,Short_URL__c, Status__c,Subscription_ID__c  FROM Subscription__c WHERE Contact__c = :req.objContact.Id AND Plan_ID__c =:req.planID AND Status__c = 'created' LIMIT 1];
            if(!inactiveSubscription.IsEmpty() ){
                isbDonationResponseWrapper res = new isbDonationResponseWrapper();
                res.shortURL = inactiveSubscription[0].Short_URL__c;
                res.isNewSubscription = false;
                res.subscriptionId = inactiveSubscription[0].Subscription_ID__c;
                
                return res;
            }
            else if(req.planID == null ){
                //Creating new planId through API
                //req.planID = createPlan(req);
                // createSubscriptionSync(req);

            //throw new Aura Exception
               
            }
           else if(req.planId!=null){
                return createSubscriptionSync(req);
           }
        }
        return null;
    }
    
    
   
    
    
    public static isbDonationResponseWrapper createSubscriptionSync(isbDonationRequestWrapper req) {
        req.totalCount = calculateTotal(req.frequency,req.duration);
        System.debug('req.totalcount '+ req.totalCount);
        
        Map<String,Object> mapBody = new Map<String,Object>{
            'plan_id' => req.planID,
            'total_count' => req.totalCount
        };
       
        DateTime dt = DateTime.now();           // UTC datetime
        DateTime subscriptionLinkAuthExpirationTime = dt.addMinutes(60);// setting the auth link expiry to 15 min
        Long unixSeconds = UnixDateTimeUtil.dateTimeToUnixSeconds(subscriptionLinkAuthExpirationTime); // Convert to seconds
        isbDonationResponseWrapper response = new isbDonationResponseWrapper();
        mapBody.put('expire_by',unixSeconds);

        String jsonBody = JSON.serialize(mapBody);

        // 3. HTTP Callout (no DML before this)
        HttpRequest httpReq = new HttpRequest();
        httpReq.setEndpoint('callout:Razorpay_NamedCred/v1/subscriptions');
        httpReq.setMethod('POST');
        httpReq.setHeader('Content-Type','application/json');
        httpReq.setBody(jsonBody);
        
        HttpResponse httpRes;
        try {
            httpRes = new Http().send(httpReq);
        } catch (CalloutException ex) {
         System.debug('Callout error: '+ex.getMessage());
            return null;
           
        }

        // 4. Process Response
        Response res = new Response();
        res.statusCode = httpRes.getStatusCode();
        res.body = httpRes.getBody();
        System.debug('res'+res);
        if (res.statusCode >= 200 && res.statusCode < 300) {
            Map<String,Object> respMap = (Map<String,Object>)JSON.deserializeUntyped(res.body);
           
            
            res.subscriptionId = (String)respMap.get('id');
            response.subscriptionId = res.subscriptionId;
            res.success = true;
            res.shortURL = (String)respMap.get('short_url');
            res.subscriptionStatus = (String)respMap.get('status');
            
            createSubscriptionsRecords(req, res);
            
            
        } else {
            res.success = false;
            res.error = 'Razorpay returned '+res.statusCode+': '+res.body;
        }
        return response;
    }
    
    private static  void createSubscriptionsRecords(isbDonationRequestWrapper req, Response res){ //creates the subscription record on successful response from API
        try{
        Subscription__c sub = new Subscription__c();
        sub.Status__c =  res?.subscriptionStatus;
        sub.Short_URL__c = res?.shortURL;
        sub.Subscription_ID__c = res?.subscriptionId;
        sub.Contact__c = req?.objContact?.Id;
        sub.Quantity__c = 1;
        sub.Total_Count__c = req.totalCount;
        sub.Frequency__c = req.frequency;
        
        
        
        insert sub;
        createTransactionDeatils(req, sub);
            
        }
        catch(Exception ex){
            
        }
        
        
    }
    
    private static void createTransactionDeatils (isbDonationRequestWrapper req, Subscription__c sub){
        Transaction_Details__c objTranscation = new Transaction_Details__c();
        objTranscation.Transaction_Date__c = system.today();
        objTranscation.Payment_Status__c= 'Not Paid';
        //objTranscation.OwnerId=userId;
        objtranscation.This_is_an_anonymous_gift__c = req?.objDonation.gift_to_be_anonymous__c;
        system.debug('objContact998899'+req?.objDonation);
        if(req?.objDonation.Passport_Number__c != NUll){
            objtranscation.Passport_Number__c =req?.objDonation.Passport_Number__c;
        }
        objTranscation.Contact__c = req?.objContact?.Id;
        objTranscation.Mode_of_Payment__c ='Payment Gateway';
        objTranscation.PIN_Code__c = req?.objContact?.Current_Postal_Code__c;
        objTranscation.Address__c= req?.objContact?.Current_Address_Line_1__c;
        objTranscation.PAN_Number__c = req?.objDonation?.PAN_No__c ;
        objTranscation.Name_on_online_donation_form__c = req?.objContact?.Name;
        objTranscation.Donor_s_Phone_Number__c = req?.objContact?.Indian_Mobile_Number__c;
        Pledge_details__c ps = createPledgeAndPledgeDeatils(req, sub);
        objTranscation.Pledge_Summary__c = ps.Pledge_Summary__c;
        objTranscation.Pledge_detail__c = ps.Id;
        objTranscation.Subscription_ID__c = sub.Subscription_ID__c;
        
        
        upsert objTranscation;
    }
    
    private static Pledge_details__c createPledgeAndPledgeDeatils(isbDonationRequestWrapper req, Subscription__c sub){
        Id Pledgerecordtype = Schema.SObjectType.Pledges_Summary__c.getRecordTypeInfosByName().get('One Time Donation').getRecordTypeId();
        Id subPledgerecordtype = Schema.SObjectType.Pledge_details__c.getRecordTypeInfosByName().get('One time Donation').getRecordTypeId();
        List<Pledge_details__c> pdList = new List<Pledge_details__c>();
        
        //Creating pledge Summaries
        Pledges_Summary__c PS = new Pledges_Summary__c();
        PS.Pledged_Amount_In_donor_currency__c = req?.objDonation?.Amount__c * req?.totalCount;//req?.objDonation.Amount__c;
        ps.NoOfSubPledges__c = req?.totalCount;
        ps.RecordTypeId = Pledgerecordtype;
        ps.Transaction_Status__c ='Not Paid';
        //system.debug('email test 555'+objDonation.Contact_Email__c);
        ps.Contact_Email__c = req?.objDonation?.Contact_Email__c;
        ps.PAN_No__c = req?.objDonation?.PAN_No__c;
        ps.Address_Line_1__c = req?.objContact?.Current_Address_Line_1__c;
        ps.Mode_of_Payment__c ='Payment Gateway';
        //system.debug('contact pledge'+ conList1[0].id);
        ps.Name__c = req?.objContact?.Id;
        ps.Currency__c ='INR';
        ps.ForexRatetoINR__c =1;
        ps.Pledge__c = req?.objDonation?.Amount__c * req?.totalCount;
        ps.No_of_Installments__c =1;
       // ps.OwnerId=userId;
        system.debug('contact pledge'+ ps.Contact__c);
        if(req?.objDonation.gift_to_be_anonymous__c == true){
            ps.Is_donation_Anonymous__c ='Yes';
        }else{
            ps.Is_donation_Anonymous__c ='NO';
        }
        ps.Subscription__c = sub.Id;
        upsert ps;
        //Querying the inserted pledge summary to get the name 
   		Pledges_Summary__c psname = [SELECT Id,Name from Pledges_Summary__c where Id =: ps.Id];
        //Creating pledge deatils
        for(Integer i =0; i<req.totalCount;i++){
        Pledge_details__c pd = new Pledge_details__c();
   
        pd.Name = psname.Name + '-' + Integer.valueof(i+1);
        pd.currency__c = 'INR';
        pd.Sub_Pledge_Amount__c = req?.objDonation?.Amount__c;
        pd.Pledge_Summary__c = PS.Id;
        pd.PLD_Status__c  ='Not Paid';
        //system.debug('email test'+objDonation.Contact_Email__c);
        pd.Contact_Email__c = req?.objDonation?.Contact_Email__c;
        pd.RecordTypeId =subPledgerecordtype;
        pd.Mode_of_Payment__c ='Payment Gateway';
        pd.Name__c = req?.objContact?.Id;
        pd.Sub_Pledge_Amount__c  = req?.objDonation?.Amount__c;
        pd.NoOfInstallments__c = req?.totalCount;
        pd.Subscription_Sub_Pledge_Number__c = i+1;
        pd.Subscription__c = sub.Id;
        //Pd.OwnerId=userId;
        pdList.add(pd);
        }
        
        if(!pdList.isEmpty()){
        upsert pdList;
        }
    
        
        return pdList[0];
    }
    
    public static Integer calculateTotal(String frequency, Integer duration) {
        if (duration == null || duration < 0) {
            throw new IllegalArgumentException('Duration must be a non-negative integer');
        }
        if (String.isBlank(frequency)) {
            throw new IllegalArgumentException('Frequency must be provided');
        }

        FrequencyType freq;
        try {
            freq = FrequencyType.valueOf(frequency);
        } catch (Exception e) {
            throw new IllegalArgumentException('Invalid frequency value: ' + frequency);
        }

        Integer factor;
        switch on freq {
            when Monthly {
                factor = 12;
            }
            when Quarterly {
                factor = 4;
            }
            when Yearly {
                factor = 1;
            }
            when else {
                throw new IllegalArgumentException('Unsupported frequency: ' + frequency);
            }
        }

        return duration * factor;
    }
    
    public class Request {
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String period;
        @AuraEnabled public String interval;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Long startAtUnix;
        @AuraEnabled public Decimal upfrontAmount;
        @AuraEnabled public String planID;
        @AuraEnabled public Contact objContact;
        @AuraEnabled public Donation__c objDonation;
    }
    
    public class Response {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String subscriptionId;
        @AuraEnabled public Integer statusCode;
        @AuraEnabled public String body;
        @AuraEnabled public String error;
        @AuraEnabled public Boolean isNewSubscription = true;
        @AuraEnabled public String shortURL; //contains re-direction url for payment authentication
        /*subscription fields*/
        @AuraEnabled public Integer authAttempts;
        @AuraEnabled public Long changeScheduleAt;
        @AuraEnabled public Long chargeAt;
        @AuraEnabled public Long currentStart;
        @AuraEnabled public Long currentEnd;
        @AuraEnabled public Long endedAt;
        @AuraEnabled public Long expireBy;
        @AuraEnabled public Boolean hasScheduledChanges;
        @AuraEnabled public String subscriptionStatus;
        
        
    }

}