import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'cart_service.dart';
import '../models/cart_item_model.dart';

class RecipeAgentService {
  final String backendUrl = dotenv.env['PRIMARY_DETECTION_URL'] ?? 'http://127.0.0.1:8000';

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
          id: item['sku'] ?? '',
          name: item['name'] ?? '',
          details: 'Recipe Ingredient',
          imageUrl: item['thumbnail_url'] ?? '',
          price: (item['price_rupees'] as num?)?.toDouble() ?? 0.0,
          quantity: 1, // Add default increment unit
        );
        
        // This triggers your immediate SharedPreferences update + async background Supabase sync
        cartService.addItem(missingItem);
      }
    }
  }
}