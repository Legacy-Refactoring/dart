// legacy.dart
// Extremely insecure legacy payment system in Dart
// Educational bad code example - full of SQL injection, plain text secrets, massive code duplication

import 'dart:io';
import 'dart:convert';
import 'package:postgres/postgres.dart';

class LegacyPaymentSystem {
  static const String DB_HOST = 'localhost';
  static const String DB_PORT = '5432';
  static const String DB_NAME = 'payment_legacy_db';
  static const String DB_USER = 'postgres';
  static const String DB_PASS = 'SuperSecret123!';
  static const String SITE_SECRET = 'myglobalsecret123';

  static PostgreSQLConnection? _globalConn;

  static Future<PostgreSQLConnection> _getConnection() async {
    if (_globalConn == null || _globalConn!.isClosed) {
      _globalConn = PostgreSQLConnection(
        DB_HOST,
        int.parse(DB_PORT),
        DB_NAME,
        username: DB_USER,
        password: DB_PASS,
      );
      await _globalConn!.open();
      await _globalConn!.query("SET client_encoding = 'UTF8';");
    }
    return _globalConn!;
  }

  static Future<void> _appendToLog(String msg) async {
    try {
      final file = File('legacy_errors.log');
      await file.writeAsString(
        '${DateTime.now()} | $msg\n',
        mode: FileMode.append,
      );
    } catch (_) {}
  }

  static Future<void> register_customer(
    String username,
    String email,
    String password,
    String full_name, {
    String phone = '',
    String country = 'RS',
    String city = '',
    String address = '',
  }) async {
    try {
      final conn = await _getConnection();
      final id = 'cust_${DateTime.now().millisecondsSinceEpoch}';
      final sql = '''
        INSERT INTO customers (
          id, username, email, password, full_name, phone, country, city, address_line_1,
          created_at, updated_at, register_ip, user_agent, is_admin, role_name
        ) VALUES (
          '$id', '$username', '$email', '$password', '$full_name', '$phone', '$country', '$city', '$address',
          NOW()::text, NOW()::text, '127.0.0.1', 'DART-LEGACY', 'false', 'customer'
        ) RETURNING id;
      ''';

      final result = await conn.query(sql);
      if (result.isNotEmpty) {
        print('Customer registered ID: ${result.first.first}');
      }
    } catch (e) {
      print('[ERROR] $e');
      await _appendToLog('$e');
    }
  }

  static Future<void> login_customer(String username, String password) async {
    try {
      final conn = await _getConnection();
      final sql = "SELECT * FROM customers WHERE username = '$username' AND password = '$password' LIMIT 1;";

      final result = await conn.query(sql);
      if (result.isNotEmpty) {
        final id = result.first.toColumnMap()['id'];
        final session_token = DateTime.now().millisecondsSinceEpoch.toString();
        final update = '''
          UPDATE customers SET session_token = '$session_token', 
          last_login_ip = '127.0.0.1', failed_login_count = '0', 
          updated_at = NOW()::text WHERE id = '$id';
        ''';
        await conn.query(update);
        print('LOGIN SUCCESS Session: $session_token');
      } else {
        final failSql = "UPDATE customers SET failed_login_count = (failed_login_count::int + 1)::text WHERE username = '$username';";
        await conn.query(failSql);
        print('LOGIN FAILED');
      }
    } catch (e) {
      print('[ERROR] $e');
      await _appendToLog('$e');
    }
  }

  static Future<void> get_customer(String customer_id) async {
    try {
      final conn = await _getConnection();
      final sql = "SELECT * FROM customers WHERE id = '$customer_id' LIMIT 1;";
      final result = await conn.query(sql);
      if (result.isNotEmpty) {
        print('Customer found: ${result.first.toColumnMap()['username']}');
      }
    } catch (e) {
      print('[ERROR] $e');
      await _appendToLog('$e');
    }
  }

  static Future<void> update_customer_profile(String customer_id, String new_email, String new_phone, String new_address) async {
    try {
      final conn = await _getConnection();
      final sql = "UPDATE customers SET email = '$new_email', phone = '$new_phone', " +
                  "address_line_1 = '$new_address', updated_at = NOW()::text WHERE id = '$customer_id';";
      await conn.query(sql);
      print('Customer profile updated');
    } catch (e) {
      print('[ERROR] $e');
      await _appendToLog('$e');
    }
  }

  static Future<void> reset_password(String email, String new_password) async {
    try {
      final conn = await _getConnection();
      final sql = "UPDATE customers SET password = '$new_password', " +
                  "reset_token = 'reset_' || md5(NOW()::text), " +
                  "reset_token_expires_at = (NOW() + INTERVAL '1 day')::text WHERE email = '$email';";
      await conn.query(sql);
      print('Password reset token generated for $email');
    } catch (e) {
      print('[ERROR] $e');
      await _appendToLog('$e');
    }
  }

  static Future<void> verify_email(String token) async {
    try {
      final conn = await _getConnection();
      final sql = "UPDATE customers SET email_verification_token = NULL WHERE email_verification_token = '$token';";
      await conn.query(sql);
      print('Email verified with token $token');
    } catch (e) {
      print('[ERROR] $e');
      await _appendToLog('$e');
    }
  }

  static Future<void> add_payment_method(
    String customer_id,
    String type,
    String card_number,
    String expiry_month,
    String expiry_year,
    String cvv,
    String holder_name, {
    String iban = '',
  }) async {
    try {
      final conn = await _getConnection();
      final id = 'pm_${DateTime.now().millisecondsSinceEpoch}';
      final sql = '''
        INSERT INTO payment_methods (
          id, customer_id, type, provider, card_number, card_expiry_month, card_expiry_year,
          card_cvv, card_holder_name, iban, active_flag, created_at, updated_at
        ) VALUES (
          '$id', '$customer_id', '$type', 'legacy_bank_gateway', '$card_number', '$expiry_month',
          '$expiry_year', '$cvv', '$holder_name', '$iban', 'true', NOW()::text, NOW()::text
        ) RETURNING id;
      ''';

      final result = await conn.query(sql);
      if (result.isNotEmpty) {
        print('Payment method added ID: ${result.first.first}');
      }
    } catch (e) {
      print('[ERROR] $e');
      await _appendToLog('$e');
    }
  }

  static Future<void> process_payment(
    String customer_id,
    String payment_method_id,
    String amount, {
    String currency = 'EUR',
    String? external_order_id,
    String? ip,
  }) async {
    try {
      final conn = await _getConnection();
      final id = 'pay_${DateTime.now().millisecondsSinceEpoch}';
      final realIp = ip ?? '127.0.0.1';
      final extOrder = external_order_id ?? 'ord_${DateTime.now().millisecondsSinceEpoch}';
      final rawPayload = '{"card_number":"****4242","provider_secret":"sk_live_9876543210abcdef","cvv_used":"123","3ds_password":"customer123"}';

      final sql = '''
        INSERT INTO payments (
          id, customer_id, payment_method_id, external_order_id, amount, currency, status,
          provider_ref, ip_address, raw_provider_payload, created_at, paid_at, captured_flag
        ) VALUES (
          '$id', '$customer_id', '$payment_method_id', '$extOrder', '$amount', '$currency', 'captured',
          'prov_${DateTime.now().millisecondsSinceEpoch}', '$realIp', '$rawPayload', NOW()::text, NOW()::text, 'true'
        ) RETURNING id;
      ''';

      final result = await conn.query(sql);
      if (result.isNotEmpty) {
        final payId = result.first.first;
        final update = "UPDATE customers SET total_paid = (COALESCE(total_paid::numeric, 0) + $amount)::text WHERE id = '$customer_id';";
        await conn.query(update);
        print('PAYMENT PROCESSED ID: $payId Amount: $amount $currency');
      }
    } catch (e) {
      print('[ERROR] $e');
      await _appendToLog('$e');
    }
  }

  static Future<void> list_payments(String customer_id) async {
    try {
      final conn = await _getConnection();
      final sql = "SELECT * FROM payments WHERE customer_id = '$customer_id' ORDER BY created_at DESC;";
      final result = await conn.query(sql);
      print('Listed ${result.length} payments for customer');
    } catch (e) {
      print('[ERROR] $e');
      await _appendToLog('$e');
    }
  }

  static Future<void> create_refund(String payment_id, String amount, [String reason = 'customer request']) async {
    try {
      final conn = await _getConnection();
      final id = 'ref_${DateTime.now().millisecondsSinceEpoch}';
      final sql = "INSERT INTO refunds (id, payment_id, amount, currency, status, reason, created_at) " +
                  "VALUES ('$id', '$payment_id', '$amount', 'EUR', 'pending', '$reason', NOW()::text);";
      await conn.query(sql);
      print('Refund created for payment $payment_id');
    } catch (e) {
      print('[ERROR] $e');
      await _appendToLog('$e');
    }
  }

  static Future<void> process_refund(String refund_id) async {
    try {
      final conn = await _getConnection();
      final sql = "UPDATE refunds SET status = 'processed', processed_at = NOW()::text WHERE id = '$refund_id';";
      await conn.query(sql);
      print('Refund processed ID: $refund_id');
    } catch (e) {
      print('[ERROR] $e');
      await _appendToLog('$e');
    }
  }

  static Future<void> simulate_chargeback(String payment_id, String amount, [String reason = 'fraud']) async {
    try {
      final conn = await _getConnection();
      final id = 'cb_${DateTime.now().millisecondsSinceEpoch}';
      final sql = "INSERT INTO chargebacks (id, payment_id, amount, currency, reason, status, created_at, deadline_at) " +
                  "VALUES ('$id', '$payment_id', '$amount', 'EUR', '$reason', 'open', NOW()::text, (NOW() + INTERVAL '7 days')::text);";
      await conn.query(sql);
      print('Chargeback created for payment $payment_id');
    } catch (e) {
      print('[ERROR] $e');
      await _appendToLog('$e');
    }
  }

  static Future<void> resolve_chargeback(String chargeback_id, [String won = 'true']) async {
    try {
      final conn = await _getConnection();
      final sql = "UPDATE chargebacks SET status = 'closed', won_flag = '$won', closed_at = NOW()::text WHERE id = '$chargeback_id';";
      await conn.query(sql);
      print('Chargeback resolved ID: $chargeback_id');
    } catch (e) {
      print('[ERROR] $e');
      await _appendToLog('$e');
    }
  }

  static Future<void> create_fraud_review(String payment_id, String customer_id, [String score = '85']) async {
    try {
      final conn = await _getConnection();
      final id = 'fraud_${DateTime.now().millisecondsSinceEpoch}';
      final sql = "INSERT INTO fraud_reviews (id, payment_id, customer_id, score, decision, created_at) " +
                  "VALUES ('$id', '$payment_id', '$customer_id', '$score', 'pending', NOW()::text);";
      await conn.query(sql);
      print('Fraud review created for payment $payment_id');
    } catch (e) {
      print('[ERROR] $e');
      await _appendToLog('$e');
    }
  }

  static Future<void> decide_fraud_review(String review_id, String decision, String reviewer_email, String reviewer_password) async {
    try {
      final conn = await _getConnection();
      final check = "SELECT * FROM customers WHERE email = '$reviewer_email' AND password = '$reviewer_password' AND is_admin = 'true';";
      final result = await conn.query(check);
      if (result.isNotEmpty) {
        final sql = "UPDATE fraud_reviews SET decision = '$decision', reviewer = '$reviewer_email', updated_at = NOW()::text WHERE id = '$review_id';";
        await conn.query(sql);
        print('Fraud review decided as $decision');
      } else {
        print('Fraud review access denied');
      }
    } catch (e) {
      print('[ERROR] $e');
      await _appendToLog('$e');
    }
  }

  static Future<void> admin_export_all_data() async {
    try {
      final conn = await _getConnection();
      final sql = '''
        COPY (
          SELECT * FROM customers 
          UNION ALL SELECT * FROM payments 
          UNION ALL SELECT * FROM payment_methods 
          UNION ALL SELECT * FROM refunds 
          UNION ALL SELECT * FROM chargebacks 
          UNION ALL SELECT * FROM fraud_reviews
        ) TO '/tmp/legacy_full_export_${DateTime.now().millisecondsSinceEpoch}.csv' WITH CSV HEADER;
      ''';
      await conn.query(sql);
      print('Full data export completed to /tmp/legacy_full_export_*.csv');
    } catch (e) {
      print('[ERROR] $e');
      await _appendToLog('$e');
    }
  }

  static Future<void> ban_customer(String customer_id) async {
    try {
      final conn = await _getConnection();
      final sql = "UPDATE customers SET blocked_flag = 'true' WHERE id = '$customer_id';";
      await conn.query(sql);
      print('Customer banned');
    } catch (e) {
      print('[ERROR] $e');
      await _appendToLog('$e');
    }
  }

  static Future<void> generate_api_key(String customer_id) async {
    try {
      final conn = await _getConnection();
      final key = 'key_${DateTime.now().millisecondsSinceEpoch}';
      final secret = 'secret_${DateTime.now().millisecondsSinceEpoch * 2}';
      final sql = "UPDATE customers SET api_key = '$key', api_secret = '$secret' WHERE id = '$customer_id';";
      await conn.query(sql);
      print('API key generated: $key');
    } catch (e) {
      print('[ERROR] $e');
      await _appendToLog('$e');
    }
  }

  static Future<void> main() async {
    print('LEGACY PAYMENT SYSTEM STARTED (Dart version)');

    await register_customer('testuser1', 'test1@example.com', 'PlainPass123', 'Test User One', '381601234567', 'RS', 'Belgrade', 'Novi Beograd 1');
    await register_customer('testuser2', 'test2@example.com', 'AnotherPass456', 'Test User Two', '381609876543', 'RS', 'Novi Sad', 'Address 2');

    await login_customer('testuser1', 'PlainPass123');
    await login_customer('testuser2', 'AnotherPass456');

    await add_payment_method('cust_...', 'card', '4242424242424242', '12', '2028', '123', 'Test User One');
    await add_payment_method('cust_...', 'iban', '', '', '', '', 'Test User Two', 'RS12345678901234567890');

    await process_payment('cust_...', 'pm_...', '149.99', 'EUR', 'ORDER-1001');
    await process_payment('cust_...', 'pm_...', '299.50', 'USD', 'ORDER-1002');

    await create_refund('pay_...', '49.99', 'partial return');
    await process_refund('ref_...');

    await simulate_chargeback('pay_...', '299.50', 'dispute');
    await resolve_chargeback('cb_...', 'false');

    await create_fraud_review('pay_...', 'cust_...', '78');
    await decide_fraud_review('fraud_...', 'approve', 'admin@legacy.com', 'AdminPass123');

    await reset_password('test1@example.com', 'NewPlainPass789');
    await verify_email('email_verify_token_demo');

    await admin_export_all_data();

    await ban_customer('cust_...');
    await generate_api_key('cust_...');

    print('LEGACY PAYMENT SYSTEM WORKFLOW COMPLETE');
  }
}

// Run the demo
void main() async {
  await LegacyPaymentSystem.main();
}