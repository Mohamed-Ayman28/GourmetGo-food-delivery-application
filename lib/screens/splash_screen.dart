import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'email_verification/email_verification_screen.dart';
import 'CustomerScreens/home_screen.dart';
import 'AdminScreens/dashboard_screen.dart';
import '../features/order_tracking/presentation/pages/staff_order_manager_screen.dart';
import '../features/order_tracking/presentation/pages/driver_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _animController.forward();

    Future.delayed(const Duration(seconds: 3), () async {
      final user = FirebaseAuth.instance.currentUser;
      Widget nextScreen = const LoginScreen();

      if (user != null) {
        try {
          // Reload to get latest email verification status
          await user.reload();
          final refreshedUser = FirebaseAuth.instance.currentUser;

          final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
          final doc = await docRef.get();
          String role = 'customer';
          if (doc.exists) {
            role = doc.data()?['role'] ?? 'customer';
          }

          if (user.email != null && user.email!.toLowerCase() == 'admin@gmail.com') {
            role = 'admin';
            if (!doc.exists || doc.data()?['role'] != 'admin') {
              await docRef.set({
                'name': 'Admin',
                'email': user.email,
                'role': 'admin',
                'emailVerified': true,
                'createdAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            }
          }

          // Guard: only require email verification for customers, not admin/staff/driver
          if (role == 'customer' &&
              refreshedUser != null &&
              !refreshedUser.emailVerified) {
            nextScreen = EmailVerificationScreen(
              email: user.email ?? '',
              uid: user.uid,
            );
          } else if (role == 'admin') {
            nextScreen = const AdminDashboardScreen();
          } else if (role == 'staff') {
            nextScreen = const StaffOrderManagerScreen();
          } else if (role == 'driver') {
            nextScreen = DriverDashboardScreen(driverId: user.uid);
          } else {
            nextScreen = const HomeScreen();
          }
        } catch (e) {
          // Fallback to login if error
        }
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => nextScreen,
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF6B2C), Color(0xFFFF4500)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Decorative fork & knife icon top-left
            Positioned(
              top: 60,
              left: 30,
              child: Opacity(
                opacity: 0.18,
                child: Icon(
                  Icons.restaurant,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),

            // Decorative pizza slice top-right
            Positioned(
              top: 80,
              right: 30,
              child: Opacity(
                opacity: 0.15,
                child: Icon(
                  Icons.local_pizza,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            ),

            // Decorative bowl bottom-right
            Positioned(
              bottom: 120,
              right: -20,
              child: Opacity(
                opacity: 0.12,
                child: Icon(
                  Icons.ramen_dining,
                  size: 120,
                  color: Colors.white,
                ),
              ),
            ),

            // Main content
            Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo Card
                    ScaleTransition(
                      scale: _scaleAnim,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.close, // X icon like in the design
                            color: const Color(0xFFFF5722),
                            size: 56,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // App name
                    const Text(
                      'GourmetGo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom tagline
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    // Dot indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Dot(active: true),
                        const SizedBox(width: 6),
                        _Dot(active: false),
                        const SizedBox(width: 6),
                        _Dot(active: false),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'DELIVERING EXCELLENCE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
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
}

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: active ? 20 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
