public  class RazorpaySubCtrl {
  public  String subscriptionId { get; private set; }
  public String callbackUrl { get; private set; }
  public String razorPayUserName {get; private set;}
  public String contactId {get; private set;}

  public RazorpaySubCtrl() {
    subscriptionId = ApexPages.currentPage().getParameters().get('subscriptionId');
    //contactId = ApexPages.currentPage().getParameters().get('conId');
   // Contact con = [select id, name, email from contact where Id = :contactId];
    
    razorPayUserName = System.Label.RazorPayUsername;
    //String host = URL.getOrgDomainUrl().toExternalForm()().toExternalForm();
    callbackUrl = System.Label.Razorpay_Subscriptions_Callback_URL;
    
      
      
  }
}