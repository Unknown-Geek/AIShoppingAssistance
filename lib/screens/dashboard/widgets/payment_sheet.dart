import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/payment_service.dart';

class PaymentSheet extends StatefulWidget {
  final double amount;
  final VoidCallback onPaymentSuccess;

  const PaymentSheet({
    super.key,
    required this.amount,
    required this.onPaymentSuccess,
  });

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> with SingleTickerProviderStateMixin {
  final PaymentService _paymentService = PaymentService();
  PaymentMethodType _selectedMethod = PaymentMethodType.card;

  // Form keys and controllers
  final _cardFormKey = GlobalKey<FormState>();
  final _upiFormKey = GlobalKey<FormState>();

  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _upiController = TextEditingController();

  // Focus nodes
  final _cardNumberFocus = FocusNode();
  final _expiryFocus = FocusNode();
  final _cvvFocus = FocusNode();
  final _upiFocus = FocusNode();

  // State flags
  bool _isProcessing = false;
  bool _isSuccess = false;
  bool _isError = false;
  String _statusMessage = '';
  String _transactionId = '';
  String? _errorMessage;

  // Real-time card display state
  String _cardNumberStr = '•••• •••• •••• ••••';
  String _expiryStr = 'MM/YY';
  String _cardHolderStr = '';

  @override
  void initState() {
    super.initState();
    final email = Supabase.instance.client.auth.currentUser?.email ?? 'GUEST USER';
    _cardHolderStr = email.split('@')[0].toUpperCase();
    _cardHolderController.text = _cardHolderStr;

    // Listeners to update card art in real-time
    _cardNumberController.addListener(() {
      setState(() {
        _cardNumberStr = _cardNumberController.text.isEmpty
            ? '•••• •••• •••• ••••'
            : _cardNumberController.text;
      });
    });

    _expiryController.addListener(() {
      setState(() {
        _expiryStr = _expiryController.text.isEmpty ? 'MM/YY' : _expiryController.text;
      });
    });


    _cardHolderController.addListener(() {
      setState(() {
        _cardHolderStr = _cardHolderController.text.isEmpty
            ? 'GUEST USER'
            : _cardHolderController.text.toUpperCase();
      });
    });
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardHolderController.dispose();
    _upiController.dispose();
    _cardNumberFocus.dispose();
    _expiryFocus.dispose();
    _cvvFocus.dispose();
    _upiFocus.dispose();
    super.dispose();
  }

  // Identify Card Type
  String _getCardType(String number) {
    final clean = number.replaceAll(' ', '');
    if (clean.startsWith('4')) return 'VISA';
    if (clean.startsWith('5')) return 'MASTERCARD';
    if (clean.startsWith('3')) return 'AMEX';
    return 'CARD';
  }

  Future<void> _handlePayment() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();

    if (_selectedMethod == PaymentMethodType.card) {
      if (!_cardFormKey.currentState!.validate()) return;
    } else if (_selectedMethod == PaymentMethodType.upi) {
      if (!_upiFormKey.currentState!.validate()) return;
    }

    setState(() {
      _isProcessing = true;
      _isSuccess = false;
      _isError = false;
      _errorMessage = null;
      _statusMessage = 'Initiating Secure Gateway Connection...';
    });

    // Simulate different loading phases for immersive visual feedback
    Timer(const Duration(milliseconds: 700), () {
      if (mounted && _isProcessing) {
        setState(() => _statusMessage = 'Encrypting Transaction Credentials...');
      }
    });

    Timer(const Duration(milliseconds: 1400), () {
      if (mounted && _isProcessing) {
        setState(() => _statusMessage = 'Requesting Bank Authorization...');
      }
    });

    Map<String, String> details = {};
    if (_selectedMethod == PaymentMethodType.card) {
      details = {
        'cardNumber': _cardNumberController.text,
        'expiry': _expiryController.text,
        'cvv': _cvvController.text,
      };
    } else if (_selectedMethod == PaymentMethodType.upi) {
      details = {
        'upiId': _upiController.text,
      };
    }

    try {
      final result = await _paymentService.processPayment(
        method: _selectedMethod,
        amount: widget.amount,
        details: details,
      );

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _isProcessing = false;
          _isSuccess = true;
          _transactionId = result.transactionId;
          _statusMessage = 'Payment Processed Successfully!';
        });

        // Fire success callback after showing the checkmark animation for a bit
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted) {
            widget.onPaymentSuccess();
            Navigator.pop(context);
          }
        });
      } else {
        setState(() {
          _isProcessing = false;
          _isError = true;
          _errorMessage = result.message;
          _statusMessage = 'Payment Transaction Declined';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isError = true;
          _errorMessage = 'An unexpected connection error occurred: $e';
          _statusMessage = 'Gateway Timeout';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _isProcessing
              ? _buildProcessingState(theme)
              : _isSuccess
                  ? _buildSuccessState(theme)
                  : _isError
                      ? _buildErrorState(theme)
                      : _buildFormState(theme, isDark),
        ),
      ),
    );
  }

  // ── 1. FORM STATE ────────────────────────────────────────────────────────
  Widget _buildFormState(ThemeData theme, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Payment Mode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Amount to charge: ₹${widget.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
        const SizedBox(height: 20),

        // Payment Method Options Tab Selector
        Row(
          children: [
            _buildTabButton(
              type: PaymentMethodType.card,
              icon: Icons.credit_card_rounded,
              label: 'Card',
              theme: theme,
            ),
            const SizedBox(width: 8),
            _buildTabButton(
              type: PaymentMethodType.upi,
              icon: Icons.account_balance_wallet_rounded,
              label: 'UPI',
              theme: theme,
            ),
            const SizedBox(width: 8),
            _buildTabButton(
              type: PaymentMethodType.googlePay,
              icon: Icons.payment_rounded,
              label: 'GPay',
              theme: theme,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Form Contents
        if (_selectedMethod == PaymentMethodType.card)
          _buildCardForm(theme)
        else if (_selectedMethod == PaymentMethodType.upi)
          _buildUpiForm(theme)
        else
          _buildGooglePayForm(theme),
      ],
    );
  }

  Widget _buildTabButton({
    required PaymentMethodType type,
    required IconData icon,
    required String label,
    required ThemeData theme,
  }) {
    final isSelected = _selectedMethod == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMethod = type;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primary.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── CARD FORM ────────────────────────────────────────────────────────────
  Widget _buildCardForm(ThemeData theme) {
    final cardType = _getCardType(_cardNumberStr);
    return Form(
      key: _cardFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sleek Interactive Credit Card Art
          AspectRatio(
            aspectRatio: 1.58,
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withRed(30).withBlue(50),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Gold Chip Simulation
                      Container(
                        width: 45,
                        height: 35,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF2D183), Color(0xFFC79E4A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      Text(
                        cardType,
                        style: TextStyle(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          fontSize: 16,
                          fontFamily: 'ClashDisplay',
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _cardNumberStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CARD HOLDER',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _cardHolderStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'EXPIRES',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _expiryStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Card Fields
          TextFormField(
            controller: _cardNumberController,
            focusNode: _cardNumberFocus,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: _getInputDecoration(theme, 'Card Number', Icons.credit_card),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
              TextInputFormatter.withFunction((oldValue, newValue) {
                final text = _paymentService.formatCardNumber(newValue.text);
                return TextEditingValue(
                  text: text,
                  selection: TextSelection.collapsed(offset: text.length),
                );
              }),
            ],
            validator: (val) {
              if (val == null || val.replaceAll(' ', '').length < 16) {
                return 'Please enter a valid 16-digit card number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _expiryController,
                  focusNode: _expiryFocus,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  decoration: _getInputDecoration(theme, 'Expiry (MM/YY)', Icons.calendar_month),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      final text = _paymentService.formatExpiry(newValue.text);
                      return TextEditingValue(
                        text: text,
                        selection: TextSelection.collapsed(offset: text.length),
                      );
                    }),
                  ],
                  validator: (val) {
                    if (val == null || !val.contains('/') || val.length != 5) {
                      return 'Use MM/YY';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _cvvController,
                  focusNode: _cvvFocus,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  decoration: _getInputDecoration(theme, 'CVV', Icons.lock),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  validator: (val) {
                    if (val == null || val.length < 3) {
                      return 'Enter 3-digit CVV';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cardHolderController,
            keyboardType: TextInputType.text,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: _getInputDecoration(theme, 'Cardholder Name', Icons.person),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Cardholder name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          _buildActionButton(theme, 'Pay ₹${widget.amount.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  // ── UPI FORM ─────────────────────────────────────────────────────────────
  Widget _buildUpiForm(ThemeData theme) {
    return Form(
      key: _upiFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'UPI Provider Apps',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          // Popular apps select grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildUpiAppLogo(theme, 'Google Pay', 'gpay@okaxis'),
              _buildUpiAppLogo(theme, 'PhonePe', 'user@ybl'),
              _buildUpiAppLogo(theme, 'Paytm', 'mobile@paytm'),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Or Enter UPI ID Manually',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _upiController,
            focusNode: _upiFocus,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: _getInputDecoration(theme, 'UPI ID (e.g. name@bank)', Icons.alternate_email_rounded),
            validator: (val) {
              if (val == null || !val.contains('@') || val.length < 5) {
                return 'Please enter a valid UPI VPA ID';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          _buildActionButton(theme, 'Pay ₹${widget.amount.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _buildUpiAppLogo(ThemeData theme, String name, String vpaPlaceholder) {
    final isSelected = _upiController.text == vpaPlaceholder;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _upiController.text = vpaPlaceholder;
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.secondary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? theme.colorScheme.secondary : theme.colorScheme.primary.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mobile_screen_share_rounded,
                size: 24,
                color: isSelected ? theme.colorScheme.secondary : theme.colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? theme.colorScheme.primary : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── GPAY FORM ────────────────────────────────────────────────────────────
  Widget _buildGooglePayForm(ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.payment_outlined, color: theme.colorScheme.secondary, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Google Pay',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pay securely using cards saved to your account',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 40),
        // Google Pay native styled button
        GestureDetector(
          onTap: _handlePayment,
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF000000), // GPay styling defaults to dark background
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Gpay logo text simulation
                const Text(
                  'G',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                Text(
                  'Pay',
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(width: 8),
                const VerticalDivider(
                  color: Colors.white30,
                  indent: 14,
                  endIndent: 14,
                  width: 1,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Pay with Card',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── SHARED WIDGET BUILDERS ───────────────────────────────────────────────
  InputDecoration _getInputDecoration(ThemeData theme, String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, size: 20, color: theme.colorScheme.primary.withValues(alpha: 0.7)),
      filled: true,
      fillColor: theme.colorScheme.primary.withValues(alpha: 0.02),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.1), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.1), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.secondary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.error, width: 1),
      ),
    );
  }

  Widget _buildActionButton(ThemeData theme, String text) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _handlePayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          elevation: 0,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }

  // ── 2. PROCESSING STATE ──────────────────────────────────────────────────
  Widget _buildProcessingState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular progress simulation with pulses
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please do not press back or close the application.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. SUCCESS STATE ─────────────────────────────────────────────────────
  Widget _buildSuccessState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Large Success Icon with green circle
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF10B981),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Order Confirmed!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF001A23),
              fontFamily: 'ClashDisplay',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transaction ID',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                ),
                Text(
                  _transactionId,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF001A23)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. ERROR STATE ───────────────────────────────────────────────────────
  Widget _buildErrorState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.error,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _statusMessage,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              fontFamily: 'ClashDisplay',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'Gateway error processing transaction credentials.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFE11D48),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isError = false;
                      _errorMessage = null;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
