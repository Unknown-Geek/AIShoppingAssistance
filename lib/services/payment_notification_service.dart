import 'package:flutter/material.dart';

class PaymentNotificationService {
  static void show(
    BuildContext context, {
    required bool success,
    required String message,
    String? transactionId,
  }) {
    final theme = Theme.of(context);
    
    // Clear any active SnackBars
    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    success ? 'Payment Success' : 'Payment Failed',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  static void dismiss() {
    // No-op since snackbars dismiss themselves
  }
}
