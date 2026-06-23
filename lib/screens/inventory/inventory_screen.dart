import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import '../../services/cart_service.dart';
import '../../models/cart_item_model.dart';
import 'widgets/inventory_header_pill.dart';
import 'widgets/inventory_filter_bar.dart';
import 'widgets/product_grid_card.dart';
import 'widgets/inventory_empty_state.dart';
import '../dashboard/widgets/dashboard_sheets.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _inventoryService = InventoryService();
  final _cartService = CartService();

  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];

  String _selectedCategory = 'All';
  String _selectedSort = 'az';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Snacks',
    'Pantry',
    'Beverages',
    'Cereals',
    'Household',
  ];

  final Map<String, String> _sortOptions = {
    'az': 'Name (A-Z)',
    'za': 'Name (Z-A)',
    'priceLow': 'Price: Low to High',
    'priceHigh': 'Price: High to Low',
  };

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_onSearchOrFilterChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadProducts() {
    final products = _inventoryService.getAllProducts();
    setState(() {
      _allProducts = List.from(products);
      _applyFiltersAndSort();
    });
  }

  String _getProductCategory(Map<String, dynamic> product) {
    final slug = product['slug']?.toString().toLowerCase() ?? '';
    final name = product['name']?.toString().toLowerCase() ?? '';

    if (slug.contains('chips') ||
        slug.contains('kurkure') ||
        slug.contains('puffcorn') ||
        slug.contains('snickers') ||
        slug.contains('mars') ||
        slug.contains('chocolate') ||
        slug.contains('fuse') ||
        slug.contains('kitkat') ||
        slug.contains('milkybar') ||
        slug.contains('bar') ||
        name.contains('chocolate') ||
        name.contains('chips') ||
        name.contains('bar') ||
        name.contains('puffcorn')) {
      return 'Snacks';
    }
    if (slug.contains('oil') ||
        slug.contains('vinegar') ||
        slug.contains('paste') ||
        slug.contains('ketchup') ||
        slug.contains('sauce') ||
        slug.contains('noodles') ||
        slug.contains('maggi') ||
        slug.contains('geki') ||
        slug.contains('milk') ||
        name.contains('oil') ||
        name.contains('vinegar') ||
        name.contains('paste') ||
        name.contains('ketchup') ||
        name.contains('sauce') ||
        name.contains('noodles') ||
        name.contains('maggi') ||
        name.contains('milk')) {
      return 'Pantry';
    }
    if (slug.contains('bournvita') ||
        slug.contains('horlicks') ||
        slug.contains('boost') ||
        slug.contains('tea') ||
        slug.contains('water') ||
        slug.contains('drink') ||
        name.contains('tea') ||
        name.contains('drink') ||
        name.contains('boost') ||
        name.contains('horlicks') ||
        name.contains('bournvita')) {
      return 'Beverages';
    }
    if (slug.contains('ceregrow') ||
        slug.contains('cerelac') ||
        slug.contains('lactogen') ||
        slug.contains('similac') ||
        slug.contains('oats') ||
        slug.contains('muesli') ||
        slug.contains('flakes') ||
        slug.contains('chocos') ||
        name.contains('ceregrow') ||
        name.contains('cerelac') ||
        name.contains('lactogen') ||
        name.contains('similac') ||
        name.contains('oats') ||
        name.contains('muesli') ||
        name.contains('flakes') ||
        name.contains('chocos')) {
      return 'Cereals';
    }
    if (slug.contains('freshener') ||
        slug.contains('cleaner') ||
        slug.contains('lizol') ||
        slug.contains('harpic') ||
        slug.contains('room') ||
        slug.contains('odonil') ||
        slug.contains('aer') ||
        slug.contains('bottle') ||
        slug.contains('shampoo') ||
        name.contains('freshener') ||
        name.contains('cleaner') ||
        name.contains('lizol') ||
        name.contains('harpic') ||
        name.contains('spray') ||
        name.contains('odonil') ||
        name.contains('aer') ||
        name.contains('bottle') ||
        name.contains('shampoo')) {
      return 'Household';
    }
    return 'Pantry'; // Default fallback
  }

  void _onSearchOrFilterChanged() {
    setState(() {
      _applyFiltersAndSort();
    });
  }

  void _applyFiltersAndSort() {
    final query = _searchController.text.toLowerCase().trim();

    // 1. Filter
    List<Map<String, dynamic>> temp = _allProducts.where((product) {
      // Category match
      if (_selectedCategory != 'All') {
        final cat = _getProductCategory(product);
        if (cat != _selectedCategory) return false;
      }

      // Search query match
      if (query.isNotEmpty) {
        final name = product['name']?.toString().toLowerCase() ?? '';
        if (!name.contains(query)) return false;
      }

      return true;
    }).toList();

    // 2. Sort
    temp.sort((a, b) {
      final slugA = a['slug']?.toString() ?? '';
      final slugB = b['slug']?.toString() ?? '';
      final imageA = _inventoryService.getImageUrl(slugA);
      final imageB = _inventoryService.getImageUrl(slugB);
      final isPlaceholderA = imageA.contains('unsplash.com');
      final isPlaceholderB = imageB.contains('unsplash.com');

      if (isPlaceholderA && !isPlaceholderB) return 1;
      if (!isPlaceholderA && isPlaceholderB) return -1;

      final nameA = a['name']?.toString() ?? '';
      final nameB = b['name']?.toString() ?? '';
      final priceA = (a['price_rupees'] as num?)?.toDouble() ?? 0.0;
      final priceB = (b['price_rupees'] as num?)?.toDouble() ?? 0.0;

      switch (_selectedSort) {
        case 'az':
          return nameA.compareTo(nameB);
        case 'za':
          return nameB.compareTo(nameA);
        case 'priceLow':
          return priceA.compareTo(priceB);
        case 'priceHigh':
          return priceB.compareTo(priceA);
        default:
          return nameA.compareTo(nameB);
      }
    });

    _filteredProducts = temp;
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    final slug = product['slug']?.toString() ?? '';
    final name = product['name']?.toString() ?? 'Unknown Item';
    final price = (product['price_rupees'] as num?)?.toDouble() ?? 50.0;
    final imageUrl = _inventoryService.getImageUrl(slug);
    final pricesRaw = product['prices'];
    final prices = (pricesRaw as List?)
        ?.map((e) => (e as num).toDouble())
        .toList();

    CartItemModel item = CartItemModel(
      id:
          product['sku']?.toString() ??
          'sku_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      price: price,
      prices: prices,
      quantity: 1,
      details: 'Added from Store',
      imageUrl: imageUrl,
    );

    if (prices != null && prices.length > 1) {
      final confirmedItem = await DashboardSheets.showItemConfirmSheet(
        context,
        item: item,
      );
      if (confirmedItem == null) return;
      item = confirmedItem;
    }

    _cartService.addItem(item);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('${item.name} added to cart!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background soft visual decoration (radial gradients) matching profile/notifications
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.08),
                    theme.colorScheme.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.secondary.withValues(alpha: 0.12),
                    theme.colorScheme.secondary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Main Body
          SafeArea(
            child: Column(
              children: [
                InventoryHeaderPill(
                  onBackTap: () {
                    Navigator.of(context).pop();
                  },
                ),
                InventoryFilterBar(
                  searchController: _searchController,
                  selectedCategory: _selectedCategory,
                  onCategorySelected: (category) {
                    setState(() {
                      _selectedCategory = category;
                      _applyFiltersAndSort();
                    });
                  },
                  selectedSort: _selectedSort,
                  onSortSelected: (sortKey) {
                    setState(() {
                      _selectedSort = sortKey;
                      _applyFiltersAndSort();
                    });
                  },
                  categories: _categories,
                  sortOptions: _sortOptions,
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _filteredProducts.isEmpty
                      ? const SingleChildScrollView(
                          physics: BouncingScrollPhysics(),
                          child: InventoryEmptyState(),
                        )
                      : GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.68,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            final slug = product['slug']?.toString() ?? '';
                            final imageUrl = _inventoryService.getImageUrl(
                              slug,
                            );
                            final category = _getProductCategory(product);

                            return ProductGridCard(
                              product: product,
                              imageUrl: imageUrl,
                              category: category,
                              onAddToCart: () => _addToCart(product),
                            );
                          },
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
