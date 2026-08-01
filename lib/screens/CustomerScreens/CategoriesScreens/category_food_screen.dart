import 'package:flutter/material.dart';
import 'package:gourmet_go/helper/api_helper.dart';
import 'package:gourmet_go/models/food_item.dart';
import 'package:gourmet_go/widgets/food_item_card.dart';
import 'package:gourmet_go/widgets/skeleton_card.dart';
import 'package:gourmet_go/consts/appColors.dart';
import 'package:gourmet_go/helper/cart_manager.dart';
import 'package:gourmet_go/widgets/cart_icon_badge.dart';

/// Generic category screen. Pass [title] and [endpoint] (e.g. '/burgers').
class CategoryFoodScreen extends StatefulWidget {
  final String title;
  final String endpoint;
  final String emoji;

  const CategoryFoodScreen({
    super.key,
    required this.title,
    required this.endpoint,
    this.emoji = '🍽️',
  });

  @override
  State<CategoryFoodScreen> createState() => _CategoryFoodScreenState();
}

class _CategoryFoodScreenState extends State<CategoryFoodScreen> {
  final ApiHelper _api = ApiHelper();

  List<FoodItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.fetchCategory(widget.endpoint);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    _api.invalidate(widget.endpoint);
    await _fetch();
  }

  static const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 0.68,
    crossAxisSpacing: 14,
    mainAxisSpacing: 14,
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: colors.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.emoji} ${widget.title}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: false,
        actions: [
          CartIconBadge(color: colors.primary),
        ],
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(ColorScheme colors) {
    // ── Skeleton loading ─────────────────────────────────────
    if (_loading) {
      return CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Container(
                width: 140,
                height: 13,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF3A3A3C)
                      : const Color(0xFFE0E0E6),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) => const SkeletonCard(),
                childCount: 6,
              ),
              gridDelegate: _gridDelegate,
            ),
          ),
        ],
      );
    }

    // ── Error ────────────────────────────────────────────────
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 64,
                  color: colors.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(
                "Couldn't load ${widget.title}",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.5),
                    fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Try Again"),
              ),
            ],
          ),
        ),
      );
    }

    // ── Data ─────────────────────────────────────────────────
    return RefreshIndicator(
      color: colors.primary,
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 16),
              child: Text(
                "${_items.length} items available",
                style: TextStyle(
                  fontSize: 14,
                  color: colors.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16)
                .copyWith(bottom: 24),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => FoodItemCard(
                  item: _items[index],
                  category: widget.title,
                  onAddToCart: () {
                    CartManager().addItem(
                      foodItem: _items[index],
                      selectedExtras: const [],
                      category: widget.title,
                      quantity: 1,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text("${_items[index].name} added to cart!"),
                          ],
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        backgroundColor: AppColors.success,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                childCount: _items.length,
              ),
              gridDelegate: _gridDelegate,
            ),
          ),
        ],
      ),
    );
  }
}
