import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'payment_service.dart';

@JS('Razorpay')
extension type RazorpayJS._(JSObject _) implements JSObject {
  external RazorpayJS(JSObject options);
  external void open();
}

Future<PaymentResult> startRazorpayCheckoutPlatform({
  required PaymentService service,
  required double amount,
  required String email,
  required String appName,
  String? contact,
}) {
  final completer = Completer<PaymentResult>();
  final keyId = dotenv.env['RAZORPAY_KEY_ID']?.trim() ?? 'rzp_test_mockKey123';

  final handler = ((JSObject response) {
    final paymentId =
        response['razorpay_payment_id']?.toString() ??
        'RZP-${DateTime.now().millisecondsSinceEpoch}';
    completer.complete(
      PaymentResult(
        success: true,
        transactionId: paymentId,
        message:
            'Payment of ₹${amount.toStringAsFixed(2)} completed via Razorpay Web.',
      ),
    );
  }).toJS;

  final onDismiss = (() {
    completer.complete(
      PaymentResult(
        success: false,
        transactionId: '',
        message: 'Razorpay Web Checkout dismissed by user.',
      ),
    );
  }).toJS;

  final options =
      {
            'key': keyId,
            'amount': (amount * 100).toInt(), // in paise
            'currency': 'INR',
            'name': appName.isNotEmpty ? appName : 'Qless',
            'description': 'Shopping Cart Checkout',
            'prefill': {
              'contact': (contact != null && contact.trim().isNotEmpty)
                  ? contact.trim()
                  : '9999999999',
              'email': email.trim().isNotEmpty
                  ? email.trim()
                  : 'guest@example.com',
              'name': email.trim().isNotEmpty
                  ? email.trim().split('@')[0]
                  : 'Guest User',
            },
            'theme': {'color': '#001A23'},
            'handler': handler,
            'modal': {'ondismiss': onDismiss},
          }.jsify()
          as JSObject;

  try {
    final rzp = RazorpayJS(options);
    rzp.open();
  } catch (e) {
    completer.complete(
      PaymentResult(
        success: false,
        transactionId: '',
        message: 'Failed to initialize Razorpay Web JS SDK: $e',
      ),
    );
  }

  return completer.future;
}
