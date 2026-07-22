import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gourmet_go/models/food_item.dart';

class ApiHelper {
  // Singleton so the cache lives for the app's lifetime
  static final ApiHelper _instance = ApiHelper._internal();
  factory ApiHelper() => _instance;
  ApiHelper._internal();

  static const String _menuUrl =
      'https://mohamed-ayman28.github.io/restaurant-menu-api/gourmet_go_menu.json';

  /// Timeout for each HTTP request.
  static const Duration _timeout = Duration(seconds: 10);

  /// Max retries on failure.
  static const int _maxRetries = 2;

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

    _inflight = _fetchMenuWithRetry()
        .whenComplete(() => _inflight = null);

    return _inflight!;
  }

  Future<Map<String, List<FoodItem>>> _fetchMenuWithRetry() async {
    final uri = Uri.parse(_menuUrl);
    Object? lastError;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http.get(uri).timeout(_timeout);

        if (response.statusCode != 200) {
          throw Exception(
              'Server error ${response.statusCode}: ${response.reasonPhrase}');
        }

        final Map<String, dynamic> body =
            jsonDecode(response.body) as Map<String, dynamic>;

        final List<dynamic> categories =
            body['categories'] as List<dynamic>? ?? [];

        final Map<String, List<FoodItem>> menu = {};

        for (final cat in categories) {
          final catMap = cat as Map<String, dynamic>;
          final categoryName = catMap['category']?.toString() ?? '';
          final items = catMap['items'] as List<dynamic>? ?? [];

          menu[categoryName] = items.asMap().entries.map((entry) {
            return FoodItem.fromGourmetJson(
              entry.value as Map<String, dynamic>,
              index: entry.key,
            );
          }).toList();
        }

        _menuCache = menu;
        return menu;
      } on TimeoutException {
        lastError = 'Request timed out. Please check your internet connection.';
        if (attempt < _maxRetries) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        lastError = e;
        if (attempt < _maxRetries) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    throw Exception(lastError.toString());
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

    // For "best-foods" / trendy: return a shuffled mix of all items
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
