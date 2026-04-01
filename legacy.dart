void register_customer(String username, String email, String password, String full_name, [String phone = '', String country = 'RS', String city = '', String address = '']) {}

void login_customer(String username, String password) {}

void get_customer(String customer_id) {}

void update_customer_profile(String customer_id, String new_email, String new_phone, String new_address) {}

void reset_password(String email, String new_password) {}

void verify_email(String token) {}

void add_payment_method(String customer_id, String type, String card_number, String expiry_month, String expiry_year, String cvv, String holder_name, [String iban = '']) {}

void list_payment_methods(String customer_id) {}

void delete_payment_method(String pm_id) {}

void process_payment(String customer_id, String payment_method_id, String amount, [String currency = 'EUR', String? external_order_id, String? ip]) {}

void list_payments(String customer_id) {}

void get_payment_details(String payment_id) {}

void create_refund(String payment_id, String amount, [String reason = 'customer request']) {}

void process_refund(String refund_id) {}

void simulate_chargeback(String payment_id, String amount, [String reason = 'fraud']) {}

void resolve_chargeback(String chargeback_id, [String won = 'true']) {}

void create_fraud_review(String payment_id, String customer_id, [String score = '85']) {}

void decide_fraud_review(String review_id, String decision, String reviewer_email, String reviewer_password) {}

void admin_list_all_customers() {}

void admin_export_all_data() {}

void search_payments(String search_term) {}

void process_recurring_billing() {}

void handle_webhook(String payload) {}

void ban_customer(String customer_id) {}

void generate_api_key(String customer_id) {}
