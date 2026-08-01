import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gourmet_go/models/food_item.dart';
import 'package:gourmet_go/models/extra_item.dart';
import 'package:gourmet_go/models/cart_item.dart';

/// Singleton [ChangeNotifier] that manages the shopping cart and persists
/// it to [SharedPreferences] so the cart survives app restarts.
///
/// Usage:
/// ```dart
/// // Once at app startup, before runApp():
/// await CartManager().loadCart();
///
/// // Anywhere:
/// CartManager().addItem(...);
/// ```
class CartManager extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final CartManager _instance = CartManager._internal();
  factory CartManager() => _instance;
  CartManager._internal();

  // ── Storage key ───────────────────────────────────────────────────────────
  static const String _kCartKey = 'gourmet_go_cart_v1';

  // ── In-memory items ───────────────────────────────────────────────────────
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  // ── Counts & totals ───────────────────────────────────────────────────────

  int get itemCount {
    int total = 0;
    for (final item in _items) {
      total += item.quantity;
    }
    return total;
  }

  double get subtotal {
    double sum = 0.0;
    for (final item in _items) {
      sum += item.totalPrice;
    }
    return sum;
  }

  double get deliveryFee {
    if (_items.isEmpty) return 0.0;
    // Free delivery over $30
    return subtotal >= 30.0 ? 0.0 : 2.99;
  }

  double get serviceTax => subtotal * 0.08; // 8% tax

  double get total {
    if (_items.isEmpty) return 0.0;
    return subtotal + deliveryFee + serviceTax;
  }

  int get loyaltyPointsEarned => (subtotal * 2).round();

  // ── Mutations ─────────────────────────────────────────────────────────────

  void addItem({
    required FoodItem foodItem,
    required List<ExtraItem> selectedExtras,
    required String category,
    int quantity = 1,
  }) {
    final tempItem = CartItem(
      foodItem: foodItem,
      selectedExtras: selectedExtras,
      category: category,
      quantity: quantity,
    );

    final existingIndex =
        _items.indexWhere((item) => item.uniqueId == tempItem.uniqueId);

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(tempItem);
    }
    _persistAndNotify();
  }

  void removeItem(String uniqueId) {
    _items.removeWhere((item) => item.uniqueId == uniqueId);
    _persistAndNotify();
  }

  void incrementQuantity(String uniqueId) {
    final index = _items.indexWhere((item) => item.uniqueId == uniqueId);
    if (index >= 0) {
      _items[index].quantity++;
      _persistAndNotify();
    }
  }

  void decrementQuantity(String uniqueId) {
    final index = _items.indexWhere((item) => item.uniqueId == uniqueId);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      _persistAndNotify();
    }
  }

  void clearCart() {
    _items.clear();
    _persistAndNotify();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  /// Loads the previously saved cart from [SharedPreferences].
  ///
  /// Call this **once** during app startup before [runApp]:
  /// ```dart
  /// await CartManager().loadCart();
  /// runApp(const GourmetGoApp());
  /// ```
  Future<void> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCartKey);
      if (raw == null || raw.isEmpty) return;

      final List<dynamic> jsonList = jsonDecode(raw) as List<dynamic>;
      _items.clear();
      for (final entry in jsonList) {
        try {
          final item =
              CartItem.fromJson(Map<String, dynamic>.from(entry as Map));
          _items.add(item);
        } catch (e) {
          // Skip any corrupt individual entry rather than crashing the whole
          // cart restore.
          debugPrint('[CartManager] Skipped corrupt cart entry: $e');
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[CartManager] Failed to load cart: $e');
    }
  }

  /// Serialises the current cart to JSON and writes it to [SharedPreferences].
  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _items.map((item) => item.toJson()).toList();
      await prefs.setString(_kCartKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[CartManager] Failed to save cart: $e');
    }
  }

  /// Saves the cart to disk AND notifies all listeners.
  void _persistAndNotify() {
    _saveCart(); // fire-and-forget — non-blocking
    notifyListeners();
  }
}
