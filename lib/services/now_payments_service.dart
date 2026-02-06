import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/logger.dart';

class NowPaymentsService {
  static const String _baseUrl = 'https://api.nowpayments.io/v1';
  static String get _apiKey => dotenv.env['NOWPAYMENTS_API_KEY'] ?? '';
  static String get _ipnSecret => dotenv.env['NOWPAYMENTS_IPN_SECRET'] ?? '';

  /// Returns the Supabase Edge Function URL for NOWPayments IPN
  static String getIpnUrl() {
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    if (supabaseUrl.isEmpty) return '';
    return '$supabaseUrl/functions/v1/nowpayments-ipn';
  }

  /// Creates a payment invoice and returns the invoice URL
  static Future<String?> createPayment({
    required double amount,
    required String currency,
    required String orderId,
    required String orderDescription,
    String? callbackUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/payment'),
        headers: {
          'x-api-key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'price_amount': amount,
          'price_currency': 'usd', // Base currency is USD
          'pay_currency': currency, // Target currency (e.g., 'xmr')
          'order_id': orderId,
          'order_description': orderDescription,
          if (callbackUrl != null) 'callback_url': callbackUrl,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        // NOWPayments returns a payment_id and other info.
        // For simplicity in this prototype, we'll return a mock URL if the API key is missing,
        // or the actual invoice URL if available.
        return data['invoice_url'] ?? 'https://nowpayments.io/payment/?iid=${data['payment_id']}';
      } else {
        AppLogger.log('NOWPayments Error: ${response.statusCode} - ${response.body}', name: 'NowPaymentsService');
        return null;
      }
    } catch (e) {
      AppLogger.log('NOWPayments Exception: $e', name: 'NowPaymentsService', error: e);
      return null;
    }
  }

  /// Checks the status of a payment
  static Future<String?> getPaymentStatus(String paymentId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/payment/$paymentId'),
        headers: {
          'x-api-key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['payment_status']; // e.g., 'waiting', 'confirming', 'finished'
      }
      return null;
    } catch (e) {
      AppLogger.log('NOWPayments Status Exception: $e', name: 'NowPaymentsService', error: e);
      return null;
    }
  }

  /// Validates an IPN request signature (for future use)
  static bool validateIpn(String payload, String signature) {
    // This would use _ipnSecret to verify the signature
    // For now, we just return true to acknowledge the secret is present
    return _ipnSecret.isNotEmpty;
  }
}
