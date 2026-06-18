import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/cart_item_model.dart';
import 'cart_service.dart';

class RecipeAgentService {
  final String backendUrl = (() {
    final raw = (dotenv.env['PRIMARY_DETECTION_URL'] ??
                 dotenv.env['VM_DETECTION_URL'] ??
                 dotenv.env['BACKUP_DETECTION_URL'] ??
                 dotenv.env['HF_SPACE_URL'] ??
                 '').trim();
    if (raw.isEmpty) return 'http://127.0.0.1:8000';
    var clean = raw.replaceAll(RegExp(r'/health$'), '');
    clean = clean.replaceAll(RegExp(r'/detect$'), '');
    clean = clean.replaceAll(RegExp(r'/embed$'), '');
    clean = clean.replaceAll(RegExp(r'/recipe-agent$'), '');
    clean = clean.replaceAll(RegExp(r'/$'), '');
    return clean.isEmpty ? 'http://127.0.0.1:8000' : clean;
  })();

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
          id: 'recipe_${DateTime.now().millisecondsSinceEpoch}_${(item['slug'] ?? item['name'] ?? 'item').hashCode}',
          name: item['name'] ?? 'Unknown Item',
          details: 'SKU: ${item['sku'] ?? 'UNKNOWN'} • Price: ₹${(item['price_rupees'] ?? 0.0).toStringAsFixed(2)}',
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