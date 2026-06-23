import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'razorpay_checkout_non_web.dart'
    if (dart.library.js_interop) 'razorpay_checkout_web.dart'
    as rzp;

enum PaymentMethodType { card, upi, googlePay, razorpay }

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

  Razorpay? _razorpay;
  Completer<PaymentResult>? _razorpayCompleter;
  double? _razorpayAmount;

  PaymentService._internal();

  void _initRazorpayIfNeeded() {
    if (!kIsWeb && _razorpay == null) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (_razorpayCompleter != null && !_razorpayCompleter!.isCompleted) {
      final amountStr = _razorpayAmount != null
          ? ' ₹${_razorpayAmount!.toStringAsFixed(2)}'
          : '';
      _razorpayCompleter!.complete(
        PaymentResult(
          success: true,
          transactionId:
              response.paymentId ??
              'RZP-${DateTime.now().millisecondsSinceEpoch}',
          message: 'Payment of$amountStr processed via Razorpay SDK.',
        ),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (_razorpayCompleter != null && !_razorpayCompleter!.isCompleted) {
      _razorpayCompleter!.complete(
        PaymentResult(
          success: false,
          transactionId: '',
          message: response.message ?? 'Payment cancelled or declined.',
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (_razorpayCompleter != null && !_razorpayCompleter!.isCompleted) {
      _razorpayCompleter!.complete(
        PaymentResult(
          success: true,
          transactionId: 'RZP-WALLET-${response.walletName}',
          message:
              'Payment via external wallet ${response.walletName} selected.',
        ),
      );
    }
  }

  /// Launches Razorpay Checkout.
  /// Uses JS SDK for Web platform and native SDK for Mobile (Android/iOS).
  Future<PaymentResult> startRazorpayCheckout({
    required double amount,
    required String email,
    required String appName,
    String? contact,
  }) {
    return rzp.startRazorpayCheckoutPlatform(
      service: this,
      amount: amount,
      email: email,
      appName: appName,
      contact: contact,
    );
  }

  Future<PaymentResult> startRazorpayCheckoutMobile({
    required double amount,
    required String email,
    required String appName,
    String? contact,
  }) {
    // Native Mobile SDK Flow
    _initRazorpayIfNeeded();
    _razorpayCompleter = Completer<PaymentResult>();
    _razorpayAmount = amount;

    final keyId =
        dotenv.env['RAZORPAY_KEY_ID']?.trim() ?? 'rzp_test_mockKey123';

    final options = {
      'key': keyId,
      'amount': (amount * 100).toInt(),
      'currency': 'INR',
      'name': appName.isNotEmpty ? appName : 'Qless',
      'description': 'Shopping Cart Checkout',
      'prefill': {
        'contact': (contact != null && contact.trim().isNotEmpty)
            ? contact.trim()
            : '9999999999',
        'email': email.trim().isNotEmpty ? email.trim() : 'guest@example.com',
        'name': email.trim().isNotEmpty
            ? email.trim().split('@')[0]
            : 'Guest User',
      },
      'theme': {'color': '#001A23'},
      'timeout': 300,
    };

    try {
      _razorpay!.open(options);
    } catch (e) {
      if (_razorpayCompleter != null && !_razorpayCompleter!.isCompleted) {
        _razorpayCompleter!.complete(
          PaymentResult(
            success: false,
            transactionId: '',
            message:
                'Failed to launch Razorpay SDK: $e. Make sure you are testing on Android/iOS.',
          ),
        );
      }
    }

    return _razorpayCompleter!.future;
  }

  /// Simulates payment processing with realistic API latency and validation.
  /// Used as a fallback simulator for local desktop development where web/mobile SDKs are unavailable.
  Future<PaymentResult> processSimulation({
    required PaymentMethodType method,
    required double amount,
    Map<String, String>? details,
  }) async {
    await Future.delayed(const Duration(milliseconds: 2200));

    final txId =
        'SIM-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    switch (method) {
      case PaymentMethodType.card:
        final cardNumber = details?['cardNumber'] ?? '';
        final expiry = details?['expiry'] ?? '';
        final cvv = details?['cvv'] ?? '';

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
          message:
              'Payment of ₹${amount.toStringAsFixed(2)} successful via Card Simulator.',
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
            message: 'UPI transaction request timed out or was rejected.',
          );
        }

        return PaymentResult(
          success: true,
          transactionId: txId,
          message:
              'Payment of ₹${amount.toStringAsFixed(2)} successful via UPI Simulator ($upiId).',
        );

      case PaymentMethodType.googlePay:
        return PaymentResult(
          success: true,
          transactionId: txId,
          message:
              'Payment of ₹${amount.toStringAsFixed(2)} successful via Google Pay Simulator.',
        );
      case PaymentMethodType.razorpay:
        return PaymentResult(
          success: true,
          transactionId: txId,
          message:
              'Payment of ₹${amount.toStringAsFixed(2)} successful via Razorpay Simulator.',
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
