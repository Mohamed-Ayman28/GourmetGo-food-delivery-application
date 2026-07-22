import 'package:flutter/foundation.dart';
import 'package:gourmet_go/models/food_item.dart';
import 'package:gourmet_go/models/extra_item.dart';
import 'package:gourmet_go/models/cart_item.dart';

class CartManager extends ChangeNotifier {
  // Singleton pattern
  static final CartManager _instance = CartManager._internal();
  factory CartManager() => _instance;
  CartManager._internal();

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount {
    int total = 0;
    for (final item in _items) {
      total += item.quantity;
    }
    return total;
  }

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

    final existingIndex = _items.indexWhere((item) => item.uniqueId == tempItem.uniqueId);

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(tempItem);
    }
    notifyListeners();
  }

  void removeItem(String uniqueId) {
    _items.removeWhere((item) => item.uniqueId == uniqueId);
    notifyListeners();
  }

  void incrementQuantity(String uniqueId) {
    final index = _items.indexWhere((item) => item.uniqueId == uniqueId);
    if (index >= 0) {
      _items[index].quantity++;
      notifyListeners();
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
      notifyListeners();
    }
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

  double get serviceTax {
    // 8% tax as seen in mockup
    return subtotal * 0.08;
  }

  double get total {
    if (_items.isEmpty) return 0.0;
    return subtotal + deliveryFee + serviceTax;
  }

  int get loyaltyPointsEarned {
    // Roughly 2 points per dollar of subtotal, rounding up
    return (subtotal * 2).round();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
