import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/cart_item_model.dart';
import '../../../services/cart_service.dart';

class MissingRegularsSheet extends StatefulWidget {
  final List<dynamic> missingItems;
  final VoidCallback onContinueToCheckout;

  const MissingRegularsSheet({
    super.key,
    required this.missingItems,
    required this.onContinueToCheckout,
  });

  @override
  State<MissingRegularsSheet> createState() => _MissingRegularsSheetState();
}

class _MissingRegularsSheetState extends State<MissingRegularsSheet> {
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    // Select all by default
    for (int i = 0; i < widget.missingItems.length; i++) {
      _selectedIndices.add(i);
    }
  }

  void _addSelectedItemsToCart() {
    final cartService = CartService();
    for (int i in _selectedIndices) {
      final item = widget.missingItems[i];
      if (item['sku'] != 'UNKNOWN' && item['sku'] != null) {
        final double price =
            (item['price'] as num?)?.toDouble() ??
            (item['price_rupees'] as num?)?.toDouble() ??
            0.0;
        CartItemModel missingItem = CartItemModel(
          id: item['sku'],
          name: item['name'] ?? 'Unknown Item',
          details: 'Suggested for you',
          imageUrl: item['thumbnail_url'] ?? item['image_url'] ?? '',
          price: price,
          quantity: 1,
        );
        cartService.addItem(missingItem);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Icon(
            Icons.auto_awesome,
            color: theme.colorScheme.secondary,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            'Did you forget something?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Based on your past orders, you usually buy these items.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF4A5568)),
          ),
          const SizedBox(height: 24),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: List.generate(widget.missingItems.length, (index) {
                  final item = widget.missingItems[index];
                  final name = item['name'] ?? 'Unknown Item';
                  final price =
                      (item['price'] as num?)?.toDouble() ??
                      (item['price_rupees'] as num?)?.toDouble() ??
                      0.0;
                  final avgGap = item['avg_gap_days'] ?? 0;
                  final imageUrl =
                      item['thumbnail_url'] ?? item['image_url'] ?? '';
                  final isSelected = _selectedIndices.contains(index);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedIndices.remove(index);
                        } else {
                          _selectedIndices.add(index);
                        }
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.secondary.withValues(
                                alpha: 0.05,
                              )
                            : Colors.white,
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.secondary
                              : const Color(0xFFE2E8F0),
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: const Color(0xFFF3F4F6),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const SizedBox(),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.image, size: 20),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Bought every $avgGap days',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF718096),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: isSelected
                                ? theme.colorScheme.secondary
                                : const Color(0xFFCBD5E0),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onContinueToCheckout();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: Color(0xFF4A5568),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    _addSelectedItemsToCart();
                    Navigator.pop(context);
                    widget.onContinueToCheckout();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Text(
                    _selectedIndices.isEmpty
                        ? 'Continue to Checkout'
                        : 'Add & Checkout',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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
