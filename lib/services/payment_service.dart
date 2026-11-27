import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import '../utils/storage_helper.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  late Razorpay _razorpay;

  void initialize() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void dispose() {
    _razorpay.clear();
  }

  // Create payment order for ride
  Future<Map<String, dynamic>?> createRidePaymentOrder({
    required String rideId,
    required double amount,
  }) async {
    try {
      final token = await StorageHelper.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/payments/create-order'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'rideId': rideId,
          'amount': amount,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return data['order'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error creating payment order: $e');
      return null;
    }
  }

  // Create wallet recharge order
  Future<Map<String, dynamic>?> createWalletRechargeOrder({
    required double amount,
  }) async {
    try {
      final token = await StorageHelper.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/payments/add-to-wallet'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': amount,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return data['order'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error creating wallet recharge order: $e');
      return null;
    }
  }

  // Start payment process
  void startPayment({
    required Map<String, dynamic> orderData,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    String? description,
  }) {
    var options = {
      'key': orderData['key'],
      'amount': orderData['amount'],
      'currency': orderData['currency'],
      'name': 'Rydo',
      'description': description ?? 'Payment for Rydo service',
      'order_id': orderData['id'],
      'prefill': {
        'contact': customerPhone,
        'email': customerEmail,
        'name': customerName,
      },
      'theme': {
        'color': '#FFC107',
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
    }
  }

  // Verify ride payment
  Future<bool> verifyRidePayment({
    required String paymentId,
    required String orderId,
    required String signature,
    required String rideId,
  }) async {
    try {
      final token = await StorageHelper.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/payments/verify-payment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'razorpay_payment_id': paymentId,
          'razorpay_order_id': orderId,
          'razorpay_signature': signature,
          'rideId': rideId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Error verifying payment: $e');
      return false;
    }
  }

  // Verify wallet payment
  Future<Map<String, dynamic>?> verifyWalletPayment({
    required String paymentId,
    required String orderId,
    required String signature,
    required double amount,
  }) async {
    try {
      final token = await StorageHelper.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/payments/verify-wallet-payment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'razorpay_payment_id': paymentId,
          'razorpay_order_id': orderId,
          'razorpay_signature': signature,
          'amount': amount,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return {
            'success': true,
            'walletBalance': data['walletBalance'],
            'message': data['message'],
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error verifying wallet payment: $e');
      return null;
    }
  }

  // Pay from wallet
  Future<Map<String, dynamic>?> payFromWallet({
    required String rideId,
    required double amount,
  }) async {
    try {
      final token = await StorageHelper.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/payments/pay-from-wallet'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'rideId': rideId,
          'amount': amount,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return {
            'success': true,
            'walletBalance': data['walletBalance'],
            'transactionId': data['transactionId'],
            'message': data['message'],
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error paying from wallet: $e');
      return null;
    }
  }

  // Get wallet balance
  Future<double> getWalletBalance() async {
    try {
      final token = await StorageHelper.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/payments/wallet-balance'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return (data['balance'] ?? 0).toDouble();
        }
      }
      return 0.0;
    } catch (e) {
      debugPrint('Error getting wallet balance: $e');
      return 0.0;
    }
  }

  // Get payment history
  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    try {
      final token = await StorageHelper.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/payments/history'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return List<Map<String, dynamic>>.from(data['payments'] ?? []);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting payment history: $e');
      return [];
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    // This will be handled by the calling widget
      debugPrint('Payment Success: ${response.paymentId}');
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    // This will be handled by the calling widget
      debugPrint('Payment Error: ${response.code} - ${response.message}');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // Handle external wallet
      debugPrint('External Wallet: ${response.walletName}');
  }
}
