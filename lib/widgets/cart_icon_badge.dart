import 'package:flutter/material.dart';
import 'package:gourmet_go/helper/cart_manager.dart';
import 'package:gourmet_go/screens/CustomerScreens/cart_screen.dart';

/// A self-contained cart icon button with an animated red badge showing
/// the total item count from [CartManager].
///
/// - Badge is hidden when the cart is empty.
/// - Shows "99+" for counts ≥ 100.
/// - Plays a spring bounce animation whenever the count changes.
/// - Navigates to [CartScreen] on tap.
/// - Only the badge sub-tree rebuilds on cart changes (via [ListenableBuilder]).
class CartIconBadge extends StatefulWidget {
  /// Tint colour for the shopping-cart icon. Defaults to the app primary.
  final Color? color;

  const CartIconBadge({super.key, this.color});

  @override
  State<CartIconBadge> createState() => _CartIconBadgeState();
}

class _CartIconBadgeState extends State<CartIconBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceCtrl;
  late final Animation<double> _scaleAnim;

  int _prevCount = CartManager().itemCount;

  @override
  void initState() {
    super.initState();

    _bounceCtrl = AnimationController(
      vsync: this,
      // total duration of one bounce cycle
      duration: const Duration(milliseconds: 400),
    );

    // Scale goes 1.0 → 1.45 → 0.85 → 1.0 (elastic pop feel)
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.45)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.45, end: 0.85)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.85, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 35,
      ),
    ]).animate(_bounceCtrl);

    // Listen directly to CartManager so we can detect count changes
    // and trigger the animation — without rebuilding this entire widget.
    CartManager().addListener(_onCartChanged);
  }

  @override
  void dispose() {
    CartManager().removeListener(_onCartChanged);
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _onCartChanged() {
    final newCount = CartManager().itemCount;
    if (newCount != _prevCount) {
      _prevCount = newCount;
      // Restart the bounce so repeated taps re-trigger it cleanly.
      _bounceCtrl
        ..reset()
        ..forward();
    }
  }

  void _navigateToCart(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  /// Returns the display string for the badge.
  String _badgeLabel(int count) => count >= 100 ? '99+' : '$count';

  @override
  Widget build(BuildContext context) {
    final iconColor =
        widget.color ?? Theme.of(context).colorScheme.primary;

    // ListenableBuilder rebuilds ONLY the Stack (badge + icon) on cart changes.
    return ListenableBuilder(
      listenable: CartManager(),
      builder: (context, _) {
        final count = CartManager().itemCount;
        final showBadge = count > 0;

        return IconButton(
          tooltip: showBadge ? 'Cart ($count items)' : 'Cart',
          onPressed: () => _navigateToCart(context),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Cart icon ──
              Icon(
                Icons.shopping_cart_outlined,
                color: iconColor,
              ),

              // ── Badge ──
              if (showBadge)
                Positioned(
                  // Sit slightly outside the top-right corner of the icon
                  top: -6,
                  right: -8,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: _BadgePill(
                      label: _badgeLabel(count),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The red pill/circle that displays the item count.
class _BadgePill extends StatelessWidget {
  final String label;

  const _BadgePill({required this.label});

  @override
  Widget build(BuildContext context) {
    // Use a slightly wider pill for "99+" vs single digit
    final isLong = label.length > 2;
    final minWidth = isLong ? 26.0 : 20.0;
    final fontSize = isLong ? 9.0 : 11.0;

    return Container(
      constraints: BoxConstraints(minWidth: minWidth, minHeight: 20),
      padding: EdgeInsets.symmetric(
        horizontal: isLong ? 4.0 : 2.0,
        vertical: 2.0,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40FF3B30),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1.1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
