// Mobile (Android/iOS) implementation of Razorpay checkout using razorpay_flutter.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class CheckoutResult {
  final bool success;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? error;

  CheckoutResult({
    required this.success,
    this.paymentId,
    this.orderId,
    this.signature,
    this.error,
  });
}

Future<CheckoutResult> openCheckout({
  required Map<String, dynamic> order,
  required String name,
  required String description,
  required String customerName,
  required String customerEmail,
  required String customerPhone,
  required String themeColor,
}) async {
  // Dev/test mode: backend returns a mock order id (order_test_...). The native
  // SDK cannot process a fake order, so simulate a successful payment.
  final orderId = order['id']?.toString() ?? '';
  if (orderId.startsWith('order_test_')) {
    return CheckoutResult(
      success: true,
      paymentId: 'pay_test_${DateTime.now().millisecondsSinceEpoch}',
      orderId: orderId,
      signature: 'test_signature',
    );
  }

  // razorpay_flutter only supports Android and iOS. On Windows/macOS/Linux its
  // open() fails silently in the background and the payment would hang forever.
  if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
    return CheckoutResult(
      success: false,
      error: 'Razorpay payments work only on Android, iOS or web. '
          'Run the app on a phone/emulator (or Chrome) to recharge.',
    );
  }

  final completer = Completer<CheckoutResult>();
  final razorpay = Razorpay();

  void cleanup() => razorpay.clear();

  razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse resp) {
    if (!completer.isCompleted) {
      completer.complete(CheckoutResult(
        success: true,
        paymentId: resp.paymentId,
        orderId: resp.orderId,
        signature: resp.signature,
      ));
    }
    cleanup();
  });

  razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse resp) {
    if (!completer.isCompleted) {
      completer.complete(CheckoutResult(success: false, error: resp.message ?? 'Payment failed'));
    }
    cleanup();
  });

  razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse resp) {
    // External wallet selected; treat as pending/cancel for our flow.
    if (!completer.isCompleted) {
      completer.complete(CheckoutResult(success: false, error: 'External wallet: ${resp.walletName}'));
    }
    cleanup();
  });

  final options = {
    'key': order['key'],
    'amount': order['amount'],
    'currency': order['currency'] ?? 'INR',
    'name': name,
    'description': description,
    'order_id': order['id'],
    'prefill': {
      'name': customerName,
      'email': customerEmail,
      'contact': customerPhone,
    },
    'theme': {'color': themeColor},
  };

  try {
    razorpay.open(options);
  } catch (e) {
    if (!completer.isCompleted) {
      completer.complete(CheckoutResult(success: false, error: e.toString()));
    }
    cleanup();
  }

  return completer.future;
}
