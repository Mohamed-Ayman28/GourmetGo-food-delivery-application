class FoodItem {
  final String id;
  final String img;
  final String name;
  final String description;
  final double price;
  final double rate;
  final String country;
  final List<String> ingredients;

  const FoodItem({
    required this.id,
    required this.img,
    required this.name,
    required this.description,
    required this.price,
    required this.rate,
    required this.country,
    this.ingredients = const [],
  });

  // ── Serialization (used by CartManager for local persistence) ────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'img': img,
        'name': name,
        'description': description,
        'price': price,
        'rate': rate,
        'country': country,
        'ingredients': ingredients,
      };

  /// Reconstructs a [FoodItem] from a persisted JSON map.
  factory FoodItem.fromPersistedJson(Map<String, dynamic> json) {
    final ingredientsList = <String>[];
    if (json['ingredients'] is List) {
      for (final i in json['ingredients'] as List) {
        ingredientsList.add(i.toString());
      }
    }
    return FoodItem(
      id: json['id'] as String? ?? '',
      img: json['img'] as String? ?? '',
      name: json['name'] as String? ?? 'Food Item',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      country: json['country'] as String? ?? '',
      ingredients: ingredientsList,
    );
  }

  /// Parse from the old API format (free-food-menus-api).
  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? 'Food Item';
    final rawImg = json['img']?.toString() ?? '';
    final imgUrl = getStableImageUrl(name, rawImg);

    return FoodItem(
      id: json['id']?.toString() ?? '',
      img: imgUrl,
      name: name,
      description: json['dsc']?.toString() ?? json['description']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      country: json['country']?.toString() ?? '',
    );
  }

  /// Parse from the new Gourmet GO menu API format.
  factory FoodItem.fromGourmetJson(Map<String, dynamic> json, {int index = 0}) {
    // Price comes as "$8.50" – strip the dollar sign and parse.
    final rawPrice = json['price']?.toString() ?? '0';
    final cleanPrice = rawPrice.replaceAll(RegExp(r'[^\d.]'), '');

    final ingredientsList = <String>[];
    if (json['ingredients'] is List) {
      for (final i in json['ingredients'] as List) {
        ingredientsList.add(i.toString());
      }
    }

    final name = json['name']?.toString() ?? 'Food Item';
    final rawImg = json['image']?.toString() ?? '';
    final imgUrl = getStableImageUrl(name, rawImg);

    // Generate a unique ID using the name to prevent overlaps across different categories
    final formattedName = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final uniqueId = 'gourmet_${formattedName}_$index';

    return FoodItem(
      id: uniqueId,
      img: imgUrl,
      name: name,
      description: json['description']?.toString() ?? '',
      price: double.tryParse(cleanPrice) ?? 0.0,
      rate: (json['rating'] as num?)?.toDouble() ?? 0.0,
      country: '',
      ingredients: ingredientsList,
    );
  }

  /// Get a stable, high-quality Unsplash image based on the food item name.
  /// If it doesn't match any mapped item, fallback to a locked loremflickr URL.
  static String getStableImageUrl(String name, String fallbackUrl) {
    final lowerName = name.toLowerCase().trim();

    // High quality curated Unsplash photo IDs for products
    const Map<String, String> unsplashMapping = {
      // Burgers
      'classic cheeseburger': 'photo-1568901346375-23c9450c58cd',
      'bacon bbq burger': 'photo-1553979459-d2229ba7433b',
      'mushroom swiss burger': 'photo-1586190848861-99aa4a171e90',
      'double beef burger': 'photo-1525059696034-4967a8e1dca2',
      'spicy jalapeno burger': 'photo-1594212699903-ec8a3eca50f5',
      'veggie burger': 'photo-1525059696034-4967a8e1dca2',
      'blue cheese burger': 'photo-1568901346375-23c9450c58cd',
      'truffle burger': 'photo-1586190848861-99aa4a171e90',
      'hawaiian burger': 'photo-1553979459-d2229ba7433b',
      'bbq pulled pork burger': 'photo-1594212699903-ec8a3eca50f5',
      'chicken burger': 'photo-1625813506062-0aeb1d7a094b',
      'fish burger': 'photo-1525059696034-4967a8e1dca2',
      'breakfast burger': 'photo-1594212699903-ec8a3eca50f5',
      'black bean burger': 'photo-1586190848861-99aa4a171e90',
      'smoky chipotle burger': 'photo-1553979459-d2229ba7433b',

      // Pizza
      'margherita pizza': 'photo-1604068549290-dea0e4a305ca',
      'pepperoni pizza': 'photo-1628840042765-356cda07504e',
      'bbq chicken pizza': 'photo-1513104890138-7c749659a591',
      'four cheese pizza': 'photo-1573821663912-569905455b1c',
      'veggie supreme pizza': 'photo-1571066811602-71683a3f680d',
      'hawaiian pizza': 'photo-1565299624946-b28f40a0ae38',
      'meat lovers pizza': 'photo-1513104890138-7c749659a591',
      'mushroom truffle pizza': 'photo-1604068549290-dea0e4a305ca',
      'buffalo chicken pizza': 'photo-1628840042765-356cda07504e',
      'pesto caprese pizza': 'photo-1573821663912-569905455b1c',
      'diavola pizza': 'photo-1571066811602-71683a3f680d',
      'white pizza': 'photo-1565299624946-b28f40a0ae38',
      'seafood pizza': 'photo-1513104890138-7c749659a591',
      'prosciutto arugula pizza': 'photo-1604068549290-dea0e4a305ca',
      'vegan delight pizza': 'photo-1571066811602-71683a3f680d',

      // Drinks
      'fresh lemonade': 'photo-1513558161293-cdaf765ed2fd',
      'iced tea': 'photo-1556679343-c7306c1976bc',
      'cola': 'photo-1622483767028-3f66f32aef97',
      'orange juice': 'photo-1621506289937-a8e4df240d0b',
      'mango smoothie': 'photo-1553530666-ba11a7da3888',
      'strawberry milkshake': 'photo-1579954115545-a95591f28bfc',
      'chocolate milkshake': 'photo-1572490122747-3968b75cc699',
      'sparkling water': 'photo-1551782450-1a14c803eff6',
      'iced coffee': 'photo-1517701604599-bb29b565090c',
      'mojito mocktail': 'photo-1513558161293-cdaf765ed2fd',
      'watermelon juice': 'photo-1621506289937-a8e4df240d0b',
      'ginger ale': 'photo-1556679343-c7306c1976bc',
      'hibiscus iced tea': 'photo-1517701604599-bb29b565090c',
      'pineapple juice': 'photo-1621506289937-a8e4df240d0b',
      'vanilla latte': 'photo-1541167760496-1628856ab772',

      // Steaks
      'ribeye steak': 'photo-1544025162-d76694265947',
      'filet mignon': 'photo-1546964124-0cce460f38ef',
      't-bone steak': 'photo-1600891964599-f61ba0e24092',
      'sirloin steak': 'photo-1544025162-d76694265947',
      'new york strip': 'photo-1546964124-0cce460f38ef',
      'porterhouse steak': 'photo-1600891964599-f61ba0e24092',
      'tomahawk steak': 'photo-1544025162-d76694265947',
      'peppercorn steak': 'photo-1546964124-0cce460f38ef',
      'garlic butter steak': 'photo-1600891964599-f61ba0e24092',
      'wagyu steak': 'photo-1544025162-d76694265947',
      'grilled flank steak': 'photo-1546964124-0cce460f38ef',
      'bbq steak': 'photo-1600891964599-f61ba0e24092',
      'steak au poivre': 'photo-1544025162-d76694265947',
      'surf and turf': 'photo-1546964124-0cce460f38ef',
      'herb crusted steak': 'photo-1600891964599-f61ba0e24092',

      // Desserts
      'chocolate lava cake': 'photo-1606313564200-e75d5e30476c',
      'cheesecake': 'photo-1533134242443-d4fd215305ad',
      'tiramisu': 'photo-1571877227200-a0d98ea607e9',
      'apple pie': 'photo-1621510456681-23a23cfb5f57',
      'creme brulee': 'photo-1516685018646-549198525c1b',
      'brownie sundae': 'photo-1564355808539-22fda35bed7e',
      'red velvet cake': 'photo-1616260841936-748934caf7b3',
      'panna cotta': 'photo-1488477181946-6428a0291777',
      'chocolate mousse': 'photo-1606313564200-e75d5e30476c',
      'carrot cake': 'photo-1606313564200-e75d5e30476c',
      'ice cream sundae': 'photo-1563729784474-d77dbb933a9e',
      'banana split': 'photo-1563729784474-d77dbb933a9e',
      'lemon tart': 'photo-1516685018646-549198525c1b',
      'churros': 'photo-1621510456681-23a23cfb5f57',
      'baklava': 'photo-1519623286359-e9f3cbef015b',

      // Fried Chicken
      'classic fried chicken': 'photo-1569058242253-92a9c755a0ec',
      'spicy fried chicken': 'photo-1627662236973-4f8259fa2441',
      'honey butter chicken': 'photo-1606755962773-d324e0a13086',
      'buttermilk fried chicken': 'photo-1569058242253-92a9c755a0ec',
      'korean fried chicken': 'photo-1627662236973-4f8259fa2441',
      'nashville hot chicken': 'photo-1627662236973-4f8259fa2441',
      'fried chicken tenders': 'photo-1562967914-608f82629710',
      'chicken wings': 'photo-1567620832903-9fc6debc209f',
      'popcorn chicken': 'photo-1562967914-608f82629710',
      'bbq fried chicken': 'photo-1569058242253-92a9c755a0ec',
      'garlic parmesan chicken': 'photo-1606755962773-d324e0a13086',
      'crispy chicken sandwich': 'photo-1625813506062-0aeb1d7a094b',
      'fried chicken bucket': 'photo-1569058242253-92a9c755a0ec',
      'lemon pepper chicken': 'photo-1606755962773-d324e0a13086',
      'fried chicken sliders': 'photo-1569058242253-92a9c755a0ec',
    };

    if (unsplashMapping.containsKey(lowerName)) {
      return 'https://images.unsplash.com/${unsplashMapping[lowerName]}?auto=format&fit=crop&w=600&q=80';
    }

    // Keyword fallback mapping if exact name is not found
    if (lowerName.contains('burger')) {
      return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=600&q=80';
    } else if (lowerName.contains('pizza')) {
      return 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=600&q=80';
    } else if (lowerName.contains('juice') || lowerName.contains('smoothie') || lowerName.contains('shake') || lowerName.contains('tea') || lowerName.contains('coffee') || lowerName.contains('latte') || lowerName.contains('mocktail') || lowerName.contains('cola') || lowerName.contains('ale') || lowerName.contains('water')) {
      return 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?auto=format&fit=crop&w=600&q=80';
    } else if (lowerName.contains('steak') || lowerName.contains('mignon') || lowerName.contains('strip') || lowerName.contains('beef') || lowerName.contains('porterhouse') || lowerName.contains('tomahawk') || lowerName.contains('poivre')) {
      return 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80';
    } else if (lowerName.contains('cake') || lowerName.contains('pie') || lowerName.contains('brulee') || lowerName.contains('sundae') || lowerName.contains('cotta') || lowerName.contains('mousse') || lowerName.contains('split') || lowerName.contains('tart') || lowerName.contains('churros') || lowerName.contains('baklava') || lowerName.contains('tiramisu') || lowerName.contains('cheesecake')) {
      return 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?auto=format&fit=crop&w=600&q=80';
    } else if (lowerName.contains('chicken') || lowerName.contains('wing') || lowerName.contains('tender') || lowerName.contains('bucket')) {
      return 'https://images.unsplash.com/photo-1569058242253-92a9c755a0ec?auto=format&fit=crop&w=600&q=80';
    }

    // Default fallback using stable lock on loremflickr
    if (fallbackUrl.contains('loremflickr.com')) {
      if (fallbackUrl.contains('lock=')) {
        return fallbackUrl;
      }

      int lock = 0;
      for (int i = 0; i < name.length; i++) {
        lock = 31 * lock + name.codeUnitAt(i);
      }
      lock = lock.abs() % 1000 + 1;

      if (fallbackUrl.contains('?')) {
        return '$fallbackUrl&lock=$lock';
      } else {
        return '$fallbackUrl?lock=$lock';
      }
    }

    return fallbackUrl;
  }
}
