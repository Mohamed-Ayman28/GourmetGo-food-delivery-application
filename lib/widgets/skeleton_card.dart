import 'package:flutter/material.dart';

/// A shimmer skeleton that mirrors the FoodItemCard layout.
/// Used during loading to show a placeholder grid.
class SkeletonCard extends StatefulWidget {
  const SkeletonCard({super.key});

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _anim = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8E8ED);
    final highlight =
        isDark ? const Color(0xFF3A3A3C) : const Color(0xFFF5F5F7);

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(22),
          ),
          child: ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
              transform: _SweepTransform(_anim.value),
            ).createShader(bounds),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image placeholder
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                    ),
                  ),
                ),
                // Text placeholders
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Bar(width: 100, height: 13, color: highlight),
                            const SizedBox(height: 6),
                            _Bar(width: double.infinity, height: 10, color: highlight),
                            const SizedBox(height: 4),
                            _Bar(width: 80, height: 10, color: highlight),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _Bar(width: 44, height: 16, color: highlight),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: highlight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const _Bar({
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

/// Shifts the gradient horizontally based on the animation value.
class _SweepTransform extends GradientTransform {
  final double value;
  const _SweepTransform(this.value);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * value * 0.5, 0, 0);
  }
}
