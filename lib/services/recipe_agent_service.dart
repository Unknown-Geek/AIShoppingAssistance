import 'import_declarations.dart'; // Add your standard package paths

class RecipeAgentService {
  final String backendUrl = Config.backendUrl; // References your config setup

  Future<Map<String, dynamic>> analyzeAndGetMissing(List<String> cartSlugs, String dish, int servings) async {
    final response = await http.post(
      Uri.parse('$backendUrl/recipe/analyze-ingredients'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "current_cart_slugs": cartSlugs,
        "dish_query": dish,
        "servings": servings,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to process recipe orchestration layer");
    }
  }

  // Primary Goal: Add missing items seamlessly back into the workflow
  void addMissingIngredientsToCart(List<dynamic> missingIngredients, CartService cartService) {
    for (var item in missingIngredients) {
      if (item['sku'] != 'UNKNOWN') {
        // Instantiate using your model mappings
        CartItemModel missingItem = CartItemModel(
          sku: item['sku'],
          slug: item['slug'],
          name: item['name'],
          priceRupees: item['price_rupees'].toDouble(),
          thumbnailUrl: item['thumbnail_url'],
          quantity: 1, // Add default increment unit
        );
        
        // This triggers your immediate SharedPreferences update + async background Supabase sync
        cartService.addItemToCart(missingItem);
      }
    }
  }
}