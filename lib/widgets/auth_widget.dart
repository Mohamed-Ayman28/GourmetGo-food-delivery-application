import 'package:flutter/material.dart';

abstract final class _AuthTokens {
  static const Color brand = Color(0xFFFF5722);
  static const Color brandLight = Color(0xFFFF8C42);
  static const Color brandDeep = Color(0xFFFF4500);
  static const Color surface = Color(0xFFFAFAFA);
  static const Color border = Color(0xFFE8E8E8);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF888888);
  static const Color textMuted = Color(0xFF444444);
  static const Color hint = Color(0xFFBBBBBB);
  static const Color error = Color(0xFFE53935);

  static const double radius = 12.0;
  static const double radiusButton = 14.0;
}

enum AuthHeaderVariant { banner, inline }

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, this.variant = AuthHeaderVariant.banner});

  final AuthHeaderVariant variant;

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      AuthHeaderVariant.banner => _BannerHeader(),
      AuthHeaderVariant.inline => _InlineHeader(),
    };
  }
}

class _BannerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 120,
      color: const Color(0xFFFFDDD0),
      child: const Center(
        child: Text(
          'GourmetGo',
          style: TextStyle(
            color: _AuthTokens.brand,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _InlineHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.restaurant, color: _AuthTokens.brand, size: 22),
        SizedBox(width: 8),
        Text(
          'GourmetGo',
          style: TextStyle(
            color: _AuthTokens.brand,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class AuthInputField extends StatelessWidget {
  const AuthInputField({
    super.key,
    required this.controller,
    required this.hint,
    this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.errorText,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? prefixIcon;
  final TextInputType keyboardType;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: _AuthTokens.surface,
            borderRadius: BorderRadius.circular(_AuthTokens.radius),
            border: Border.all(
              color: hasError ? _AuthTokens.error : _AuthTokens.border,
              width: hasError ? 1.5 : 1.0,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontSize: 14,
              color: _AuthTokens.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: _AuthTokens.hint, fontSize: 14),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: const Color(0xFFAAAAAA), size: 20)
                  : null,
              border: InputBorder.none,
              contentPadding: prefixIcon != null
                  ? const EdgeInsets.symmetric(vertical: 15)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          _ErrorRow(message: errorText!),
        ],
      ],
    );
  }
}

class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.controller,
    this.hint = 'Password',
    this.showPrefixIcon = false,
    this.errorText,
  });

  final TextEditingController controller;
  final String hint;

  final bool showPrefixIcon;
  final String? errorText;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: _AuthTokens.surface,
            borderRadius: BorderRadius.circular(_AuthTokens.radius),
            border: Border.all(
              color: hasError ? _AuthTokens.error : _AuthTokens.border,
              width: hasError ? 1.5 : 1.0,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            obscureText: _obscure,
            style: const TextStyle(
              fontSize: 14,
              color: _AuthTokens.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(color: _AuthTokens.hint, fontSize: 14),
              prefixIcon: widget.showPrefixIcon
                  ? const Icon(
                      Icons.lock_outline,
                      color: Color(0xFFAAAAAA),
                      size: 20,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: widget.showPrefixIcon
                  ? const EdgeInsets.symmetric(vertical: 15)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              suffixIcon: GestureDetector(
                onTap: () => setState(() => _obscure = !_obscure),
                child: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          _ErrorRow(message: widget.errorText!),
        ],
      ],
    );
  }
}

class AuthPrimaryButton extends StatefulWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _ctrl,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_AuthTokens.brandLight, _AuthTokens.brandDeep],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(_AuthTokens.radiusButton),
            boxShadow: [
              BoxShadow(
                color: _AuthTokens.brand.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthSocialButton extends StatelessWidget {
  const AuthSocialButton({
    super.key,
    required this.label,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_AuthTokens.radius),
          border: Border.all(color: _AuthTokens.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: _AuthTokens.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, this.label = 'OR CONTINUE WITH'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: _AuthTokens.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const Expanded(child: Divider(color: _AuthTokens.divider)),
      ],
    );
  }
}

class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.prefixText,
    required this.actionText,
    required this.onTap,
  });

  final String prefixText;
  final String actionText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: RichText(
          text: TextSpan(
            text: prefixText,
            style: const TextStyle(
              fontSize: 14,
              color: _AuthTokens.textSecondary,
            ),
            children: [
              TextSpan(
                text: actionText,
                style: const TextStyle(
                  color: _AuthTokens.brand,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _AuthTokens.textMuted,
      ),
    );
  }
}

class AuthFoodStrip extends StatelessWidget {
  const AuthFoodStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_AuthTokens.radius),
      child: Container(
        height: 80,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_AuthTokens.brandLight, _AuthTokens.brand],
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Icon(Icons.lunch_dining, color: Colors.white, size: 36),
            Icon(Icons.local_pizza, color: Colors.white, size: 36),
            Icon(Icons.ramen_dining, color: Colors.white, size: 36),
            Icon(Icons.fastfood, color: Colors.white, size: 36),
          ],
        ),
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: _AuthTokens.error, size: 14),
        const SizedBox(width: 4),
        Text(
          message,
          style: const TextStyle(fontSize: 12, color: _AuthTokens.error),
        ),
      ],
    );
  }
}
