import 'package:gourmet_go/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:gourmet_go/consts/appColors.dart';
import 'package:gourmet_go/models/food_item.dart';
import 'package:gourmet_go/models/extra_item.dart';
import 'package:gourmet_go/helper/cart_manager.dart';

/// Returns category-specific extras.
List<ExtraItem> _extrasForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'burgers':
      return const [
        ExtraItem(name: 'Double Patty', price: 3.50, icon: Icons.layers_rounded),
        ExtraItem(name: 'Fries', price: 2.00, icon: Icons.bakery_dining_rounded),
        ExtraItem(name: 'Extra Cheese', price: 1.50, icon: Icons.square_rounded),
        ExtraItem(name: 'Onion Rings', price: 2.50, icon: Icons.circle_outlined),
        ExtraItem(name: 'Coleslaw', price: 1.75, icon: Icons.grass_rounded),
      ];
    case 'pizza':
      return const [
        ExtraItem(name: 'More Filling', price: 3.00, icon: Icons.add_circle_outline_rounded),
        ExtraItem(name: 'Stuffed Crust', price: 2.50, icon: Icons.panorama_horizontal_rounded),
        ExtraItem(name: 'Extra Mozzarella', price: 2.00, icon: Icons.square_rounded),
        ExtraItem(name: 'Jalapeños', price: 1.00, icon: Icons.local_fire_department_rounded),
        ExtraItem(name: 'Garlic Bread', price: 2.50, icon: Icons.bakery_dining_rounded),
      ];
    case 'desserts':
      return const [
        ExtraItem(name: 'Extra Sauce', price: 1.50, icon: Icons.water_drop_rounded),
        ExtraItem(name: 'Whipped Cream', price: 1.00, icon: Icons.cloud_rounded),
        ExtraItem(name: 'Ice Cream Scoop', price: 2.50, icon: Icons.icecream_rounded),
        ExtraItem(name: 'Chocolate Drizzle', price: 1.75, icon: Icons.cookie_rounded),
        ExtraItem(name: 'Fresh Berries', price: 2.00, icon: Icons.spa_rounded),
      ];
    case 'drinks':
      return const [
        ExtraItem(name: 'Extra Shot', price: 1.50, icon: Icons.coffee_rounded),
        ExtraItem(name: 'Whipped Cream', price: 1.00, icon: Icons.cloud_rounded),
        ExtraItem(name: 'Flavor Syrup', price: 0.75, icon: Icons.water_drop_rounded),
        ExtraItem(name: 'Oat Milk', price: 1.00, icon: Icons.grass_rounded),
        ExtraItem(name: 'Large Size', price: 1.50, icon: Icons.expand_rounded),
      ];
    case 'steaks':
      return const [
        ExtraItem(name: 'Side Salad', price: 3.00, icon: Icons.grass_rounded),
        ExtraItem(name: 'Mashed Potatoes', price: 2.50, icon: Icons.rice_bowl_rounded),
        ExtraItem(name: 'Grilled Veggies', price: 2.50, icon: Icons.eco_rounded),
        ExtraItem(name: 'Pepper Sauce', price: 1.50, icon: Icons.water_drop_rounded),
        ExtraItem(name: 'Garlic Butter', price: 1.00, icon: Icons.square_rounded),
      ];
    default:
      return const [
        ExtraItem(name: 'Extra Sauce', price: 1.50, icon: Icons.water_drop_rounded),
        ExtraItem(name: 'Side Salad', price: 3.00, icon: Icons.grass_rounded),
        ExtraItem(name: 'Drink', price: 2.50, icon: Icons.local_cafe_rounded),
      ];
  }
}

class FoodDetailScreen extends StatefulWidget {
  final FoodItem item;
  final String category;
  final String heroTag;

  const FoodDetailScreen({
    super.key,
    required this.item,
    required this.category,
    this.heroTag = '',
  });

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen>
    with TickerProviderStateMixin {
  int _quantity = 1;
  bool _isFavorite = false;
  final Set<int> _selectedExtras = {};
  late final List<ExtraItem> _extras;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _extras = _extrasForCategory(widget.category);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  double get _extrasTotal {
    double total = 0;
    for (final i in _selectedExtras) {
      total += _extras[i].price;
    }
    return total;
  }

  double get _totalPrice => (widget.item.price + _extrasTotal) * _quantity;

  void _addToCart() {
    final selectedExtrasList = _selectedExtras.map((i) => _extras[i]).toList();
    CartManager().addItem(
      foodItem: widget.item,
      selectedExtras: selectedExtrasList,
      category: widget.category,
      quantity: _quantity,
    );

    final extrasNames = selectedExtrasList.map((e) => e.name).toList();
    final msg = extrasNames.isEmpty
        ? '${widget.item.name} x$_quantity added to cart!'
        : '${widget.item.name} x$_quantity + ${extrasNames.join(", ")} added!';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Scrollable Content ──
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Hero Image ──
              _buildHeroImage(screenHeight),

              // ── Body ──
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoSection(),
                      _buildActionButtons(),
                      _buildDeliveryBanner(),
                      if (widget.item.ingredients.isNotEmpty) _buildIngredients(),
                      _buildExtrasSection(),
                      _buildQuantitySelector(),
                      // Bottom padding for the fixed cart bar
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Back Button ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: _circleButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ),

          // ── Share Button ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: _circleButton(
              icon: Icons.share_outlined,
              onTap: () {
                CustomSnackBar.show(context, message: 'Share feature coming soon!', type: SnackBarType.info);
              },
            ),
          ),

          // ── Bottom Cart Bar ──
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Hero Image Sliver
  // ─────────────────────────────────────────────
  Widget _buildHeroImage(double screenHeight) {
    return SliverAppBar(
      expandedHeight: screenHeight * 0.38,
      pinned: false,
      floating: false,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            Hero(
              tag: widget.heroTag.isNotEmpty
                  ? widget.heroTag
                  : 'food_${widget.item.id}',
              child: Image.network(
                widget.item.img,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.secondary,
                  child: const Icon(Icons.fastfood_rounded,
                      size: 80, color: AppColors.primary),
                ),
              ),
            ),
            // Bottom gradient
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 120,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.background,
                      AppColors.background.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            // Rating badge
            if (widget.item.rate >= 4.0)
              Positioned(
                bottom: 16,
                left: 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'TOP RATED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Info Section (name, rating, time)
  // ─────────────────────────────────────────────
  Widget _buildInfoSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.category.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Name
          Text(
            widget.item.name,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),

          // Description
          Text(
            widget.item.description,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),

          // Rating + delivery time row
          Row(
            children: [
              // Rating
              const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 20),
              const SizedBox(width: 4),
              Text(
                widget.item.rate.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(500+ reviews)',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(width: 20),
              const SizedBox(width: 4),
              Text(
                '20–35 min',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Action Buttons (Info, Favorite, Share)
  // ─────────────────────────────────────────────
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _actionChip(
            icon: Icons.info_outline_rounded,
            label: 'Info',
            onTap: _showNutritionInfo,
          ),
          const SizedBox(width: 10),
          _actionChip(
            icon: _isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: 'Favorite',
            isActive: _isFavorite,
            onTap: () => setState(() => _isFavorite = !_isFavorite),
          ),
          const SizedBox(width: 10),
          _actionChip(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: () {
              CustomSnackBar.show(context, message: 'Share feature coming soon!', type: SnackBarType.info);
            },
          ),
        ],
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isActive ? AppColors.error : Colors.grey.shade200,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isActive ? AppColors.error : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color:
                        isActive ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Free Delivery Banner
  // ─────────────────────────────────────────────
  Widget _buildDeliveryBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.success.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delivery_dining_rounded,
                  color: AppColors.success, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Free delivery over \$30',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Ingredients Section
  // ─────────────────────────────────────────────
  Widget _buildIngredients() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Ingredients',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.item.ingredients.map((ingredient) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  ingredient,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Extras Section (category-specific)
  // ─────────────────────────────────────────────
  Widget _buildExtrasSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Extras & Add-ons',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Customize your ${widget.category.toLowerCase()}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(_extras.length, (index) {
            final extra = _extras[index];
            final isSelected = _selectedExtras.contains(index);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedExtras.remove(index);
                      } else {
                        _selectedExtras.add(index);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.06)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : Colors.grey.shade200,
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Row(
                      children: [
                        // Icon
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            extra.icon,
                            size: 20,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Name
                        Expanded(
                          child: Text(
                            extra.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        // Price
                        Text(
                          '+\$${extra.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Checkbox
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check_rounded,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Quantity Selector
  // ─────────────────────────────────────────────
  Widget _buildQuantitySelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          const Text(
            'Quantity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          // Minus
          _quantityButton(
            icon: Icons.remove_rounded,
            onTap: _quantity > 1
                ? () => setState(() => _quantity--)
                : null,
          ),
          // Count
          Container(
            width: 48,
            alignment: Alignment.center,
            child: Text(
              '$_quantity',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          // Plus
          _quantityButton(
            icon: Icons.add_rounded,
            onTap: _quantity < 20
                ? () => setState(() => _quantity++)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _quantityButton({
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    return Material(
      color: isEnabled
          ? AppColors.primary.withValues(alpha: 0.1)
          : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 20,
            color: isEnabled ? AppColors.primary : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Bottom Add-to-Cart Bar
  // ─────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Row(
          children: [
            // Price column
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '\$${_totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            // Add to Cart button
            Expanded(
              child: SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _addToCart,
                  icon: const Icon(Icons.shopping_bag_rounded, size: 20),
                  label: const Text(
                    'Add to Cart',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Nutrition Info Dialog
  // ─────────────────────────────────────────────
  void _showNutritionInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Nutrition Info',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _nutritionRow('Calories', '450 kcal'),
            _nutritionRow('Protein', '22g'),
            _nutritionRow('Carbs', '38g'),
            _nutritionRow('Fat', '18g'),
            _nutritionRow('Fiber', '4g'),
            _nutritionRow('Sodium', '680mg'),
            const SizedBox(height: 12),
            Text(
              '* Nutritional values are approximate and may vary.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textPrimary.withValues(alpha: 0.4),
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _nutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
