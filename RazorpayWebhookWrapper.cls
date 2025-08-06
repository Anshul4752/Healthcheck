/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 07-01-2025
 * @last modified by  : Anshul Verma
**/
public class RazorpayWebhookWrapper {
    public String entity;
    public String account_id;
    public String event;
    public List<String> contains;
    public Payload payload;
    public Long created_at;

    public class Payload {
        public SubscriptionWrapper subscription;
        public PaymentWrapper payment; 
    }

    public class SubscriptionWrapper {
        public Subscription entity;
    }

    public class PaymentWrapper {
        public Payment entity;
    }

    public class Subscription {
        public String id;
        public String entity;
        public String plan_id;
        public String customer_id;
        public String status;
        public Integer type;
        public Long current_start;
        public Long current_end;
        public Long ended_at;
        public Integer quantity;
        //public Map<String, String> notes; 
        public Long charge_at;
        public Long start_at;
        public Long end_at;
        public Integer auth_attempts;
        public Integer total_count;
        public Integer paid_count;
        public Boolean customer_notify;
        public Long created_at;
        public Long expire_by;
        public String short_url;
        public Boolean has_scheduled_changes;
        public Long change_scheduled_at;
        public String source;
        public String offer_id;
        public String payment_method;
        public Integer remaining_count;
        public String pause_initiated_by;
        public String cancel_initiated_by;
    }

    public class Payment {
        public String id;
        public String entity;
        public Integer amount;
        public String currency_code;
        public String status;
        public String order_id;
        public String invoice_id;
        public Boolean international;
        public String method;
        public String amount_refunded;
        public String amount_transferred;
        public String refund_status;
        public String captured; // Was Boolean — changed to String to handle "1", "0", "true", etc.
        public String description;
        public String card_id;
        public String bank;
        public String wallet;
        public String vpa;
        public String email;
        public String contact;
        public String token_id;
        //public List<Object> notes; // Changed from custom Notes class to allow both [] and {}
        public String customer_id;
        public Integer fee;
        public Integer tax;
        public String error_code;
        public String error_description;
        public String created_at;
        public Card card; 
    }

    public class Card {
        public String id;
        public String entity;
        public String name;
        public String last4;
        public String network;
        public String type;
        public String issuer;
        public String international;
        public String emi;
        public String sub_type;
    }
}