import 'package:gourmet_go/models/food_item.dart';
import 'package:gourmet_go/models/extra_item.dart';

class CartItem {
  final FoodItem foodItem;
  final List<ExtraItem> selectedExtras;
  final String category;
  int quantity;

  CartItem({
    required this.foodItem,
    required this.selectedExtras,
    required this.category,
    this.quantity = 1,
  });

  /// Generates a unique key based on food item ID and selected extra names
  /// to group items with identical choices in the cart.
  String get uniqueId {
    final extraNames = selectedExtras.map((e) => e.name).toList()..sort();
    return "${foodItem.id}_${extraNames.join('_')}";
  }

  /// Calculates total price for this cart item including selected extras.
  double get unitPrice {
    double total = foodItem.price;
    for (final extra in selectedExtras) {
      total += extra.price;
    }
    return total;
  }

  double get totalPrice => unitPrice * quantity;

  /// String summary of selected extras.
  String get extrasSummary {
    if (selectedExtras.isEmpty) return "Standard";
    return selectedExtras.map((e) => e.name).join(", ");
  }
}
