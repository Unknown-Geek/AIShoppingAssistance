import 'package:flutter/material.dart';

class InventoryFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final String selectedSort;
  final ValueChanged<String> onSortSelected;
  final List<String> categories;
  final Map<String, String> sortOptions;

  const InventoryFilterBar({
    super.key,
    required this.searchController,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.selectedSort,
    required this.onSortSelected,
    required this.categories,
    required this.sortOptions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search + Sort Row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.02,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: searchController,
                    style: TextStyle(
                      fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                      fontSize: 14,
                      color: theme.colorScheme.primary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      hintStyle: TextStyle(
                        fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: 14,
                      ),

                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.6,
                                ),
                                size: 18,
                              ),
                              onPressed: () {
                                searchController.clear();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: Color(0xFFD2E4E6),
                          width: 1.2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: Color(0xFFD2E4E6),
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: theme.colorScheme.secondary,
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Sort PopupMenuButton
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD2E4E6),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.swap_vert_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                  tooltip: 'Sort products',
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFD2E4E6), width: 1),
                  ),
                  color: Colors.white,
                  onSelected: onSortSelected,
                  itemBuilder: (BuildContext context) {
                    return sortOptions.entries.map((entry) {
                      final isSelected = selectedSort == entry.key;
                      return PopupMenuItem<String>(
                        value: entry.key,
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.grey,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              entry.value,
                              style: TextStyle(
                                fontFamily:
                                    theme.textTheme.bodyMedium?.fontFamily,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Category chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: categories.map((category) {
                  final isSelected = selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: GestureDetector(
                      onTap: () => onCategorySelected(category),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : const Color(0xFFD2E4E6),
                            width: 1.2,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.15,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                          ],
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                            fontSize: 12,
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
            ),
          ),
        ],
      ),
    );
  }
}
