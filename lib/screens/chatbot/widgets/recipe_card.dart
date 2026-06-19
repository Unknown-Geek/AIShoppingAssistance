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
          CartService().addItem(
            CartItemModel(
              id: sku,
              name: name,
              details: 'Recipe Ingredient: $reqQty',
              imageUrl: thumbnail,
              price: price,
              quantity: 1,
            ),
          );
        } else {
          missingItems.add(name);
        }
      }
    }

    final theme = Theme.of(context);
    final String message;
    if (addedItems.isEmpty && missingItems.isEmpty) {
      message = 'All ingredients are already in your cart!';
    } else if (addedItems.isNotEmpty && missingItems.isEmpty) {
      message = 'Added to cart: ${addedItems.join(', ')}';
    } else if (addedItems.isEmpty && missingItems.isNotEmpty) {
      message = 'Not in inventory: ${missingItems.join(', ')}';
    } else {
      message = 'Added: ${addedItems.join(', ')}\nNot in inventory: ${missingItems.join(', ')}';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'ClashGrotesk',
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 4),
      ),
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
    final instructions = List<String>.from(widget.recipe['instructions'] ?? []);

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
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
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
          // Horizontal Action Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildActionChip(
                  icon: _isExpanded ? Icons.expand_less_rounded : Icons.menu_book_rounded,
                  label: _isExpanded ? 'Hide Recipe' : 'View Recipe',
                  onTap: _toggleExpanded,
                ),
                const SizedBox(width: 8),
                _buildActionChip(
                  icon: Icons.add_shopping_cart_rounded,
                  label: 'Add to Cart',
                  onTap: () => _addIngredientsToCart(context),
                ),
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
