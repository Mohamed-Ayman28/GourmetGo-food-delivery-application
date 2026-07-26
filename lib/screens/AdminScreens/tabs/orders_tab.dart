import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../consts/appColors.dart';

class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No orders found.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final createdAt = data['createdAt'] as Timestamp?;
            final dateStr = createdAt != null ? DateFormat('MMM dd, yyyy - hh:mm a').format(createdAt.toDate()) : 'Unknown Date';
            
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(data['status'] ?? ''),
                  child: const Icon(Icons.receipt, color: Colors.white),
                ),
                title: Text('Order #${doc.id.substring(0, 8).toUpperCase()}'),
                subtitle: Text('$dateStr\nTotal: \$${data['total']} - ${data['status']?.toString().toUpperCase()}'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showOrderDetails(context, doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return AppColors.warning;
      case 'preparing': return AppColors.info;
      case 'ready': return AppColors.primary;
      case 'delivering': return Colors.deepPurple;
      case 'delivered': return AppColors.success;
      case 'cancelled': return AppColors.error;
      default: return AppColors.neutral;
    }
  }

  void _showOrderDetails(BuildContext context, String orderId, Map<String, dynamic> data) {
    final items = data['items'] as List<dynamic>? ?? [];
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Order Details - #${orderId.substring(0, 8).toUpperCase()}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: ${data['status']?.toString().toUpperCase()}', style: TextStyle(color: _getStatusColor(data['status'] ?? ''), fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Customer: ${data['customerName'] ?? 'N/A'}'),
              Text('Phone: ${data['customerPhone'] ?? 'N/A'}'),
              Text('Address: ${data['deliveryAddress'] ?? 'N/A'}'),
              const Divider(),
              const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${item['quantity']}x ${item['name']}'),
                    Text('\$${(item['price'] * item['quantity']).toStringAsFixed(2)}'),
                  ],
                ),
              )).toList(),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('\$${data['total']?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
