// Web implementation of Razorpay checkout using Checkout.js via JS interop.
import 'dart:async';
import 'dart:js' as js;
import 'dart:js_util' as js_util;

/// Result of a checkout attempt.
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

/// Opens the Razorpay web checkout. [order] must contain id, amount, currency, key.
Future<CheckoutResult> openCheckout({
  required Map<String, dynamic> order,
  required String name,
  required String description,
  required String customerName,
  required String customerEmail,
  required String customerPhone,
  required String themeColor,
}) async {
  // Dev/test mode: backend returns a mock order id (order_test_...). Real
  // Checkout.js cannot process a fake order, so simulate a successful payment.
  final orderId = order['id']?.toString() ?? '';
  if (orderId.startsWith('order_test_')) {
    return CheckoutResult(
      success: true,
      paymentId: 'pay_test_${DateTime.now().millisecondsSinceEpoch}',
      orderId: orderId,
      signature: 'test_signature',
    );
  }

  final completer = Completer<CheckoutResult>();

  // Success handler invoked by Razorpay Checkout.js
  final handler = js.allowInterop((response) {
    try {
      final paymentId = js_util.getProperty(response, 'razorpay_payment_id')?.toString();
      final orderId = js_util.getProperty(response, 'razorpay_order_id')?.toString();
      final signature = js_util.getProperty(response, 'razorpay_signature')?.toString();
      if (!completer.isCompleted) {
        completer.complete(CheckoutResult(
          success: true,
          paymentId: paymentId,
          orderId: orderId,
          signature: signature,
        ));
      }
    } catch (e) {
      if (!completer.isCompleted) {
        completer.complete(CheckoutResult(success: false, error: e.toString()));
      }
    }
  });

  final options = js_util.jsify({
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
  });

  // Attach the success handler
  js_util.setProperty(options, 'handler', handler);

  // modal.ondismiss -> user closed without paying
  final modal = js_util.jsify({});
  js_util.setProperty(modal, 'ondismiss', js.allowInterop(() {
    if (!completer.isCompleted) {
      completer.complete(CheckoutResult(success: false, error: 'Payment cancelled'));
    }
  }));
  js_util.setProperty(options, 'modal', modal);

  try {
    final razorpay = js_util.getProperty(js.context, 'Razorpay');
    if (razorpay == null) {
      return CheckoutResult(success: false, error: 'Razorpay Checkout.js not loaded');
    }
    final rzp = js_util.callConstructor(razorpay, [options]);

    // Handle explicit payment failures
    js_util.callMethod(rzp, 'on', [
      'payment.failed',
      js.allowInterop((response) {
        if (!completer.isCompleted) {
          String? msg;
          try {
            final err = js_util.getProperty(response, 'error');
            msg = js_util.getProperty(err, 'description')?.toString();
          } catch (_) {}
          completer.complete(CheckoutResult(success: false, error: msg ?? 'Payment failed'));
        }
      }),
    ]);

    js_util.callMethod(rzp, 'open', []);
  } catch (e) {
    return CheckoutResult(success: false, error: e.toString());
  }

  return completer.future;
}
