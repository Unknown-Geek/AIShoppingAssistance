import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductGridCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final String imageUrl;
  final String category;
  final VoidCallback onAddToCart;

  const ProductGridCard({
    super.key,
    required this.product,
    required this.imageUrl,
    required this.category,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = product['name']?.toString() ?? 'Unknown Item';
    final price = (product['price_rupees'] as num?)?.toDouble() ?? 0.0;

    final String catKey = category.trim().toLowerCase();
    Color badgeBg;
    Color badgeText;

    if (catKey == 'snacks') {
      badgeBg = const Color(0xFFFFF2D4);
      badgeText = const Color(0xFF8A5D00);
    } else if (catKey == 'pantry') {
      badgeBg = const Color(0xFFE2F9E1);
      badgeText = const Color(0xFF1D5C20);
    } else if (catKey == 'beverages') {
      badgeBg = const Color(0xFFE0F2FE);
      badgeText = const Color(0xFF0369A1);
    } else if (catKey == 'cereals') {
      badgeBg = const Color(0xFFF3E8FF);
      badgeText = const Color(0xFF6B21A8);
    } else if (catKey == 'household') {
      badgeBg = const Color(0xFFFFE4E6);
      badgeText = const Color(0xFFBE123C);
    } else {
      badgeBg = theme.colorScheme.secondary.withValues(alpha: 0.15);
      badgeText = theme.colorScheme.primary;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD2E4E6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Area
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Icon(
                        Icons.image_outlined,
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        size: 32,
                      ),
                    ),
                  ),
                ),
                // Category Label Overlay
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: badgeText.withValues(alpha: 0.15), width: 0.5),
                    ),
                    child: Text(
                      category.toUpperCase(),
                      style: TextStyle(
                        fontFamily: theme.textTheme.labelSmall?.fontFamily,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: badgeText,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Product Info Section
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      GestureDetector(
                        onTap: onAddToCart,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
