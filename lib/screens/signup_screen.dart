import 'package:gourmet_go/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'CustomerScreens/home_screen.dart';
import 'AdminScreens/dashboard_screen.dart';
import '../features/order_tracking/presentation/pages/staff_order_manager_screen.dart';
import '../features/order_tracking/presentation/pages/driver_dashboard_screen.dart';
import '../widgets/auth_widget.dart';
import '../services/social_auth_service.dart';
import 'email_verification/email_verification_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final SocialAuthService _socialAuthService = SocialAuthService();
  bool _isLoading = false;

  bool _agreeToTerms = false;
  String? _emailError;
  String? _passwordError;

  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeIn));
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _navigateForRole(String role, String uid) {
    if (!mounted) return;
    if (role == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
    } else if (role == 'staff') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StaffOrderManagerScreen()),
      );
    } else if (role == 'driver') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DriverDashboardScreen(driverId: uid)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  Future<void> _handleSocialSignUp(
      Future<SocialAuthResult> Function() authMethod) async {
    setState(() => _isLoading = true);
    try {
      final result = await authMethod();
      if (!mounted) return;

      switch (result.status) {
        case SocialAuthStatus.success:
          if (result.user != null) {
            _navigateForRole(result.role ?? 'customer', result.user!.uid);
          }
          break;

        case SocialAuthStatus.accountAlreadyExists:
          CustomSnackBar.show(context, message: result.message ?? 'Account already registered. Logging you in...', type: SnackBarType.success);
          if (result.user != null) {
            _navigateForRole(result.role ?? 'customer', result.user!.uid);
          }
          break;

        case SocialAuthStatus.cancelled:
          break;

        case SocialAuthStatus.accountNotFound:
        case SocialAuthStatus.error:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Sign-up failed.'),
            ),
          );
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Validates email and password, returning true when both are valid.
  bool _validate() {
    String? emailErr;
    String? passErr;

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      emailErr = 'Email is required.';
    } else if (!email.contains('@')) {
      emailErr = 'Please enter a valid email address.';
    }

    final password = _passwordController.text;
    if (password.isEmpty) {
      passErr = 'Password is required.';
    } else if (password.length < 8) {
      passErr = 'Password must be at least 8 characters.';
    }

    setState(() {
      _emailError = emailErr;
      _passwordError = passErr;
    });

    return emailErr == null && passErr == null;
  }

  Future<void> _onSignUp() async {
    if (_validate()) {
      setState(() => _isLoading = true);
      try {
        final cred =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (cred.user != null) {
          // Store user with emailVerified: false
          await FirebaseFirestore.instance
              .collection('users')
              .doc(cred.user!.uid)
              .set({
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'role': 'customer',
            'emailVerified': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Send verification email via Firebase Auth (free, no Cloud Functions needed)
          try {
            await cred.user!.sendEmailVerification();
          } catch (_) {
            // Even if email send fails, proceed to verification screen
            // where the user can retry with the resend button
          }

          if (!mounted) return;

          // Navigate to email verification screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => EmailVerificationScreen(
                email: _emailController.text.trim(),
                uid: cred.user!.uid,
              ),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Sign up failed')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AuthHeader(variant: AuthHeaderVariant.inline),
                  const SizedBox(height: 28),

                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      text: 'Start your ',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF777777),
                      ),
                      children: [
                        const TextSpan(
                          text: 'culinary journey',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF555555),
                          ),
                        ),
                        const TextSpan(text: ' with us today.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF5722),
                        ),
                      ),
                    ),

                  // Full Name field
                  const AuthFieldLabel('Full Name'),
                  const SizedBox(height: 8),
                  AuthInputField(
                    controller: _nameController,
                    hint: 'Enter your full name',
                    prefixIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: 20),

                  const AuthFieldLabel('Email Address'),
                  const SizedBox(height: 8),
                  AuthInputField(
                    controller: _emailController,
                    hint: 'email@example.com',
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    errorText: _emailError,
                  ),
                  const SizedBox(height: 20),

                  const AuthFieldLabel('Password'),
                  const SizedBox(height: 8),
                  AuthPasswordField(
                    controller: _passwordController,
                    hint: 'Min. 8 characters',
                    showPrefixIcon: true,
                    errorText: _passwordError,
                  ),
                  const SizedBox(height: 20),

                  // Terms & Conditions checkbox
                  _TermsCheckbox(
                    value: _agreeToTerms,
                    onChanged: (v) => setState(() => _agreeToTerms = v),
                  ),
                  const SizedBox(height: 28),

                  AuthPrimaryButton(label: 'Sign Up', onTap: _onSignUp),
                  const SizedBox(height: 24),

                  const AuthDivider(label: 'or continue with'),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: AuthSocialButton(
                          label: 'Google',
                          icon: Icons.g_mobiledata,
                          iconColor: const Color(0xFFDB4437),
                          onTap: _isLoading
                              ? null
                              : () => _handleSocialSignUp(
                                    () => _socialAuthService.signInWithGoogle(
                                      isSignUp: true,
                                    ),
                                  ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: AuthSocialButton(
                          label: 'Apple',
                          icon: Icons.apple,
                          iconColor: Colors.black,
                          onTap: _isLoading
                              ? null
                              : () => _handleSocialSignUp(
                                    () => _socialAuthService.signInWithApple(
                                      isSignUp: true,
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  AuthFooterLink(
                    prefixText: 'Already have an account? ',
                    actionText: 'Log in',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: value ? const Color(0xFFFF5722) : Colors.white,
              border: Border.all(
                color: value
                    ? const Color(0xFFFF5722)
                    : const Color(0xFFCCCCCC),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: value
                ? const Icon(Icons.check, color: Colors.white, size: 12)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: const TextSpan(
                text: 'I agree to the ',
                style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
                children: [
                  TextSpan(
                    text: 'Terms of Service',
                    style: TextStyle(
                      color: Color(0xFFFF5722),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(
                      color: Color(0xFFFF5722),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
