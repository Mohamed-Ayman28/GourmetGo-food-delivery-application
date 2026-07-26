import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/menu_admin/data/datasources/menu_seeder.dart';
import '../login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _staffEmailController = TextEditingController();
  final _staffPasswordController = TextEditingController();
  
  final _driverEmailController = TextEditingController();
  final _driverPasswordController = TextEditingController();

  bool _isLoadingStaff = false;
  bool _isLoadingDriver = false;

  @override
  void dispose() {
    _staffEmailController.dispose();
    _staffPasswordController.dispose();
    _driverEmailController.dispose();
    _driverPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createUser(String email, String password, String role) async {
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    if (role == 'staff') {
      setState(() => _isLoadingStaff = true);
    } else {
      setState(() => _isLoadingDriver = true);
    }

    try {
      // NOTE: Using createUserWithEmailAndPassword on the client side 
      // will sign in the newly created user and sign out the admin.
      // In production, consider using Firebase Cloud Functions to create users without altering the auth state.
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
          'email': email,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$role user created successfully!')),
        );

        if (role == 'staff') {
          _staffEmailController.clear();
          _staffPasswordController.clear();
        } else {
          _driverEmailController.clear();
          _driverPasswordController.clear();
        }
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Authentication error occurred')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (role == 'staff') {
        setState(() => _isLoadingStaff = false);
      } else {
        setState(() => _isLoadingDriver = false);
      }
    }
  }

  Widget _buildAddUserSection({
    required String title,
    required String role,
    required TextEditingController emailController,
    required TextEditingController passwordController,
    required bool isLoading,
    required IconData icon,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xffA93500)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xffA93500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffA93500),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: isLoading
                    ? null
                    : () => _createUser(
                          emailController.text.trim(),
                          passwordController.text.trim(),
                          role,
                        ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text('Add $role'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Settings'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xffA93500),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Database Management',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seeding database...')));
                    await MenuSeeder.clearAndReseedMenu();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database seeded successfully!')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Re-seed Menu Database'),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'User Management',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildAddUserSection(
              title: 'Add Staff User',
              role: 'staff',
              emailController: _staffEmailController,
              passwordController: _staffPasswordController,
              isLoading: _isLoadingStaff,
              icon: Icons.admin_panel_settings,
            ),
            const SizedBox(height: 24),
            _buildAddUserSection(
              title: 'Add Driver User',
              role: 'driver',
              emailController: _driverEmailController,
              passwordController: _driverPasswordController,
              isLoading: _isLoadingDriver,
              icon: Icons.delivery_dining,
            ),
          ],
        ),
      ),
    );
  }
}
