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
    final ingredients = List<Map<String, dynamic>>.from(widget.recipe['ingredients'] ?? []);
    if (ingredients.isEmpty) return;

    for (final item in ingredients) {
      final name = item['name'] ?? '';
      final quantity = item['quantity'] ?? '1';

      CartService().addItem(
        CartItemModel(
          id: 'recipe_${widget.recipe['dish']}_${name.hashCode}',
          name: name,
          details: 'Recipe Ingredient: $quantity',
          imageUrl: '', // default fallback
          price: 50.0,  // fallback mockup price
          quantity: 1,
        ),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added ${ingredients.length} ingredients to your cart!',
          style: const TextStyle(fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w500),
        ),
        backgroundColor: const Color(0xFF001A23),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _shareRecipe(BuildContext context) {
    final dish = widget.recipe['dish'] ?? 'Recipe';
    Clipboard.setData(ClipboardData(text: 'Check out this recipe: $dish!'));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied recipe link for "$dish" to clipboard!',
          style: const TextStyle(fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w500),
        ),
        backgroundColor: const Color(0xFF001A23),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            color: const Color(0xFF001A23).withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rating Row
          Row(
            children: List.generate(5, (index) {
              return const Icon(
                Icons.star_rounded,
                color: Color(0xFFFFB300), // Gold Star
                size: 20,
              );
            }),
          ),
          const SizedBox(height: 10),
          // Title
          Text(
            dishName,
            style: const TextStyle(
              fontFamily: 'ClashDisplay',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF001A23),
            ),
          ),
          const SizedBox(height: 6),
          // Ready In
          Text(
            'Ready in $readyTime • Serves $servings',
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF001A23).withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          // Summary
          Text(
            summary,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF001A23).withValues(alpha: 0.8),
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
                      const Text(
                        'Ingredients',
                        style: TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF001A23),
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
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFB3EFB2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${item['quantity'] ?? ''} ${item['name'] ?? ''}',
                                  style: const TextStyle(
                                    fontFamily: 'ClashGrotesk',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF001A23),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (instructions.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Instructions',
                          style: TextStyle(
                            fontFamily: 'ClashDisplay',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF001A23),
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
                                  style: const TextStyle(
                                    fontFamily: 'ClashDisplay',
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF001A23),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: const TextStyle(
                                      fontFamily: 'ClashGrotesk',
                                      fontSize: 15,
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF001A23),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFD2E4E6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF001A23).withValues(alpha: 0.02),
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
              size: 18,
              color: const Color(0xFF2E7D32), // green accent
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF001A23),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
