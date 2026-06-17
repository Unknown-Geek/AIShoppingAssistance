import 'dart:async';

enum PaymentGatewayProvider { stripe, razorpay }

enum PaymentMethodType { card, upi, googlePay }

class PaymentResult {
  final bool success;
  final String transactionId;
  final String message;

  PaymentResult({
    required this.success,
    required this.transactionId,
    required this.message,
  });
}

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;

  PaymentService._internal();

  /// Simulates payment processing with realistic API latency and validation.
  /// This can be easily replaced by Stripe's SDK (Stripe.instance.confirmPayment)
  /// or Razorpay's checkout options.
  Future<PaymentResult> processPayment({
    required PaymentMethodType method,
    required double amount,
    Map<String, String>? details,
  }) async {
    // Simulate network latency
    await Future.delayed(const Duration(milliseconds: 2200));

    final txId = 'TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    switch (method) {
      case PaymentMethodType.card:
        final cardNumber = details?['cardNumber'] ?? '';
        final expiry = details?['expiry'] ?? '';
        final cvv = details?['cvv'] ?? '';

        // Basic credit card validation rules
        if (cardNumber.replaceAll(' ', '').length < 16) {
          return PaymentResult(
            success: false,
            transactionId: '',
            message: 'Invalid card number format. Must be 16 digits.',
          );
        }
        if (!expiry.contains('/') || expiry.length != 5) {
          return PaymentResult(
            success: false,
            transactionId: '',
            message: 'Invalid expiry format (MM/YY).',
          );
        }
        if (cvv.length < 3) {
          return PaymentResult(
            success: false,
            transactionId: '',
            message: 'Invalid CVV code.',
          );
        }

        // Simulating credit card declines (e.g. testing with specific CVV)
        if (cvv == '000' || cvv == '999') {
          return PaymentResult(
            success: false,
            transactionId: txId,
            message: 'Payment declined: Insufficient funds or card restricted.',
          );
        }

        return PaymentResult(
          success: true,
          transactionId: txId,
          message: 'Payment of ₹${amount.toStringAsFixed(2)} successful via Credit Card.',
        );

      case PaymentMethodType.upi:
        final upiId = details?['upiId'] ?? '';
        if (!upiId.contains('@') || upiId.length < 5) {
          return PaymentResult(
            success: false,
            transactionId: '',
            message: 'Invalid UPI ID format (e.g. user@bank).',
          );
        }

        if (upiId.startsWith('fail')) {
          return PaymentResult(
            success: false,
            transactionId: txId,
            message: 'UPI transaction request timed out or was rejected by user.',
          );
        }

        return PaymentResult(
          success: true,
          transactionId: txId,
          message: 'Payment of ₹${amount.toStringAsFixed(2)} successful via UPI ($upiId).',
        );

      case PaymentMethodType.googlePay:
        // GPay tokenization is direct and biometric validated on-device
        return PaymentResult(
          success: true,
          transactionId: txId,
          message: 'Payment of ₹${amount.toStringAsFixed(2)} successful via Google Pay.',
        );
    }
  }

  /// Utility to format card numbers with spaces every 4 digits
  String formatCardNumber(String value) {
    var text = value.replaceAll(' ', '');
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(' ');
      }
    }
    return buffer.toString();
  }

  /// Utility to format expiry date as MM/YY
  String formatExpiry(String value) {
    var text = value.replaceAll('/', '');
    if (text.length > 2) {
      return '${text.substring(0, 2)}/${text.substring(2)}';
    }
    return text;
  }
}
