import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isExpanded;
  final VoidCallback onTap;

  const OrderCard({
    super.key,
    required this.order,
    required this.isExpanded,
    required this.onTap,
  });

  String _formatOrderDate(dynamic createdAt) {
    if (createdAt == null) return 'Unknown date';
    try {
      DateTime dt;
      if (createdAt is String) {
        dt = DateTime.parse(createdAt).toLocal();
      } else if (createdAt is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(createdAt).toLocal();
      } else {
        return createdAt.toString();
      }

      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];

      final monthStr = months[dt.month - 1];
      final day = dt.day;

      int hour = dt.hour;
      final ampm = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;

      final minuteStr = dt.minute.toString().padLeft(2, '0');

      return '$monthStr $day, $hour:$minuteStr $ampm';
    } catch (_) {
      return createdAt.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = (order['items'] as List<dynamic>? ?? []);
    final status = order['status']?.toString() ?? '';
    final isSuccess = status.toLowerCase() == 'processed';
    final totalPrice = (order['total_price'] as num?)?.toDouble() ?? 0.0;

    final createdAt =
        order['vreated_at'] ?? order['created_at'] ?? order['createdAt'];
    final formattedDate = _formatOrderDate(createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD2E4E6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Qless Store',
                          style: TextStyle(
                            fontFamily: theme.textTheme.titleMedium?.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 0),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                            fontSize: 10,
                            fontWeight: FontWeight.normal,
                            letterSpacing: 0.6,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isSuccess ? 'Success' : 'Failure',
                          style: TextStyle(
                            fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSuccess
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isSuccess
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: isSuccess
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Animated Size Container for items content
                ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isExpanded) ...[
                          // Expanded state: show all items with prices
                          ...items.map((item) {
                            final itemMap = item as Map<String, dynamic>;
                            final name =
                                itemMap['name']?.toString() ?? 'Unknown item';
                            final qty =
                                itemMap['quantity'] ?? itemMap['qty'] ?? 1;
                            final price =
                                (itemMap['price'] as num?)?.toDouble() ??
                                (itemMap['unit_price'] as num?)?.toDouble() ??
                                0.0;
                            final lineTotal =
                                (qty is num ? qty.toDouble() : 1.0) * price;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        // Quantity badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3F4F6),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            '${qty}x',
                                            style: TextStyle(
                                              fontFamily: theme
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.fontFamily,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF4B5563),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        // Item Name
                                        Expanded(
                                          child: Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily: theme
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.fontFamily,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: theme.colorScheme.primary
                                                  .withValues(alpha: 0.8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '₹${lineTotal.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontFamily: theme
                                          .textTheme
                                          .bodyMedium
                                          ?.fontFamily,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ] else ...[
                          // Collapsed state: show first 2 items
                          ...items.take(2).map((item) {
                            final itemMap = item as Map<String, dynamic>;
                            final name =
                                itemMap['name']?.toString() ?? 'Unknown item';
                            final qty =
                                itemMap['quantity'] ?? itemMap['qty'] ?? 1;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  // Quantity badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      '${qty}x',
                                      style: TextStyle(
                                        fontFamily: theme
                                            .textTheme
                                            .bodyMedium
                                            ?.fontFamily,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF4B5563),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Item Name
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: theme
                                            .textTheme
                                            .bodyMedium
                                            ?.fontFamily,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (items.length > 2)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '& ${items.length - 2} more',
                                style: TextStyle(
                                  fontFamily:
                                      theme.textTheme.bodyMedium?.fontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.6,
                                  ),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 12),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final txnId = order['id']?.toString() ?? '';
                          if (txnId.isNotEmpty) {
                            Clipboard.setData(ClipboardData(text: txnId));
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Transaction ID copied to clipboard!',
                                ),
                                backgroundColor: theme.colorScheme.primary,
                                behavior: SnackBarBehavior.fixed,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: Text(
                          'ID: ${order['id']?.toString() ?? ''}',
                          style: TextStyle(
                            fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey.shade500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '₹${totalPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontFamily: theme.textTheme.titleMedium?.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
