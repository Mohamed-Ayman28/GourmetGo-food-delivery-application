import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../consts/appColors.dart';

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Business Overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 800;
              final crossAxisCount = isDesktop ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.9,
                children: [
                  _buildKpiCard(
                    title: 'Total Revenue',
                    icon: Icons.attach_money,
                    color: AppColors.success,
                    stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'delivered').snapshots(),
                    valueBuilder: (snapshot) {
                      double revenue = 0;
                      for (var doc in snapshot.docs) {
                        revenue += (doc.data() as Map<String, dynamic>)['total'] ?? 0;
                      }
                      return '\$${revenue.toStringAsFixed(2)}';
                    },
                  ),
                  _buildKpiCard(
                    title: 'Total Orders',
                    icon: Icons.receipt_long,
                    color: AppColors.primary,
                    stream: FirebaseFirestore.instance.collection('orders').snapshots(),
                    valueBuilder: (snapshot) => snapshot.docs.length.toString(),
                  ),
                  _buildKpiCard(
                    title: 'Customers',
                    icon: Icons.people,
                    color: AppColors.info,
                    stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'customer').snapshots(),
                    valueBuilder: (snapshot) => snapshot.docs.length.toString(),
                  ),
                  _buildKpiCard(
                    title: 'Drivers',
                    icon: Icons.delivery_dining,
                    color: AppColors.warning,
                    stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'driver').snapshots(),
                    valueBuilder: (snapshot) => snapshot.docs.length.toString(),
                  ),
                  _buildKpiCard(
                    title: 'Staff',
                    icon: Icons.admin_panel_settings,
                    color: AppColors.tertiary,
                    stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'staff').snapshots(),
                    valueBuilder: (snapshot) => snapshot.docs.length.toString(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required IconData icon,
    required Color color,
    required Stream<QuerySnapshot> stream,
    required String Function(QuerySnapshot) valueBuilder,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                if (snapshot.hasError) {
                  return const Text('Error', style: TextStyle(color: AppColors.error));
                }
                final value = valueBuilder(snapshot.data!);
                return Text(
                  value,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
