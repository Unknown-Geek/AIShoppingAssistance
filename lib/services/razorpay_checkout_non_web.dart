import 'dart:async';
import 'payment_service.dart';

Future<PaymentResult> startRazorpayCheckoutPlatform({
  required PaymentService service,
  required double amount,
  required String email,
  required String appName,
  String? contact,
}) {
  return service.startRazorpayCheckoutMobile(
    amount: amount,
    email: email,
    appName: appName,
    contact: contact,
  );
}
