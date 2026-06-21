import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/inventory_service.dart';
import '../../services/cart_service.dart';
import '../../models/cart_item_model.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _inventoryService = InventoryService();
  final _cartService = CartService();
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _products = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _products = List.from(_allProducts);
      } else {
        _products = _allProducts.where((product) {
          final name = product['name']?.toString().toLowerCase() ?? '';
          return name.contains(query);
        }).toList();
      }
    });
  }

  void _loadProducts() {
    setState(() {
      _allProducts = _inventoryService.getAllProducts();
      // Sort alphabetically by name
      _allProducts.sort((a, b) {
        final nameA = a['name']?.toString() ?? '';
        final nameB = b['name']?.toString() ?? '';
        return nameA.compareTo(nameB);
      });
      _products = List.from(_allProducts);
    });
  }

  void _addToCart(Map<String, dynamic> product) {
    final slug = product['slug']?.toString() ?? '';
    final name = product['name']?.toString() ?? 'Unknown Item';
    final price = (product['price_rupees'] as num?)?.toDouble() ?? 50.0;
    final imageUrl = _inventoryService.getImageUrl(slug);

    final item = CartItemModel(
      id: product['sku']?.toString() ?? 'sku_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      price: price,
      quantity: 1,
      details: 'Added from Store',
      imageUrl: imageUrl,
    );

    _cartService.addItem(item);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('$name added to cart!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Store Inventory',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: theme.colorScheme.primary),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFD2E4E6)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFD2E4E6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
                ),
              ),
            ),
          ),
          Expanded(
            child: _products.isEmpty
                ? Center(
                    child: Text(
                      'No products found.',
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      final slug = product['slug']?.toString() ?? '';
                      final name = product['name']?.toString() ?? 'Unknown Item';
                      final price = (product['price_rupees'] as num?)?.toDouble() ?? 0.0;
                      final imageUrl = _inventoryService.getImageUrl(slug);

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFD2E4E6)),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
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
                                          color: theme.colorScheme.primary.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Icon(
                                      Icons.image_outlined,
                                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '₹${price.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: theme.colorScheme.secondary,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => _addToCart(product),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.add_shopping_cart_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
