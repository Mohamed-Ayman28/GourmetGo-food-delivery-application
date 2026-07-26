import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gourmet_go/helper/api_helper.dart';
import 'package:gourmet_go/models/food_item.dart';
import 'package:gourmet_go/screens/CustomerScreens/CategoriesScreens/category_food_screen.dart';
import 'package:gourmet_go/screens/CustomerScreens/profle_screen.dart';
import 'package:gourmet_go/screens/CustomerScreens/search_screen.dart';
import 'package:gourmet_go/screens/CustomerScreens/cart_screen.dart';
import 'package:gourmet_go/screens/CustomerScreens/customer_orders_screen.dart';
import 'package:gourmet_go/screens/CustomerScreens/delivery_addresses_screen.dart';
import 'package:gourmet_go/helper/cart_manager.dart';
import 'package:gourmet_go/consts/appColors.dart';
import 'package:gourmet_go/widgets/categroies.dart';
import 'package:gourmet_go/widgets/custom_bottom_nav_bar.dart';
import 'package:gourmet_go/widgets/food_item_card.dart';
import 'package:gourmet_go/widgets/search_bar.dart';
import 'package:gourmet_go/widgets/skeleton_card.dart';
import 'package:gourmet_go/features/order_tracking/presentation/pages/staff_order_manager_screen.dart';
import 'package:gourmet_go/features/order_tracking/presentation/pages/driver_dashboard_screen.dart';
import 'package:gourmet_go/features/order_tracking/presentation/pages/customer_tracking_screen.dart';
import 'package:gourmet_go/screens/AdminScreens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final ApiHelper _api = ApiHelper();

  List<({FoodItem item, String category})> _trendyFoods = [];
  bool _trendyLoading = true;
  String? _trendyError;

  final List<CategoryItem> categories = [
    CategoryItem(icon: Icons.fastfood, title: "Burgers"),
    CategoryItem(icon: Icons.local_pizza, title: "Pizza"),
    CategoryItem(icon: Icons.local_cafe, title: "Drinks"),
    CategoryItem(icon: Icons.set_meal_rounded, title: "Steaks"),
    CategoryItem(icon: Icons.cake, title: "Desserts"),
    CategoryItem(icon: Icons.set_meal, title: "Fried Chicken"),
  ];

  /// Maps each category title to its API category name and emoji.
  static const Map<String, Map<String, String>> _categoryRoutes = {
    'Burgers': {'endpoint': 'Burgers', 'emoji': '🍔'},
    'Pizza': {'endpoint': 'Pizza', 'emoji': '🍕'},
    'Drinks': {'endpoint': 'Drinks', 'emoji': '☕'},
    'Steaks': {'endpoint': 'Steaks', 'emoji': '🥩'},
    'Desserts': {'endpoint': 'Desserts', 'emoji': '🍰'},
    'Fried Chicken': {'endpoint': 'Fried Chicken', 'emoji': '🍗'},
  };

  String _currentDeliverAddress = "Current GPS Location";

  @override
  void initState() {
    super.initState();
    _fetchTrendyFoods();
    _loadSavedDeliverAddress();
  }

  Future<void> _loadSavedDeliverAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('user_delivery_address');
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() {
        _currentDeliverAddress = saved;
      });
    }
  }

  Future<void> _fetchTrendyFoods() async {
    if (!mounted) return;
    setState(() {
      _trendyLoading = true;
      _trendyError = null;
    });

    try {
      final items = await _api.fetchAllItems();
      if (!mounted) return;
      // Take a random/trendy selection of items
      final list = List<({FoodItem item, String category})>.from(items);
      list.shuffle();
      setState(() {
        _trendyFoods = list.take(8).toList();
        _trendyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _trendyError = e.toString();
        _trendyLoading = false;
      });
    }
  }

  Widget _buildTrendySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text(
                    "Trendy Foods",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 6),
                  Text("🔥", style: TextStyle(fontSize: 20)),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CategoryFoodScreen(
                        title: "Best Foods",
                        endpoint: "best-foods",
                        emoji: "🔥",
                      ),
                    ),
                  );
                },
                child: const Text(
                  "See All",
                  style: TextStyle(
                    color: Color(0xffA93500),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_trendyLoading)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 4,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.68,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemBuilder: (_, _) => const SkeletonCard(),
          )
        else if (_trendyError != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 40,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 8),
                  const Text("Failed to load trendy foods"),
                  TextButton(
                    onPressed: _fetchTrendyFoods,
                    child: const Text(
                      "Retry",
                      style: TextStyle(color: Color(0xffA93500)),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _trendyFoods.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.68,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemBuilder: (context, index) {
              final entry = _trendyFoods[index];
              return FoodItemCard(
                item: entry.item,
                category: entry.category,
                onAddToCart: () {
                  CartManager().addItem(
                    foodItem: entry.item,
                    selectedExtras: const [],
                    category: entry.category,
                    quantity: 1,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text("${entry.item.name} added to cart!"),
                        ],
                      ),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildHomeBody() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            height: 2,
            color: Colors.grey.shade300,
          ),
          ListTile(
            leading: const Icon(
              Icons.location_on_outlined,
              size: 30,
              color: Color(0xffA93500),
            ),
            title: const Text(
              "Deliver To",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              _currentDeliverAddress,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DeliveryAddressesScreen(),
                ),
              );
              _loadSavedDeliverAddress();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedIndex = 1);
              },
              child: AbsorbPointer(
                child: SearchInput(
                  textController: TextEditingController(),
                  hintText: "Search GourmetGo...",
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Categories",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final item = categories[index];
                final route = _categoryRoutes[item.title];
                return CategoryItem(
                  icon: item.icon,
                  title: item.title,
                  onTap: route == null
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategoryFoodScreen(
                              title: item.title,
                              endpoint: route['endpoint']!,
                              emoji: route['emoji']!,
                            ),
                          ),
                        ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildTrendySection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTabBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeBody();
      case 1:
        return const SearchScreen();
      case 2:
        return const CustomerOrdersScreen();
      case 3:
        return const ProfileScreen();
      default:
        return _buildHomeBody();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            color: const Color(0xffA93500),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
        leading: Builder(
          builder: (drawerCtx) => IconButton(
            color: const Color(0xffA93500),
            onPressed: () {
              Scaffold.of(drawerCtx).openDrawer();
            },
            icon: const Icon(Icons.menu),
          ),
        ),
        title: const Text(
          "Gourmet Go",
          style: TextStyle(
            color: Color(0xffA93500),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xffA93500),
              ),
              accountName: const Text(
                'GourmetGo App',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              accountEmail: const Text('Production Delivery Portal'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Image.asset(
                    'assets/images/logo.png',
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.restaurant_rounded,
                      color: Color(0xffA93500),
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined, color: AppColors.primary),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
              title: const Text('My Orders'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on_outlined, color: AppColors.primary),
              title: const Text('Delivery Addresses'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DeliveryAddressesScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: _buildTabBody(),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
