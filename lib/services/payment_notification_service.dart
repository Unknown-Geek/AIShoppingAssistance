import 'dart:async';
import 'package:flutter/material.dart';

class PaymentNotificationService {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required bool success,
    required String message,
    String? transactionId,
  }) {
    // Dismiss any existing notification first
    dismiss();

    final overlayState = Overlay.of(context);
    
    _currentEntry = OverlayEntry(
      builder: (context) => PaymentNotificationOverlay(
        success: success,
        message: message,
        transactionId: transactionId,
        onDismiss: () {
          dismiss();
        },
      ),
    );

    overlayState.insert(_currentEntry!);
  }

  static void dismiss() {
    if (_currentEntry != null) {
      try {
        _currentEntry!.remove();
      } catch (_) {
        // Safe catch if already removed
      }
      _currentEntry = null;
    }
  }
}

class PaymentNotificationOverlay extends StatefulWidget {
  final bool success;
  final String message;
  final String? transactionId;
  final VoidCallback onDismiss;

  const PaymentNotificationOverlay({
    super.key,
    required this.success,
    required this.message,
    this.transactionId,
    required this.onDismiss,
  });

  @override
  State<PaymentNotificationOverlay> createState() => _PaymentNotificationOverlayState();
}

class _PaymentNotificationOverlayState extends State<PaymentNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();

    // Auto dismiss after 4 seconds
    Future.delayed(const Duration(milliseconds: 4000), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    if (mounted) {
      _controller.reverse().then((_) {
        widget.onDismiss();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;

    // Harmonious curated color palettes
    final Color primaryColor = widget.success
        ? theme.colorScheme.secondary // Qless mint green
        : const Color(0xFFEF4444); // Vibrant Red

    final List<Color> gradientColors = widget.success
        ? [const Color(0xFF001A23), const Color(0xFF002F3E)]
        : [const Color(0xFF450A0A), const Color(0xFF7F1D1D)];

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: SlideTransition(
            position: _offsetAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: width > 500 ? 460 : double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: (widget.success ? theme.colorScheme.primary : const Color(0xFFEF4444)).withValues(alpha: 0.2),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // Decorative glowing bubble background
                        Positioned(
                          right: -20,
                          top: -20,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primaryColor.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: primaryColor.withValues(alpha: 0.12),
                                ),
                                child: Icon(
                                  widget.success
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.error_outline_rounded,
                                  color: primaryColor,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.success ? 'Payment Successful' : 'Payment Failed',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'ClashDisplay',
                                        letterSpacing: 0.5,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            offset: const Offset(0, 2),
                                            blurRadius: 4,
                                          )
                                        ]
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.message,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 13,
                                        height: 1.3,
                                      ),
                                    ),
                                    if (widget.transactionId != null &&
                                        widget.transactionId!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Ref ID: ${widget.transactionId}',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _dismiss,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
