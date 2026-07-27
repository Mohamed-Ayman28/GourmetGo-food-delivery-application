import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gourmet_go/widgets/custom_snackbar.dart';
import 'signup_screen.dart';
import '../widgets/auth_widget.dart';
import 'CustomerScreens/home_screen.dart';
import 'AdminScreens/dashboard_screen.dart';
import '../features/order_tracking/presentation/pages/staff_order_manager_screen.dart';
import '../features/order_tracking/presentation/pages/driver_dashboard_screen.dart';
import '../services/social_auth_service.dart';
import 'forgot_password/forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final SocialAuthService _socialAuthService = SocialAuthService();
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _navigateToSignup() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SignupScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
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

  Future<void> _handleSocialAuth(Future<SocialAuthResult> Function() authMethod) async {
    setState(() => _isLoading = true);
    try {
      final result = await authMethod();
      if (!mounted) return;

      switch (result.status) {
        case SocialAuthStatus.success:
        case SocialAuthStatus.accountAlreadyExists:
          if (result.role != null && result.user != null) {
            _navigateForRole(result.role!, result.user!.uid);
          }
          break;

        case SocialAuthStatus.accountNotFound:
          CustomSnackBar.show(
            context,
            message: result.message ?? 'Account does not exist! Please sign up first.',
            type: SnackBarType.error,
          );
          // Note: Since CustomSnackBar doesn't support an Action button natively yet,
          // the user will need to manually tap Sign Up. If needed we can add action support to CustomSnackBar.
          break;

        case SocialAuthStatus.cancelled:
          break;

        case SocialAuthStatus.error:
          CustomSnackBar.show(
            context,
            message: result.message ?? 'Authentication failed.',
            type: SnackBarType.error,
          );
          break;
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Error: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F0),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AuthHeader(variant: AuthHeaderVariant.banner),
            FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome Back!',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your favorite meals are just a few taps away.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF888888),
                        ),
                      ),
                      const SizedBox(height: 30),

                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF5722),
                            ),
                          ),
                        ),

                      AuthInputField(
                        controller: _emailController,
                        hint: 'Email Address',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),

                      AuthPasswordField(
                        controller: _passwordController,
                        hint: 'Password',
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: Color(0xFFFF5722),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      AuthPrimaryButton(
                        label: 'Login',
                        onTap: () async {
                          final email = _emailController.text.trim();
                          final password = _passwordController.text.trim();
                          if (email.isEmpty || password.isEmpty) {
                            CustomSnackBar.show(
                              context,
                              message: 'Please enter email and password',
                              type: SnackBarType.error,
                            );
                            return;
                          }
                          try {
                            final cred = await FirebaseAuth.instance
                                .signInWithEmailAndPassword(
                              email: email,
                              password: password,
                            );
                            if (cred.user != null) {
                              final docRef = FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(cred.user!.uid);
                              final doc = await docRef.get();
                              String role = 'customer';
                              if (doc.exists) {
                                role = doc.data()?['role'] ?? 'customer';
                              }

                              // Ensure admin@gmail.com is set up with 'admin' role in Firestore
                              if (email.toLowerCase() == 'admin@gmail.com') {
                                role = 'admin';
                                await docRef.set({
                                  'name': 'Admin',
                                  'email': 'admin@gmail.com',
                                  'role': 'admin',
                                  'emailVerified': true,
                                  'createdAt': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true));
                              }

                              _navigateForRole(role, cred.user!.uid);
                            }
                          } on FirebaseAuthException catch (e) {
                            if (!mounted) return;
                            CustomSnackBar.show(
                              context,
                              message: e.message ?? 'Login failed',
                              type: SnackBarType.error,
                            );
                          } catch (e) {
                            if (!mounted) return;
                            CustomSnackBar.show(
                              context,
                              message: 'Error: $e',
                              type: SnackBarType.error,
                            );
                          }
                        },
                      ),

                      const SizedBox(height: 24),
                      const AuthDivider(),
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
                                  : () => _handleSocialAuth(
                                        () => _socialAuthService.signInWithGoogle(
                                          isSignUp: false,
                                        ),
                                      ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: AuthSocialButton(
                              label: 'Apple',
                              icon: Icons.apple,
                              iconColor: Colors.black,
                              onTap: _isLoading
                                  ? null
                                  : () => _handleSocialAuth(
                                        () => _socialAuthService.signInWithApple(
                                          isSignUp: false,
                                        ),
                                      ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

        
                      AuthFooterLink(
                        prefixText: "Don't have an account? ",
                        actionText: 'Sign Up',
                        onTap: _navigateToSignup,
                      ),

                      const SizedBox(height: 16),

                     
                      const AuthFoodStrip(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
