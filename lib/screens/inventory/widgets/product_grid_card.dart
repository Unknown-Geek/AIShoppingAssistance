import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/inventory_service.dart';

class ProductGridCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final String imageUrl;
  final String category;
  final ValueChanged<double> onAddToCart;

  const ProductGridCard({
    super.key,
    required this.product,
    required this.imageUrl,
    required this.category,
    required this.onAddToCart,
  });

  @override
  State<ProductGridCard> createState() => _ProductGridCardState();
}

class _ProductGridCardState extends State<ProductGridCard> {
  double? _selectedPrice;

  @override
  void initState() {
    super.initState();
    _initSelectedPrice();
  }

  @override
  void didUpdateWidget(ProductGridCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.product['sku'] != oldWidget.product['sku']) {
      _initSelectedPrice();
    }
  }

  void _initSelectedPrice() {
    final pricesRaw = widget.product['prices'];
    final prices = (pricesRaw as List?)
        ?.map((e) => (e as num).toDouble())
        .toList();
    if (prices != null && prices.isNotEmpty) {
      prices.sort();
      _selectedPrice = prices.first; // Keep lowest size/price selected by default
    } else {
      _selectedPrice = (widget.product['price_rupees'] as num?)?.toDouble() ?? 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = widget.product['name']?.toString() ?? 'Unknown Item';
    final price = (widget.product['price_rupees'] as num?)?.toDouble() ?? 0.0;
    final slug = widget.product['slug']?.toString() ?? '';

    final pricesRaw = widget.product['prices'];
    final prices = (pricesRaw as List?)
        ?.map((e) => (e as num).toDouble())
        .toList();

    if (prices != null && prices.length > 1) {
      prices.sort();
    }

    final String catKey = widget.category.trim().toLowerCase();
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

    Widget variantsWidget;
    if (prices != null && prices.length > 1) {
      variantsWidget = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        child: Row(
          children: prices.map((p) {
            final sizeStr = InventoryService.getSizeForProduct(
              name: name,
              slug: slug,
              price: p,
            );
            final isSelected = _selectedPrice == p;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPrice = p;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : const Color(0xFFD2E4E6),
                      width: 1.0,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Text(
                    sizeStr,
                    style: TextStyle(
                      fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.primary.withValues(
                              alpha: 0.8,
                            ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    } else {
      final singlePrice = _selectedPrice ?? price;
      final sizeStr = InventoryService.getSizeForProduct(
        name: name,
        slug: slug,
        price: singlePrice,
      );
      variantsWidget = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFD2E4E6),
            width: 1.0,
          ),
        ),
        child: Text(
          sizeStr,
          style: TextStyle(
            fontFamily: theme.textTheme.bodyMedium?.fontFamily,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.primary.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Area
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.30,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: widget.imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.image_outlined,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.2,
                            ),
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Category Label Overlay
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: badgeText.withValues(alpha: 0.15),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        widget.category.toUpperCase(),
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
              // Product Info Section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.primary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      variantsWidget,
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '₹${(_selectedPrice ?? price).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontFamily:
                                  theme.textTheme.titleMedium?.fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => widget.onAddToCart(_selectedPrice ?? price),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
