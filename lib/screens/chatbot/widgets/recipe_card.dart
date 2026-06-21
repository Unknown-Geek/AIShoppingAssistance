import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/cart_item_model.dart';
import '../../../services/cart_service.dart';

class RecipeCard extends StatefulWidget {
  final Map<String, dynamic> recipe;

  const RecipeCard({super.key, required this.recipe});

  @override
  State<RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<RecipeCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool get _enableSubstitutes => false;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _addIngredientsToCart(BuildContext context) {
    final missingIngredients = List<dynamic>.from(widget.recipe['missing_ingredients'] ?? []);
    final addedItems = <String>[];
    final missingItems = <String>[];

    for (final item in missingIngredients) {
      if (item is Map) {
        final sku = item['sku'] as String? ?? 'UNKNOWN';
        final name = item['name'] as String? ?? '';
        final price = (item['price_rupees'] as num?)?.toDouble() ?? 0.0;
        final thumbnail = item['thumbnail_url'] as String? ?? '';
        final reqQty = item['required_quantity'] as String? ?? '1';

        if (sku != 'UNKNOWN') {
          addedItems.add(name);
          final int quantity = (item['quantity'] as num?)?.toInt() ?? 1;
          CartService().addItem(
            CartItemModel(
              id: sku,
              name: name,
              details: 'Recipe Ingredient: $reqQty',
              imageUrl: thumbnail,
              price: price,
              quantity: quantity,
            ),
          );
        } else {
          missingItems.add(name);
        }
      }
    }

    _showCartAddedSheet(context, addedItems: addedItems, missingItems: missingItems);
  }

  void _showCartAddedSheet(
    BuildContext context, {
    required List<String> addedItems,
    required List<String> missingItems,
  }) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header row with icon
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.shopping_cart_checkout_rounded,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        addedItems.isEmpty ? 'Cart Update' : 'Added to Cart 🛒',
                        style: TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        '${addedItems.length} item${addedItems.length == 1 ? '' : 's'} from this recipe',
                        style: TextStyle(
                          fontFamily: 'ClashGrotesk',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.primary.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (addedItems.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFD2E4E6),
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: addedItems.map((name) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 14,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontFamily: 'ClashGrotesk',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              if (missingItems.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.15),
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Not in inventory:',
                        style: TextStyle(
                          fontFamily: 'ClashGrotesk',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...missingItems.map((name) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.remove_circle_outline_rounded,
                                size: 13,
                                color: Colors.redAccent.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontFamily: 'ClashGrotesk',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
              if (addedItems.isEmpty && missingItems.isEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'All ingredients are already in your cart! ✅',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: const Text(
                    'Got it!',
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _shareRecipe(BuildContext context) {
    final dish = widget.recipe['dish'] ?? 'Recipe';
    final servings = widget.recipe['servings'] ?? 2;
    final readyTime = widget.recipe['ready_time'] ?? '20 min';
    final summary = widget.recipe['summary'] ?? 'A delicious dish crafted by your AI Chef.';
    final ingredients = List<Map<String, dynamic>>.from(widget.recipe['ingredients'] ?? []);
    final instructions = List<String>.from(widget.recipe['instructions'] ?? []);

    final buffer = StringBuffer();
    buffer.writeln('🍳 Recipe: $dish');
    buffer.writeln('Servings: $servings | Ready in: $readyTime');
    buffer.writeln();
    buffer.writeln('Summary:');
    buffer.writeln(summary);
    buffer.writeln();

    if (ingredients.isNotEmpty) {
      buffer.writeln('🛒 Ingredients:');
      for (final item in ingredients) {
        final name = item['name'] ?? '';
        final quantity = item['quantity'] ?? '';
        if (quantity.isNotEmpty) {
          buffer.writeln('• $quantity $name');
        } else {
          buffer.writeln('• $name');
        }
      }
      buffer.writeln();
    }

    if (instructions.isNotEmpty) {
      buffer.writeln('📖 Instructions:');
      for (int i = 0; i < instructions.length; i++) {
        buffer.writeln('${i + 1}. ${instructions[i]}');
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString().trim()));

    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Copied complete recipe to clipboard!',
          style: TextStyle(fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w500),
        ),
        backgroundColor: theme.colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dishName = widget.recipe['dish'] ?? 'Recipe';
    final servings = widget.recipe['servings'] ?? 2;
    final readyTime = widget.recipe['ready_time'] ?? '20 min';
    final summary = widget.recipe['summary'] ?? 'A delicious dish crafted by your AI Chef.';
    final ingredients = List<Map<String, dynamic>>.from(widget.recipe['ingredients'] ?? []);
    final instructions = List<String>.from(
      widget.recipe['instructions'] ?? widget.recipe['recipe_instructions'] ?? [],
    );
    final missingIngredients = List<dynamic>.from(widget.recipe['missing_ingredients'] ?? []);
    final hasAnyAvailable = missingIngredients.any((item) => item is Map && item['sku'] != 'UNKNOWN');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0xFFD2E4E6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            dishName,
            style: TextStyle(
              fontFamily: 'ClashDisplay',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          // Ready In
          Text(
            'Ready in $readyTime • Serves $servings',
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          // Summary
          Text(
            summary,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
          // Expandable Ingredients & Instructions
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: _isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFD2E4E6), height: 1),
                      const SizedBox(height: 18),
                      // Ingredients Header
                      Text(
                        'Ingredients',
                        style: TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...ingredients.map((item) {
                        final rawName = item['name'] ?? '';
                        
                        // Find this ingredient in missing_ingredients to check for substitutes
                        final missingIngredients = List<dynamic>.from(widget.recipe['missing_ingredients'] ?? []);
                        Map<String, dynamic>? matchingMissing;
                        for (final m in missingIngredients) {
                          if (m is Map && (m['name'] as String).toLowerCase() == rawName.toLowerCase()) {
                            matchingMissing = Map<String, dynamic>.from(m);
                            break;
                          }
                        }
                        
                        // If no direct name match, try substring matching
                        if (matchingMissing == null) {
                          for (final m in missingIngredients) {
                            if (m is Map) {
                              final mName = (m['name'] as String).toLowerCase();
                              final rName = rawName.toLowerCase();
                              if (mName.contains(rName) || rName.contains(mName)) {
                                matchingMissing = Map<String, dynamic>.from(m);
                                break;
                              }
                            }
                          }
                        }

                        final hasSubstitutes = _enableSubstitutes &&
                            matchingMissing != null &&
                            matchingMissing['sku'] == 'UNKNOWN' &&
                            matchingMissing['substitutes'] != null &&
                            (matchingMissing['substitutes'] as List).isNotEmpty;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 6),
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: theme.colorScheme.secondary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${item['quantity'] ?? ''} ${item['name'] ?? ''}',
                                      style: TextStyle(
                                        fontFamily: 'ClashGrotesk',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (matchingMissing != null && matchingMissing['sku'] == 'UNKNOWN' && !hasSubstitutes) ...[
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.only(left: 18),
                                  child: Text(
                                    'Not in inventory',
                                    style: TextStyle(
                                      fontFamily: 'ClashGrotesk',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.redAccent.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                              ],
                              if (hasSubstitutes) ...[
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.only(left: 18),
                                  child: Text(
                                    'Not in inventory. Substitutes:',
                                    style: TextStyle(
                                      fontFamily: 'ClashGrotesk',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.redAccent.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.only(left: 18),
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: List<dynamic>.from(matchingMissing['substitutes']).map((sub) {
                                      final subMap = Map<String, dynamic>.from(sub);
                                      final sSku = subMap['sku'] ?? '';
                                      final sName = subMap['name'] ?? '';
                                      final sPrice = (subMap['price_rupees'] as num?)?.toDouble() ?? 0.0;
                                      final sImage = subMap['thumbnail_url'] ?? '';

                                      return InkWell(
                                        onTap: () {
                                          CartService().addItem(
                                            CartItemModel(
                                              id: sSku,
                                              name: sName,
                                              details: 'Substitute for $rawName',
                                              imageUrl: sImage,
                                              price: sPrice,
                                              quantity: 1,
                                            ),
                                          );
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Added substitute: $sName to cart!',
                                                style: const TextStyle(
                                                  fontFamily: 'ClashGrotesk',
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              backgroundColor: theme.colorScheme.primary,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: const Color(0xFFD2E4E6), width: 1.0),
                                          ),
                                          child: Text.rich(
                                            TextSpan(
                                              children: [
                                                WidgetSpan(
                                                  alignment: PlaceholderAlignment.middle,
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(right: 4),
                                                    child: Icon(
                                                      Icons.add_shopping_cart_rounded,
                                                      size: 12,
                                                      color: theme.colorScheme.secondary,
                                                    ),
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: '$sName - ₹${sPrice.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    fontFamily: 'ClashGrotesk',
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: theme.colorScheme.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      if (instructions.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Instructions',
                          style: TextStyle(
                            fontFamily: 'ClashDisplay',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...instructions.asMap().entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry.key + 1}.',
                                  style: TextStyle(
                                    fontFamily: 'ClashDisplay',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: TextStyle(
                                      fontFamily: 'ClashGrotesk',
                                      fontSize: 14,
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          // Horizontal scrollable action row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildActionChip(
                  icon: _isExpanded ? Icons.expand_less_rounded : Icons.menu_book_rounded,
                  label: _isExpanded ? 'Hide Recipe' : 'View Recipe',
                  onTap: _toggleExpanded,
                ),
                if (hasAnyAvailable) ...[
                  const SizedBox(width: 8),
                  _buildActionChip(
                    icon: Icons.add_shopping_cart_rounded,
                    label: 'Add to Cart',
                    onTap: () => _addIngredientsToCart(context),
                  ),
                ],
                const SizedBox(width: 8),
                _buildActionChip(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: () => _shareRecipe(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD2E4E6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
