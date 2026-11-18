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
  static const _themeColor = '#1976d2';

  static Future<Map<String, String>> _headers() async {
    final token = await StorageHelper.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
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
    final orderRes = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/payments/create-order'),
      headers: await _headers(),
      body: jsonEncode({'rideId': rideId, 'amount': amount}),
    );
    final orderData = jsonDecode(orderRes.body);
    if (orderData['success'] != true) {
      return {'success': false, 'message': orderData['message'] ?? 'Failed to create order'};
    }
    final order = Map<String, dynamic>.from(orderData['order']);

    // 2. Open checkout
    final result = await openCheckout(
      order: order,
      name: 'RYDO',
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
    final verifyRes = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/payments/verify-payment'),
      headers: await _headers(),
      body: jsonEncode({
        'razorpay_payment_id': result.paymentId,
        'razorpay_order_id': result.orderId,
        'razorpay_signature': result.signature,
        'rideId': rideId,
      }),
    );
    final verifyData = jsonDecode(verifyRes.body);
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
    final orderRes = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/payments/add-to-wallet'),
      headers: await _headers(),
      body: jsonEncode({'amount': amount}),
    );
    final orderData = jsonDecode(orderRes.body);
    if (orderData['success'] != true) {
      return {'success': false, 'message': orderData['message'] ?? 'Failed to create order'};
    }
    final order = Map<String, dynamic>.from(orderData['order']);

    // 2. Open checkout
    final result = await openCheckout(
      order: order,
      name: 'RYDO Wallet',
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
    final verifyRes = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/payments/verify-wallet-payment'),
      headers: await _headers(),
      body: jsonEncode({
        'razorpay_payment_id': result.paymentId,
        'razorpay_order_id': result.orderId,
        'razorpay_signature': result.signature,
        'amount': amount,
      }),
    );
    final verifyData = jsonDecode(verifyRes.body);
    return {
      'success': verifyData['success'] == true,
      'message': verifyData['message'] ?? (verifyData['success'] == true ? 'Wallet recharged' : 'Verification failed'),
      'walletBalance': verifyData['walletBalance'],
    };
  }
}
