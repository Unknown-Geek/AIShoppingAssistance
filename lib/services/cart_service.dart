import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cart_item_model.dart';


/// Singleton cart service that acts as the session-scoped cart database.
/// Persists cart state across page refreshes via SharedPreferences and syncs
/// with Supabase for logged-in users.
class CartService extends ChangeNotifier {
  static final CartService instance = CartService();
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;

  final _supabase = Supabase.instance.client;

  CartService._internal() {
    // Listen for auth state changes to load/clear user cart reactively
    _supabase.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      if (user != null) {
        _loadActiveCartFromSupabase(user.id);
      } else {
        _items.clear();
        _persist();
        _loadedUserId = null;
        notifyListeners();
      }
    });
  }

  static const String _cartKey = 'cart_items_v1';

  final List<CartItemModel> _items = [];
  bool _isLoaded = false;
  Timer? _syncTimer;
  Future<void>? _activeLoadFuture;
  String? _loadedUserId;

  void _scheduleSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 500), () {
      _syncActiveCart();
    });
  }

  /// Read-only view of the cart contents.
  List<CartItemModel> get items => List.unmodifiable(_items);

  /// Total item count (sum of quantities).
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  /// Total price in Rupees (₹).
  double get totalPrice =>
      _items.fold(0.0, (sum, item) => sum + item.price * item.quantity);

  bool get isEmpty => _items.isEmpty;

  bool get isLoaded => _isLoaded;

  // ─────────────────────────── Persistence ───────────────────────────────────

  /// Loads cart from SharedPreferences. Call once during app init.
  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_cartKey);
      if (raw != null) {
        final List<dynamic> decoded = jsonDecode(raw);
        _items.clear();
        _items.addAll(decoded.map((e) => CartItemModel.fromJson(e)));
      }

      // If already logged in on startup, sync the latest active cart from Supabase
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _loadActiveCartFromSupabase(user.id);
      }
    } catch (e) {
      debugPrint('[CartService] load error: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  final String _agentBaseUrl = "http://localhost:8000";

Future<Map<String, dynamic>?> analyzeAndInjectRecipeIngredients({
    required String dishQuery,
    required int servings,
  }) async {
    // 1. Resolve identity gracefully
    final currentUserId = _supabase.auth.currentUser?.id ?? "anonymous_user";
    final url = Uri.parse("$_agentBaseUrl/recipe/analyze-ingredients/");

    try {
      debugPrint("📡 [ARCHITECT BRIDGE] Dispatching agent payload for user: $currentUserId");
      
      final List<String> currentSlugs = _items.map((e) => e.name.toLowerCase().replaceAll(' ', '-')).toList();

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": currentUserId,
          "dish_query": dishQuery,
          "servings": servings,
          "current_cart_slugs": currentSlugs,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> additions = data['cart_additions'] ?? [];

        debugPrint("📥 [ARCHITECT BRIDGE] Agent returned ${additions.length} items to inject.");

        // 2. Core Write-Through Phase
        for (var addition in additions) {
          final String itemName = addition['name'] ?? 'Unknown Item';
          final double itemPrice = (addition['price'] as num).toDouble();
          final int itemQty = addition['quantity'] ?? 1;

          final existingIdx = _items.indexWhere((e) => e.name == itemName);
          if (existingIdx != -1) {
            _items[existingIdx].quantity += itemQty;
          } else {
            _items.add(
              CartItemModel(
                id: addition['sku'] ?? 'unknown_sku_${DateTime.now().millisecondsSinceEpoch}',
                name: itemName,
                price: itemPrice,
                quantity: itemQty,
                details: "Injected via AI Agent Analysis",
                imageUrl: "",
              ),
            );
          }
        }

        // 3. Absolute Persistence Enforcement
        await _persist();
        
        // 4. Force background synchronization to Supabase if session exists
        if (_supabase.auth.currentUser != null) {
          await _syncActiveCart();
        }

        // 5. Broadcast critical state alteration to redraw every UI element bound to this provider
        notifyListeners();
        return data;

      } else {
        debugPrint('❌ [ARCHITECT BRIDGE FLIGHT ERROR]: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('🚨 [ARCHITECT BRIDGE CRITICAL EXCEPTION]: $e');
      return null;
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cartKey,
        jsonEncode(_items.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[CartService] persist error: $e');
    }
  }

  // ────────────────────────── Supabase Syncing ────────────────────────────────

  /// Restoration method to fetch active cart from Supabase on login or app start.
  Future<void> _loadActiveCartFromSupabase(String userId) async {
    if (_loadedUserId == userId) return;
    if (_activeLoadFuture != null) {
      await _activeLoadFuture;
      return;
    }

    final completer = Completer<void>();
    _activeLoadFuture = completer.future;

    try {
      final activeCart = await _supabase
          .from('user_carts')
          .select('items')
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();

      if (activeCart != null && activeCart['items'] != null) {
        final List<dynamic> dbItems = activeCart['items'] as List<dynamic>;
        _items.clear();
        _items.addAll(dbItems.map((e) => CartItemModel.fromJson(e as Map<String, dynamic>)));
        _persist();
        _loadedUserId = userId;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[CartService] Error loading active cart from Supabase: $e');
    } finally {
      _activeLoadFuture = null;
      completer.complete();
    }
  }

  /// Pushes changes to Supabase in the background whenever the cart is modified.
  Future<void> _syncActiveCart() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final activeCart = await _supabase
          .from('user_carts')
          .select('id')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .maybeSingle();

      if (activeCart != null) {
        await _supabase
            .from('user_carts')
            .update({
              'items': _items.map((e) => e.toJson()).toList(),
              'total_price': totalPrice,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', activeCart['id']);
      } else {
        // Only create active cart record if there are items to store
        if (_items.isNotEmpty) {
          await _supabase
              .from('user_carts')
              .insert({
                'user_id': user.id,
                'items': _items.map((e) => e.toJson()).toList(),
                'total_price': totalPrice,
                'status': 'active',
              });
        }
      }
    } catch (e) {
      debugPrint('[CartService] Supabase active cart sync error: $e');
    }
  }

  // ─────────────────────────── CRUD ──────────────────────────────────────────

  void removeItemBySkuOrName(String sku, String name) {
    final index = _items.indexWhere((e) => e.id == sku || e.name == name);
    if (index != -1) {
      removeItem(index);
    }
  }

  void removeOrDecrementItemBySkuOrName(String sku, String name, int quantity) {
    final index = _items.indexWhere((e) => e.id == sku || e.name == name);
    if (index != -1) {
      final currentQty = _items[index].quantity;
      if (currentQty > quantity) {
        for (int i = 0; i < quantity; i++) {
          decrementQuantity(index);
        }
      } else {
        removeItem(index);
      }
    }
  }

  /// Adds [item] to the cart. If an item with the same [name] already exists,
  /// its quantity is incremented instead of adding a duplicate.
  void addItem(CartItemModel item) {
    final existingIdx = _items.indexWhere((e) => e.name == item.name);
    if (existingIdx != -1) {
      _items[existingIdx].quantity += item.quantity;
    } else {
      _items.add(item);
    }
    _persist();
    _scheduleSync();
    notifyListeners();
  }

  void incrementQuantity(int index) {
    if (index < 0 || index >= _items.length) return;
    _items[index].quantity++;
    _persist();
    _scheduleSync();
    notifyListeners();
  }

  void decrementQuantity(int index) {
    if (index < 0 || index >= _items.length) return;
    if (_items[index].quantity > 1) {
      _items[index].quantity--;
      _persist();
      _scheduleSync();
    } else {
      removeItem(index);
    }
    notifyListeners();
  }

  void removeItem(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    _persist();
    // If the cart becomes empty, delete the active cart from Supabase
    final user = _supabase.auth.currentUser;
    if (user != null && _items.isEmpty) {
      _syncTimer?.cancel(); // Cancel any pending sync if we are deleting the cart
      _supabase
          .from('user_carts')
          .delete()
          .eq('user_id', user.id)
          .eq('status', 'active')
          .then((_) => null, onError: (e) => debugPrint('[CartService] Error deleting active cart: $e'));
    } else {
      _scheduleSync();
    }
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _persist();
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _syncTimer?.cancel();
      _supabase
          .from('user_carts')
          .delete()
          .eq('user_id', user.id)
          .eq('status', 'active')
          .then((_) => null, onError: (e) => debugPrint('[CartService] Error deleting active cart: $e'));
    }
    notifyListeners();
  }

  // ─────────────────────────── Checkout ──────────────────────────────────────

  /// Completes the checkout: marks the active cart as processed in Supabase,
  /// clears the in-memory cart, and wipes local storage.
  Future<void> checkout() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final activeCart = await _supabase
            .from('user_carts')
            .select('id')
            .eq('user_id', user.id)
            .eq('status', 'active')
            .maybeSingle();

        if (activeCart != null) {
          // Progress state to 'processed'
          await _supabase
              .from('user_carts')
              .update({
                'status': 'processed',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', activeCart['id']);
        } else if (_items.isNotEmpty) {
          // If no active cart exists in DB but we have local items, write direct processed entry
          await _supabase
              .from('user_carts')
              .insert({
                'user_id': user.id,
                'items': _items.map((e) => e.toJson()).toList(),
                'total_price': totalPrice,
                'status': 'processed',
              });
        }
      } catch (e) {
        debugPrint('[CartService] Supabase checkout sync error: $e');
      }
    }

    _items.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cartKey);
    } catch (e) {
      debugPrint('[CartService] checkout clear error: $e');
    }
    notifyListeners();
  }
}
