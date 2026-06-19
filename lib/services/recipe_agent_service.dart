import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cart_service.dart';
import '../models/cart_item_model.dart';

class RecipeAgentService {
  final String backendUrl =
      dotenv.env['PRIMARY_DETECTION_URL'] ?? 'http://127.0.0.1:8000';

  /// Resolves the active user's ID from Supabase auth.
  /// Falls back to "anonymous_user" when no session is present.
  String get _resolvedUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? 'anonymous_user';

  /// Sends the dish + cart context to the recipe agent pipeline.
  ///
  /// Returns the full agent response including [recipe_instructions],
  /// [parsed_ingredients], [missing_ingredients], and [cart_additions].
  ///
  /// [user_id] is resolved internally from Supabase auth so callers do not
  /// need to supply it — keeping the method signature stable.
  Future<Map<String, dynamic>> analyzeAndGetMissing(
    List<String> cartSlugs,
    String dish,
    int servings,
  ) async {
    final response = await http.post(
      Uri.parse('$backendUrl/recipe/analyze-ingredients'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': _resolvedUserId, // Fix: was missing, caused 422 Unprocessable Entity
        'current_cart_slugs': cartSlugs,
        'dish_query': dish,
        'servings': servings,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Recipe agent pipeline failed: ${response.statusCode} — ${response.body}',
      );
    }
  }

  /// Fetches the agent-committed cart state from the backend in-memory store.
  ///
  /// The agent's [add_to_cart] tool writes SKUs to a process-scoped memory
  /// store on the backend. This endpoint lets Flutter reconcile any items the
  /// agent committed that were not returned in [cart_additions] (e.g. after a
  /// server restart). Returns an empty list on failure — non-fatal.
  Future<List<Map<String, dynamic>>> fetchAgentCart() async {
    final userId = _resolvedUserId;
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/recipe/cart/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];
        return items.cast<Map<String, dynamic>>();
      } else {
        return [];
      }
    } catch (_) {
      // Non-fatal: backend may be unavailable; local cart state is authoritative.
      return [];
    }
  }

  /// Injects matched missing ingredients into [cartService].
  ///
  /// Only items with a known SKU (not "UNKNOWN") are added. Each triggers an
  /// immediate SharedPreferences write + a debounced Supabase background sync
  /// via [CartService.addItem].
  void addMissingIngredientsToCart(
    List<dynamic> missingIngredients,
    CartService cartService,
  ) {
    for (final item in missingIngredients) {
      if (item['sku'] != 'UNKNOWN') {
        final missingItem = CartItemModel(
          id: item['sku'] as String? ?? '',
          name: item['name'] as String? ?? '',
          details: 'Recipe Ingredient',
          imageUrl: item['thumbnail_url'] as String? ?? '',
          price: (item['price_rupees'] as num?)?.toDouble() ?? 0.0,
          quantity: 1,
        );
        cartService.addItem(missingItem);
      }
    }
  }
}