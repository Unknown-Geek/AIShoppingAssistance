import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/cart_item_model.dart';
import 'cart_service.dart';

class RecipeAgentService {
  List<String> get backendUrls {
    final urls = <String>[];
    
    // Add primary URL if configured
    final primary = dotenv.env['PRIMARY_DETECTION_URL']?.trim() ?? '';
    if (primary.isNotEmpty) urls.add(primary);
    
    // Add VM URL if configured
    final vm = dotenv.env['VM_DETECTION_URL']?.trim() ?? '';
    if (vm.isNotEmpty) urls.add(vm);
    
    // Add backup HF Space URL if configured
    final backup = dotenv.env['BACKUP_DETECTION_URL']?.trim() ?? '';
    if (backup.isNotEmpty) urls.add(backup);
    
    // Add HF Space URL if configured
    final hfSpace = dotenv.env['HF_SPACE_URL']?.trim() ?? '';
    if (hfSpace.isNotEmpty) urls.add(hfSpace);
    
    // Add fallback local URL
    urls.add('http://127.0.0.1:8000');
    
    // Clean URLs by removing sub-endpoints (e.g. /health, /detect, /embed)
    return urls.map((url) {
      var clean = url.replaceAll(RegExp(r'/health$'), '');
      clean = clean.replaceAll(RegExp(r'/detect$'), '');
      clean = clean.replaceAll(RegExp(r'/embed$'), '');
      clean = clean.replaceAll(RegExp(r'/recipe-agent$'), '');
      clean = clean.replaceAll(RegExp(r'/$'), '');
      return clean;
    }).where((url) => url.isNotEmpty).toList();
  }

  Future<Map<String, dynamic>> analyzeAndGetMissing(List<String> cartSlugs, String dish, int servings) async {
    final urls = backendUrls;
    List<String> errors = [];

    for (final url in urls) {
      try {
        debugPrint('[RecipeAgentService] Attempting request to backend: $url/recipe/analyze-ingredients');
        final response = await http.post(
          Uri.parse('$url/recipe/analyze-ingredients'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "current_cart_slugs": cartSlugs,
            "dish_query": dish,
            "servings": servings,
          }),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          debugPrint('[RecipeAgentService] Success using backend: $url');
          return jsonDecode(response.body);
        } else {
          final errorMsg = 'Server $url returned status code: ${response.statusCode}';
          debugPrint('[RecipeAgentService] $errorMsg');
          errors.add(errorMsg);
        }
      } catch (e) {
        final errorMsg = 'Failed to connect to $url: $e';
        debugPrint('[RecipeAgentService] $errorMsg');
        errors.add(errorMsg);
      }
    }

    throw Exception("Failed to process recipe orchestration layer. Errors: ${errors.join(', ')}");
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