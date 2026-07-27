import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gourmet_go/widgets/custom_snackbar.dart';
import 'package:gourmet_go/widgets/auth_widget.dart';
import 'package:gourmet_go/screens/CustomerScreens/home_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String uid;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.uid,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with TickerProviderStateMixin {
  bool _isResending = false;
  bool _isChecking = false;
  bool _isSuccess = false;

  int _countdown = 60;
  Timer? _countdownTimer;
  Timer? _autoCheckTimer;

  // Animations
  late AnimationController _envelopeController;
  late Animation<double> _envelopeBounce;
  late Animation<double> _envelopeFloat;

  late AnimationController _fadeSlideController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  late AnimationController _successController;
  late Animation<double> _successScale;
  late Animation<double> _successOpacity;

  @override
  void initState() {
    super.initState();

    // Envelope breathing animation
    _envelopeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _envelopeBounce = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _envelopeController, curve: Curves.easeInOut),
    );

    _envelopeFloat = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _envelopeController, curve: Curves.easeInOut),
    );

    // Page entrance animation
    _fadeSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeSlideController, curve: Curves.easeOut),
    );
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _fadeSlideController, curve: Curves.easeOutCubic),
    );
    _fadeSlideController.forward();

    // Success animation
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );
    _successOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.easeIn),
    );

    _startCountdown();
    _startAutoCheck();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _autoCheckTimer?.cancel();
    _envelopeController.dispose();
    _fadeSlideController.dispose();
    _successController.dispose();
    super.dispose();
  }

  String get _maskedEmail {
    final parts = widget.email.split('@');
    if (parts.length != 2 || parts[0].length < 2) return widget.email;
    final name = parts[0];
    final masked =
        '${name[0]}${'•' * (name.length - 2).clamp(1, 6)}${name[name.length - 1]}';
    return '$masked@${parts[1]}';
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  /// Periodically check if the user has clicked the email link
  void _startAutoCheck() {
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_isSuccess && !_isChecking) {
        _checkVerification(silent: true);
      }
    });
  }

  Future<void> _checkVerification({bool silent = false}) async {
    if (_isChecking || _isSuccess) return;

    setState(() => _isChecking = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        final refreshedUser = FirebaseAuth.instance.currentUser;

        if (refreshedUser != null && refreshedUser.emailVerified) {
          // Update Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.uid)
              .update({'emailVerified': true});

          if (!mounted) return;
          _onVerificationSuccess();
          return;
        }
      }

      if (!silent && mounted) {
        CustomSnackBar.show(
          context,
          message: 'Email not verified yet. Please check your inbox and click the link.',
          type: SnackBarType.warning,
        );
      }
    } catch (e) {
      if (!silent && mounted) {
        CustomSnackBar.show(
          context,
          message: 'Could not check verification status. Try again.',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _onVerificationSuccess() {
    _autoCheckTimer?.cancel();
    _countdownTimer?.cancel();
    _envelopeController.stop();

    setState(() => _isSuccess = true);
    _successController.forward();

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    });
  }

  Future<void> _resendVerification() async {
    if (_countdown > 0 || _isResending) return;

    setState(() => _isResending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        if (!mounted) return;
        CustomSnackBar.show(
          context,
          message: 'Verification email sent! Check your inbox.',
          type: SnackBarType.success,
        );
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Failed to send email. Please try again later.',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    // ─── Animated Envelope ───
                    if (!_isSuccess) _buildEnvelopeSection(),

                    const SizedBox(height: 36),

                    if (!_isSuccess) ...[
                      // ─── Title & Description ───
                      const Text(
                        'Check Your Email',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF888888),
                            height: 1.6,
                          ),
                          children: [
                            const TextSpan(
                                text:
                                    'We\'ve sent a verification link to\n'),
                            TextSpan(
                              text: _maskedEmail,
                              style: const TextStyle(
                                color: Color(0xFFFF5722),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(
                                text:
                                    '\n\nClick the link in the email to verify your account.'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // ─── Steps Indicator ───
                      _buildStepsSection(),

                      const SizedBox(height: 36),

                      // ─── Check Verification Button ───
                      _buildCheckButton(),

                      const SizedBox(height: 24),

                      // ─── Resend Section ───
                      _buildResendSection(),

                      const SizedBox(height: 36),

                      // ─── Bottom Hint ───
                      _buildBottomHint(),
                    ],

                    // ─── Success State ───
                    if (_isSuccess) _buildSuccessState(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnvelopeSection() {
    return AnimatedBuilder(
      animation: _envelopeController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _envelopeFloat.value),
          child: Transform.scale(
            scale: _envelopeBounce.value,
            child: child,
          ),
        );
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF8C42), Color(0xFFFF4500)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5722).withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 10,
              right: 10,
              child: Icon(
                Icons.auto_awesome,
                color: Colors.white.withValues(alpha: 0.2),
                size: 24,
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              child: Icon(
                Icons.auto_awesome,
                color: Colors.white.withValues(alpha: 0.15),
                size: 18,
              ),
            ),
            const Icon(
              Icons.mark_email_unread_rounded,
              color: Colors.white,
              size: 52,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE0D0)),
      ),
      child: Column(
        children: [
          _StepRow(
            number: '1',
            text: 'Open your email app',
            icon: Icons.email_outlined,
            isActive: true,
          ),
          const SizedBox(height: 12),
          const _StepDividerLine(),
          const SizedBox(height: 12),
          _StepRow(
            number: '2',
            text: 'Click the verification link',
            icon: Icons.touch_app_outlined,
            isActive: true,
          ),
          const SizedBox(height: 12),
          const _StepDividerLine(),
          const SizedBox(height: 12),
          _StepRow(
            number: '3',
            text: 'Come back here & tap "I\'ve Verified"',
            icon: Icons.check_circle_outline,
            isActive: false,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckButton() {
    if (_isChecking) {
      return const SizedBox(
        height: 54,
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF5722),
            strokeWidth: 3,
          ),
        ),
      );
    }

    return AuthPrimaryButton(
      label: 'I\'ve Verified My Email',
      onTap: () => _checkVerification(silent: false),
    );
  }

  Widget _buildResendSection() {
    return Column(
      children: [
        Text(
          'Didn\'t receive the email?',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 8),
        _isResending
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF5722),
                ),
              )
            : GestureDetector(
                onTap: _countdown == 0 ? _resendVerification : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _countdown == 0
                        ? const Color(0xFFFFF0EB)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _countdown == 0
                          ? const Color(0xFFFF5722)
                          : const Color(0xFFE0E0E0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_countdown > 0) ...[
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: _countdown / 60,
                                strokeWidth: 2,
                                backgroundColor: const Color(0xFFE0E0E0),
                                color: const Color(0xFFFF5722),
                              ),
                              Text(
                                '$_countdown',
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF888888),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Resend in ${_countdown}s',
                          style: const TextStyle(
                            color: Color(0xFF999999),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.refresh_rounded,
                          color: Color(0xFFFF5722),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Resend Email',
                          style: TextStyle(
                            color: Color(0xFFFF5722),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildBottomHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFF5722).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.tips_and_updates_rounded,
              color: Color(0xFFFF5722),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Check your spam folder if you don\'t see the email. We\'re also auto-checking in the background!',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF888888),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return FadeTransition(
      opacity: _successOpacity,
      child: ScaleTransition(
        scale: _successScale,
        child: Column(
          children: [
            const SizedBox(height: 40),

            // Success checkmark with particles
            SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ...List.generate(8, (i) {
                    final angle = (i * 45) * (pi / 180);
                    return Positioned(
                      left: 80 + cos(angle) * 65 - 4,
                      top: 80 + sin(angle) * 65 - 4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5722)
                              .withValues(alpha: 0.3 + (i % 3) * 0.2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF4CAF50).withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Email Verified!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Welcome to GourmetGo! Redirecting you...',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF888888),
              ),
            ),

            const SizedBox(height: 24),

            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF4CAF50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper Widgets ───────────────────────────────

class _StepRow extends StatelessWidget {
  final String number;
  final String text;
  final IconData icon;
  final bool isActive;

  const _StepRow({
    required this.number,
    required this.text,
    required this.icon,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [Color(0xFFFF8C42), Color(0xFFFF4500)],
                  )
                : null,
            color: isActive ? null : const Color(0xFFE0E0E0),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF999999),
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? const Color(0xFF333333)
                  : const Color(0xFF999999),
            ),
          ),
        ),
        Icon(
          icon,
          size: 20,
          color: isActive
              ? const Color(0xFFFF5722)
              : const Color(0xFFCCCCCC),
        ),
      ],
    );
  }
}

class _StepDividerLine extends StatelessWidget {
  const _StepDividerLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 15),
        Container(
          width: 2,
          height: 12,
          decoration: BoxDecoration(
            color: const Color(0xFFFFCCB8),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }
}
