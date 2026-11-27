import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/storage_helper.dart';

// Conditional import: web uses Checkout.js, mobile uses razorpay_flutter.
import 'razorpay_mobile.dart'
    if (dart.library.js) 'razorpay_web.dart';

/// High-level Razorpay checkout that works on both web and mobile.
///
/// Flow:
/// 1. Backend creates an order (create-order / add-to-wallet)
/// 2. openCheckout(...) opens the Razorpay UI and returns payment id/order id/signature
/// 3. Backend verifies the signature (verify-payment / verify-wallet-payment)
class RazorpayCheckout {
  static const _themeColor = '#FFC107';

  static Future<Map<String, String>> _headers() async {
    final token = await StorageHelper.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// POSTs JSON and always returns a map with `success` and `message`, even when
  /// the server is down, times out, or replies with non-JSON (e.g. Render waking up).
  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final res = await http
          .post(Uri.parse('${ApiConfig.baseUrl}$path'), headers: await _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 60));
      try {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) return data;
      } catch (_) {}
      return {'success': false, 'message': 'Server error (${res.statusCode}). Please try again in a moment.'};
    } on TimeoutException {
      return {'success': false, 'message': 'Server is taking too long to respond. Please try again.'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Pay for a ride online via Razorpay. Returns {success, message}.
  static Future<Map<String, dynamic>> payForRide({
    required String rideId,
    required double amount,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
  }) async {
    // 1. Create order
    final orderData = await _post('/payments/create-order', {'rideId': rideId, 'amount': amount});
    if (orderData['success'] != true) {
      return {'success': false, 'message': orderData['message'] ?? 'Failed to create order'};
    }
    final order = Map<String, dynamic>.from(orderData['order']);

    // 2. Open checkout
    final result = await openCheckout(
      order: order,
      name: 'Rydo',
      description: 'Ride payment',
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      themeColor: _themeColor,
    );
    if (!result.success) {
      return {'success': false, 'message': result.error ?? 'Payment cancelled'};
    }

    // 3. Verify
    final verifyData = await _post('/payments/verify-payment', {
      'razorpay_payment_id': result.paymentId,
      'razorpay_order_id': result.orderId,
      'razorpay_signature': result.signature,
      'rideId': rideId,
    });
    return {
      'success': verifyData['success'] == true,
      'message': verifyData['message'] ?? (verifyData['success'] == true ? 'Payment successful' : 'Verification failed'),
      'transactionId': verifyData['transactionId'],
    };
  }

  /// Recharge the wallet via Razorpay. Returns {success, message, walletBalance}.
  static Future<Map<String, dynamic>> rechargeWallet({
    required double amount,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
  }) async {
    // 1. Create wallet order
    final orderData = await _post('/payments/add-to-wallet', {'amount': amount});
    if (orderData['success'] != true) {
      return {'success': false, 'message': orderData['message'] ?? 'Failed to create order'};
    }
    final order = Map<String, dynamic>.from(orderData['order']);

    // 2. Open checkout
    final result = await openCheckout(
      order: order,
      name: 'Rydo Wallet',
      description: 'Wallet recharge',
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      themeColor: _themeColor,
    );
    if (!result.success) {
      return {'success': false, 'message': result.error ?? 'Payment cancelled'};
    }

    // 3. Verify wallet payment
    final verifyData = await _post('/payments/verify-wallet-payment', {
      'razorpay_payment_id': result.paymentId,
      'razorpay_order_id': result.orderId,
      'razorpay_signature': result.signature,
      'amount': amount,
    });
    return {
      'success': verifyData['success'] == true,
      'message': verifyData['message'] ?? (verifyData['success'] == true ? 'Wallet recharged' : 'Verification failed'),
      'walletBalance': verifyData['walletBalance'],
    };
  }
}
