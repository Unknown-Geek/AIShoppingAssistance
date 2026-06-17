import 'package:flutter/material.dart';

class RecipeCard extends StatelessWidget {
  final Map<String, dynamic> recipe;

  const RecipeCard({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ingredients = List<Map<String, dynamic>>.from(recipe['ingredients'] ?? []);
    final instructions = List<String>.from(recipe['instructions'] ?? []);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD2E4E6)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipe['dish'] ?? 'Recipe',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Servings: ${recipe['servings'] ?? ''}',
            style: TextStyle(
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Ingredients',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          ...ingredients.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 6, color: theme.colorScheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${item['quantity'] ?? ''} ${item['name'] ?? ''}',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Instructions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            ...instructions.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '${entry.key + 1}. ${entry.value}',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
