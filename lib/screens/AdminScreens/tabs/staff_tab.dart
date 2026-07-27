import 'package:gourmet_go/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../consts/appColors.dart';
import '../../../widgets/admin_widgets.dart';

class StaffTab extends StatefulWidget {
  const StaffTab({super.key});

  @override
  State<StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<StaffTab> {
  Future<void> _showAddEditStaffDialog([DocumentSnapshot? staffDoc]) async {
    final isEdit = staffDoc != null;
    final data = isEdit ? staffDoc.data() as Map<String, dynamic> : null;

    final nameController = TextEditingController(text: data?['name'] ?? '');
    final emailController = TextEditingController(text: data?['email'] ?? '');
    final phoneController = TextEditingController(text: data?['phone'] ?? '');
    final passwordController = TextEditingController();

    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AdminDialog(
            title: isEdit ? 'Edit Staff' : 'Add New Staff',
            isLoading: isLoading,
            saveText: isEdit ? 'Save Changes' : 'Create Staff',
            onCancel: () => Navigator.pop(ctx),
            onSave: () async {
              setState(() => isLoading = true);
              try {
                if (isEdit) {
                  await FirebaseFirestore.instance.collection('users').doc(staffDoc.id).update({
                    'name': nameController.text.trim(),
                    'phone': phoneController.text.trim(),
                  });
                } else {
                  final tempApp = await Firebase.initializeApp(name: 'temp', options: Firebase.app().options);
                  final cred = await FirebaseAuth.instanceFor(app: tempApp).createUserWithEmailAndPassword(
                    email: emailController.text.trim(),
                    password: passwordController.text.trim(),
                  );
                  if (cred.user != null) {
                    await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
                      'name': nameController.text.trim(),
                      'email': emailController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'role': 'staff',
                      'isActive': true,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  }
                  await tempApp.delete();
                }
                if (!mounted) return;
                Navigator.pop(ctx);
              } catch (e) {
                CustomSnackBar.show(context, message: 'Error: $e', type: SnackBarType.error);
              } finally {
                setState(() => isLoading = false);
              }
            },
            children: [
              AdminTextField(controller: nameController, label: 'Full Name', icon: Icons.person),
              AdminTextField(controller: emailController, label: 'Email Address', icon: Icons.email, enabled: !isEdit, keyboardType: TextInputType.emailAddress),
              AdminTextField(controller: phoneController, label: 'Phone Number', icon: Icons.phone, keyboardType: TextInputType.phone),
              if (!isEdit) AdminTextField(controller: passwordController, label: 'Password', icon: Icons.lock, isPassword: true),
            ],
          );
        },
      ),
    );
  }

  void _deleteStaff(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Staff'),
        content: const Text('Are you sure you want to delete this staff member?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('users').doc(id).delete();
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      CustomSnackBar.show(context, message: 'Password reset email sent!', type: SnackBarType.info);
    } catch (e) {
      CustomSnackBar.show(context, message: 'Error: $e', type: SnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditStaffDialog(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'staff').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No staff found.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final isActive = data['isActive'] ?? true;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(data['name'] ?? 'No Name'),
                  subtitle: Text('${data['email']}\nPhone: ${data['phone'] ?? 'N/A'}'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: isActive,
                        onChanged: (val) {
                          FirebaseFirestore.instance.collection('users').doc(doc.id).update({'isActive': val});
                        },
                      ),
                      PopupMenuButton<String>(
                        onSelected: (val) {
                          if (val == 'edit') _showAddEditStaffDialog(doc);
                          if (val == 'reset') _resetPassword(data['email']);
                          if (val == 'delete') _deleteStaff(doc.id);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'reset', child: Text('Reset Password')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
