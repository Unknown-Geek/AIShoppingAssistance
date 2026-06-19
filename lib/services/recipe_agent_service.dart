import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cart_item_model.dart';
import '../models/chatbot_models.dart';
import 'cart_service.dart';

class RecipeAgentService {
  /// Resolves the active user's ID from Supabase auth.
  /// Falls back to "anonymous_user" when no session is present.
  String get _resolvedUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? 'anonymous_user';

  // Getter for backendUrl used by other methods like fetchAgentCart
  String get backendUrl {
    final urls = backendUrls;
    return urls.isNotEmpty ? urls.first : 'http://127.0.0.1:8000';
  }

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

  Future<Map<String, dynamic>> analyzeAndGetMissing(
    List<String> cartSlugs,
    List<Map<String, dynamic>> currentCart,
    String dish,
    int servings,
    List<ChatMessage> chatHistory,
  ) async {
    final urls = backendUrls;
    List<String> errors = [];

    final historyList = chatHistory.map((m) {
      return {
        "is_user": m.isUser,
        "text": m.text ?? "",
      };
    }).toList();

    for (final url in urls) {
      try {
        debugPrint('[RecipeAgentService] Attempting request to backend: $url/recipe/analyze-ingredients');
        final response = await http.post(
          Uri.parse('$url/recipe/analyze-ingredients'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "user_id": _resolvedUserId, // Preserved from abhinav's branch
            "current_cart_slugs": cartSlugs,
            "dish_query": dish,
            "servings": servings,
            "chat_history": historyList,
            "current_cart": currentCart,
          }),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          if (data.containsKey('error') && data['error'] != null) {
            final errorMsg = 'Server $url returned application error: ${data['error']}';
            debugPrint('[RecipeAgentService] $errorMsg');
            errors.add(errorMsg);
          } else {
            debugPrint('[RecipeAgentService] Success using backend: $url');
            return data;
          }
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
        // Instantiate using your model mappings
        CartItemModel missingItem = CartItemModel(
          id: 'recipe_${DateTime.now().millisecondsSinceEpoch}_${(item['slug'] ?? item['name'] ?? 'item').hashCode}',
          name: item['name'] ?? 'Unknown Item',
          details: 'SKU: ${item['sku'] ?? 'UNKNOWN'} • Price: ₹${(item['price_rupees'] ?? 0.0).toStringAsFixed(2)}',
          imageUrl: item['thumbnail_url'] ?? '',
          price: (item['price_rupees'] as num?)?.toDouble() ?? 0.0,
          quantity: 1, // Add default increment unit
        );
        cartService.addItem(missingItem);
      }
    }
  }
}