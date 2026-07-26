import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/food_item.dart';

class ApiHelper {
  // Singleton so the cache lives for the app's lifetime
  static final ApiHelper _instance = ApiHelper._internal();
  factory ApiHelper() => _instance;
  ApiHelper._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Cached full menu (all categories).
  Map<String, List<FoodItem>>? _menuCache;

  /// In-flight request to prevent duplicate simultaneous calls.
  Future<Map<String, List<FoodItem>>>? _inflight;

  /// Fetches the entire menu and caches it.
  /// Returns a map of category name → list of items.
  Future<Map<String, List<FoodItem>>> _fetchMenu() async {
    if (_menuCache != null) {
      return _menuCache!;
    }
    if (_inflight != null) {
      return _inflight!;
    }

    _inflight = _fetchMenuFromFirestore().whenComplete(() => _inflight = null);

    return _inflight!;
  }

  Future<Map<String, List<FoodItem>>> _fetchMenuFromFirestore() async {
    try {
      final categoriesSnapshot = await _firestore.collection('menu_categories').where('isActive', isEqualTo: true).get();
      final itemsSnapshot = await _firestore.collection('menu_items').where('isAvailable', isEqualTo: true).get();

      final Map<String, List<FoodItem>> menu = {};

      for (var catDoc in categoriesSnapshot.docs) {
        final catData = catDoc.data();
        final catId = catDoc.id;
        final categoryName = catData['name'] ?? 'Unknown';

        final List<FoodItem> items = itemsSnapshot.docs
            .where((doc) => doc.data()['categoryId'] == catId)
            .map((doc) {
              final data = doc.data();
              return FoodItem(
                id: data['id'] ?? doc.id,
                img: FoodItem.getStableImageUrl(data['name'] ?? '', data['imageUrl'] ?? ''),
                name: data['name'] ?? '',
                description: data['description'] ?? '',
                price: (data['price'] as num?)?.toDouble() ?? 0.0,
                rate: (data['rating'] as num?)?.toDouble() ?? 0.0,
                country: '',
                ingredients: data['ingredients'] != null ? List<String>.from(data['ingredients']) : [], 
              );
            }).toList();

        menu[categoryName] = items;
      }

      _menuCache = menu;
      return menu;
    } catch (e) {
      throw Exception('Failed to load menu from database: $e');
    }
  }

  /// Fetches items for a specific category.
  /// [endpoint] is treated as the category name (e.g. "Burgers", "Pizza").
  Future<List<FoodItem>> fetchCategory(String endpoint) async {
    final menu = await _fetchMenu();

    // Try exact match first
    if (menu.containsKey(endpoint)) {
      return List.unmodifiable(menu[endpoint]!);
    }

    // Try case-insensitive match
    for (final entry in menu.entries) {
      if (entry.key.toLowerCase() == endpoint.toLowerCase()) {
        return List.unmodifiable(entry.value);
      }
    }

    // For "best-foods" / trendy: return a shuffled mix of all popular items
    if (endpoint == 'best-foods') {
      final allItems = menu.values.expand((items) => items).toList();
      allItems.shuffle();
      return List.unmodifiable(allItems.take(8).toList());
    }

    return [];
  }

  /// Returns all category names from the menu.
  Future<List<String>> fetchCategoryNames() async {
    final menu = await _fetchMenu();
    return menu.keys.toList();
  }

  /// Returns ALL items from every category, each tagged with its category.
  Future<List<({FoodItem item, String category})>> fetchAllItems() async {
    final menu = await _fetchMenu();
    final result = <({FoodItem item, String category})>[];
    for (final entry in menu.entries) {
      for (final item in entry.value) {
        result.add((item: item, category: entry.key));
      }
    }
    return result;
  }

  /// Returns the full menu map (category name → items).
  Future<Map<String, List<FoodItem>>> fetchFullMenu() async {
    return await _fetchMenu();
  }

  /// Clears the cache for refresh.
  void invalidate(String endpoint) => _menuCache = null;

  /// Clears all cached data.
  void clearAll() => _menuCache = null;
}
