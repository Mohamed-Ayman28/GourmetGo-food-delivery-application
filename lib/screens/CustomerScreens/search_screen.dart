import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gourmet_go/consts/appColors.dart';
import 'package:gourmet_go/helper/api_helper.dart';
import 'package:gourmet_go/models/food_item.dart';
import 'package:gourmet_go/widgets/food_item_card.dart';
import 'package:gourmet_go/widgets/skeleton_card.dart';
import 'package:gourmet_go/helper/cart_manager.dart';

/// Enum for sort options.
enum SortOption { none, priceLowHigh, priceHighLow, ratingHighLow, nameAZ }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiHelper _api = ApiHelper();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  // ── Data state ──
  List<({FoodItem item, String category})> _allItems = [];
  List<String> _allCategories = [];
  bool _loading = true;
  String? _error;

  // ── Filter state ──
  final Set<String> _selectedCategories = {};
  SortOption _currentSort = SortOption.none;
  RangeValues? _priceRange;
  double _minPrice = 0;
  double _maxPrice = 100;

  // ── Search state ──
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _query = _searchController.text.trim());
      }
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.fetchAllItems();
      final categories = await _api.fetchCategoryNames();

      // Calculate price range
      if (items.isNotEmpty) {
        final prices = items.map((e) => e.item.price).toList();
        _minPrice = prices.reduce((a, b) => a < b ? a : b);
        _maxPrice = prices.reduce((a, b) => a > b ? a : b);
      }

      if (!mounted) return;
      setState(() {
        _allItems = items;
        _allCategories = categories;
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

  /// Apply search query + filters + sort.
  List<({FoodItem item, String category})> get _filteredItems {
    var results = List<({FoodItem item, String category})>.from(_allItems);

    // 1. Text search (name, description, ingredients)
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      results = results.where((entry) {
        final item = entry.item;
        return item.name.toLowerCase().contains(q) ||
            item.description.toLowerCase().contains(q) ||
            item.ingredients.any((i) => i.toLowerCase().contains(q));
      }).toList();
    }

    // 2. Category filter
    if (_selectedCategories.isNotEmpty) {
      results = results
          .where((e) => _selectedCategories.contains(e.category))
          .toList();
    }

    // 3. Price range filter
    if (_priceRange != null) {
      results = results.where((e) {
        return e.item.price >= _priceRange!.start &&
            e.item.price <= _priceRange!.end;
      }).toList();
    }

    // 4. Sort
    switch (_currentSort) {
      case SortOption.priceLowHigh:
        results.sort((a, b) => a.item.price.compareTo(b.item.price));
        break;
      case SortOption.priceHighLow:
        results.sort((a, b) => b.item.price.compareTo(a.item.price));
        break;
      case SortOption.ratingHighLow:
        results.sort((a, b) => b.item.rate.compareTo(a.item.rate));
        break;
      case SortOption.nameAZ:
        results.sort((a, b) => a.item.name.compareTo(b.item.name));
        break;
      case SortOption.none:
        break;
    }

    return results;
  }

  bool get _hasActiveFilters =>
      _selectedCategories.isNotEmpty ||
      _currentSort != SortOption.none ||
      _priceRange != null;

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCategories.isNotEmpty) count++;
    if (_currentSort != SortOption.none) count++;
    if (_priceRange != null) count++;
    return count;
  }

  void _clearAllFilters() {
    setState(() {
      _selectedCategories.clear();
      _currentSort = SortOption.none;
      _priceRange = null;
    });
  }

  // ─────────────────────────────────────────────
  // Filter Bottom Sheet
  // ─────────────────────────────────────────────
  void _showFilterSheet() {
    // Work with temporary copies so Cancel doesn't apply changes
    final tempCategories = Set<String>.from(_selectedCategories);
    var tempSort = _currentSort;
    var tempPriceRange = _priceRange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Handle ──
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // ── Header ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            tempCategories.clear();
                            tempSort = SortOption.none;
                            tempPriceRange = null;
                          });
                        },
                        child: const Text(
                          'Reset All',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // ── Scrollable content ──
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── Categories ───
                        const Text(
                          'Categories',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _allCategories.map((cat) {
                            final isSelected = tempCategories.contains(cat);
                            return FilterChip(
                              label: Text(cat),
                              selected: isSelected,
                              onSelected: (val) {
                                setSheetState(() {
                                  if (val) {
                                    tempCategories.add(cat);
                                  } else {
                                    tempCategories.remove(cat);
                                  }
                                });
                              },
                              selectedColor:
                                  AppColors.primary.withValues(alpha: 0.15),
                              checkmarkColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                ),
                              ),
                              backgroundColor: Colors.white,
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 24),

                        // ─── Sort By ───
                        const Text(
                          'Sort By',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _sortChip('Price: Low → High',
                                SortOption.priceLowHigh, tempSort, (s) {
                              setSheetState(() => tempSort = s);
                            }),
                            _sortChip('Price: High → Low',
                                SortOption.priceHighLow, tempSort, (s) {
                              setSheetState(() => tempSort = s);
                            }),
                            _sortChip('Rating: Best First',
                                SortOption.ratingHighLow, tempSort, (s) {
                              setSheetState(() => tempSort = s);
                            }),
                            _sortChip(
                                'Name: A → Z', SortOption.nameAZ, tempSort,
                                (s) {
                              setSheetState(() => tempSort = s);
                            }),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ─── Price Range ───
                        const Text(
                          'Price Range',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '\$${(tempPriceRange?.start ?? _minPrice).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              '\$${(tempPriceRange?.end ?? _maxPrice).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        RangeSlider(
                          values: tempPriceRange ??
                              RangeValues(_minPrice, _maxPrice),
                          min: _minPrice,
                          max: _maxPrice,
                          divisions:
                              ((_maxPrice - _minPrice) / 0.5).round().clamp(1, 200),
                          activeColor: AppColors.primary,
                          inactiveColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          labels: RangeLabels(
                            '\$${(tempPriceRange?.start ?? _minPrice).toStringAsFixed(2)}',
                            '\$${(tempPriceRange?.end ?? _maxPrice).toStringAsFixed(2)}',
                          ),
                          onChanged: (values) {
                            setSheetState(() => tempPriceRange = values);
                          },
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // ── Apply Button ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategories
                            ..clear()
                            ..addAll(tempCategories);
                          _currentSort = tempSort;
                          // Only apply price range if user changed it
                          if (tempPriceRange != null &&
                              (tempPriceRange!.start != _minPrice ||
                                  tempPriceRange!.end != _maxPrice)) {
                            _priceRange = tempPriceRange;
                          } else {
                            _priceRange = null;
                          }
                        });
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sortChip(String label, SortOption option, SortOption current,
      ValueChanged<SortOption> onSelected) {
    final isSelected = current == option;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        onSelected(val ? option : SortOption.none);
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.grey.shade300,
        ),
      ),
      backgroundColor: Colors.white,
    );
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Search Bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _buildSearchBar(),
        ),

        // ── Active Filter Chips (horizontal scroll) ──
        if (_hasActiveFilters) _buildActiveFilterBar(),

        const SizedBox(height: 8),

        // ── Results ──
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search dishes, ingredients...',
          hintStyle: TextStyle(
            color: AppColors.textPrimary.withValues(alpha: 0.45),
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.textPrimary.withValues(alpha: 0.65),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Clear button (only when text is present)
              if (_query.isNotEmpty)
                IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.textSecondary,
                ),
              // Filter button with badge
              Stack(
                children: [
                  IconButton(
                    onPressed: _loading ? null : _showFilterSheet,
                    icon: const Icon(Icons.tune_rounded),
                    color: _hasActiveFilters
                        ? AppColors.primary
                        : AppColors.primary,
                  ),
                  if (_activeFilterCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$_activeFilterCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilterBar() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Category chips
          ..._selectedCategories.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Chip(
                  label: Text(cat, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () {
                    setState(() => _selectedCategories.remove(cat));
                  },
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.1),
                  deleteIconColor: AppColors.primary,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  labelStyle: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              )),

          // Sort chip
          if (_currentSort != SortOption.none)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Chip(
                label: Text(_sortLabel(_currentSort),
                    style: const TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  setState(() => _currentSort = SortOption.none);
                },
                backgroundColor:
                    AppColors.primary.withValues(alpha: 0.1),
                deleteIconColor: AppColors.primary,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                labelStyle: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),

          // Price range chip
          if (_priceRange != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Chip(
                label: Text(
                  '\$${_priceRange!.start.toStringAsFixed(0)} – \$${_priceRange!.end.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12),
                ),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  setState(() => _priceRange = null);
                },
                backgroundColor:
                    AppColors.primary.withValues(alpha: 0.1),
                deleteIconColor: AppColors.primary,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                labelStyle: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),

          // Clear All
          GestureDetector(
            onTap: _clearAllFilters,
            child: const Chip(
              label: Text('Clear All',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  )),
              backgroundColor: Colors.transparent,
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  String _sortLabel(SortOption opt) {
    switch (opt) {
      case SortOption.priceLowHigh:
        return 'Price ↑';
      case SortOption.priceHighLow:
        return 'Price ↓';
      case SortOption.ratingHighLow:
        return 'Top Rated';
      case SortOption.nameAZ:
        return 'A → Z';
      case SortOption.none:
        return '';
    }
  }

  Widget _buildBody() {
    // ── Loading ──
    if (_loading) {
      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemBuilder: (_, _) => const SkeletonCard(),
      );
    }

    // ── Error ──
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 64,
                  color: AppColors.textPrimary.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              const Text(
                "Couldn't load menu",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: AppColors.textPrimary.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Try Again"),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Empty query, no filters → show prompt ──
    if (_query.isEmpty && !_hasActiveFilters) {
      return _buildEmptyPrompt();
    }

    final results = _filteredItems;

    // ── No results ──
    if (results.isEmpty) {
      return _buildNoResults();
    }

    // ── Results grid ──
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${results.length} ${results.length == 1 ? 'result' : 'results'} found',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            padding:
                const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 24),
            itemCount: results.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.68,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemBuilder: (context, index) {
              final entry = results[index];
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
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text("${entry.item.name} added to cart!"),
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_rounded,
              size: 72,
              color: AppColors.primary.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 20),
            const Text(
              'Explore Our Menu',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for dishes by name, ingredients,\nor use filters to find what you love',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary.withValues(alpha: 0.5),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Quick category buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _allCategories.map((cat) {
                return ActionChip(
                  label: Text(cat),
                  onPressed: () {
                    setState(() {
                      _selectedCategories.clear();
                      _selectedCategories.add(cat);
                    });
                  },
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  labelStyle: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_food_rounded,
              size: 64,
              color: AppColors.textPrimary.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            const Text(
              'No dishes found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _query.isNotEmpty
                  ? 'Try a different search term or adjust your filters'
                  : 'Try adjusting your filters',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                _searchController.clear();
                _clearAllFilters();
                setState(() => _query = '');
              },
              child: const Text(
                'Clear All Filters',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
