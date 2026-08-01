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
            return _buildDetailedOrderCard(context, doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildDetailedOrderCard(BuildContext context, String orderId, Map<String, dynamic> data) {
    final status = data['status']?.toString() ?? 'Pending';
    final statusColor = _getStatusColor(status);
    final createdAt = data['createdAt'] as Timestamp?;
    final dateStr = createdAt != null ? DateFormat('hh:mm a').format(createdAt.toDate()) : '--:--';
    final timeAgo = createdAt != null ? _formatTimeAgo(createdAt.toDate()) : '';
    
    final customerName = data['customerName'] ?? 'Unknown Customer';
    final phone = data['customerPhone'] ?? 'No Phone';
    final address = data['deliveryAddress'] ?? 'No Address Provided';
    
    final items = data['items'] as List<dynamic>? ?? [];
    double subtotal = 0;
    for (var i in items) {
      subtotal += (((i['price'] as num?) ?? 0) * ((i['quantity'] as num?) ?? 1));
    }
    // Infer delivery fee if not stored
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    final delivery = (total - subtotal) > 0 ? (total - subtotal) : 0.0; // Simplification
    final paymentMethod = data['paymentMethod']?.toString().toUpperCase() ?? 'CASH';

    final orderNotes = data['orderNotes']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Row ──
            Row(
              children: [
                Text(
                  '#${orderId.substring(0, 5).toUpperCase()}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.radio_button_checked, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(timeAgo, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (val) {
                    if (val == 'delete') _confirmDeleteOrder(context, orderId, data);
                  },
                  itemBuilder: (ctx) => [
                    if (status.toLowerCase() == 'delivered')
                      const PopupMenuItem(value: 'delete', child: Text('Delete Order', style: TextStyle(color: Colors.red))),
                  ],
                )
              ],
            ),
            const SizedBox(height: 16),
            
            // ── Customer Info ──
            Row(
              children: [
                const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(phone, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),
              ],
            ),
            
            if (orderNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes, size: 16, color: AppColors.warning.withValues(alpha: 0.8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Notes: $orderNotes',
                        style: TextStyle(
                          color: AppColors.warning.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // ── Items & Payment Boxes ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.grey),
                            SizedBox(width: 6),
                            Text('Items', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...items.take(3).map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${item['quantity']}x ${item['name']}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                        if (items.length > 3)
                          Text('+ ${items.length - 3} more items', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Subtotal: \$${subtotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            Text('Delivery: \$${delivery.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(
                              '\$${total.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.money, size: 16, color: Colors.grey),
                            SizedBox(width: 6),
                            Text('Payment', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          paymentMethod,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: paymentMethod == 'CASH' ? Colors.green.shade700 : Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // ── Action Buttons ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.phone_outlined, size: 18),
                    label: const Text('Call Customer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Open Maps'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _updateOrderStatus(context, orderId, status),
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: Text(
                  status.toLowerCase() == 'pending' ? 'Confirm Order' : 'Update Status',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateOrderStatus(BuildContext context, String orderId, String currentStatus) {
    // A simplified status progression for demonstration.
    // In a real app, you might show a bottom sheet with a list of statuses to pick from.
    String nextStatus = 'Pending';
    if (currentStatus.toLowerCase() == 'pending') { nextStatus = 'Preparing'; }
    else if (currentStatus.toLowerCase() == 'preparing') { nextStatus = 'Ready'; }
    else if (currentStatus.toLowerCase() == 'ready') { nextStatus = 'Delivering'; }
    else if (currentStatus.toLowerCase() == 'delivering') { nextStatus = 'Delivered'; }
    
    FirebaseFirestore.instance.collection('orders').doc(orderId).update({'status': nextStatus});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order marked as $nextStatus')));
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hrs ago';
    return '${diff.inDays} days ago';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return AppColors.primary; // Orange
      case 'preparing': return AppColors.info;
      case 'ready': return AppColors.warning;
      case 'delivering': return Colors.deepPurple;
      case 'delivered': return AppColors.success;
      case 'cancelled': return AppColors.error;
      default: return AppColors.neutral;
    }
  }

  void _confirmDeleteOrder(BuildContext context, String orderId, Map<String, dynamic> data) {
    if (data['status']?.toString().toLowerCase() != 'delivered') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only delivered orders can be deleted.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Order'),
        content: const Text('Are you sure you want to permanently delete this delivered order? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('orders').doc(orderId).delete();
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Order deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
