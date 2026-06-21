import 'package:flutter/material.dart';

class InventoryEmptyState extends StatelessWidget {
  const InventoryEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 120),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
