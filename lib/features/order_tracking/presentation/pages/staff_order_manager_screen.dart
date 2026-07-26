import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../consts/appColors.dart';
import '../../../../injection_container.dart';
import '../../../../screens/login_screen.dart';
import '../../domain/entities/order_entity.dart';
import '../cubit/staff_orders_cubit.dart';
import '../cubit/staff_orders_state.dart';

class StaffOrderManagerScreen extends StatelessWidget {
  const StaffOrderManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<StaffOrdersCubit>()..loadActiveOrders(),
      child: const _StaffDashboardView(),
    );
  }
}

class _StaffDashboardView extends StatefulWidget {
  const _StaffDashboardView();

  @override
  State<_StaffDashboardView> createState() => _StaffDashboardViewState();
}

class _StaffDashboardViewState extends State<_StaffDashboardView> {
  int _selectedFilterIndex = 0;

  static const List<String> _filters = [
    'All Orders',
    'Pending',
    'Preparing',
    'Assigned',
    'Out for Delivery',
    'Delivered',
  ];

  List<OrderEntity> _filterOrders(List<OrderEntity> orders) {
    switch (_selectedFilterIndex) {
      case 1:
        return orders.where((o) => o.status == OrderStatus.pending).toList();
      case 2:
        return orders.where((o) => o.status == OrderStatus.preparing).toList();
      case 3:
        return orders
            .where((o) =>
                o.status == OrderStatus.driverAssigned ||
                o.status == OrderStatus.driverAccepted ||
                o.status == OrderStatus.driverPickedUp)
            .toList();
      case 4:
        return orders.where((o) => o.status == OrderStatus.outForDelivery).toList();
      case 5:
        return orders.where((o) => o.status == OrderStatus.delivered).toList();
      default:
        return orders;
    }
  }

  int _countPending(List<OrderEntity> orders) =>
      orders.where((o) => o.status == OrderStatus.pending).length;
  int _countPreparing(List<OrderEntity> orders) =>
      orders.where((o) => o.status == OrderStatus.preparing).length;
  int _countAssigned(List<OrderEntity> orders) => orders
      .where((o) =>
          o.status == OrderStatus.driverAssigned ||
          o.status == OrderStatus.driverAccepted ||
          o.status == OrderStatus.driverPickedUp)
      .length;
  int _countOutForDelivery(List<OrderEntity> orders) =>
      orders.where((o) => o.status == OrderStatus.outForDelivery).length;
  int _countDelivered(List<OrderEntity> orders) =>
      orders.where((o) => o.status == OrderStatus.delivered).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppColors.textPrimary),
          onPressed: () {},
        ),
        title: const Text(
          'Staff Order Manager',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.textPrimary),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined, color: AppColors.textPrimary),
            onPressed: () {},
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                onPressed: () {},
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.deepOrange,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '6',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textPrimary),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: BlocListener<StaffOrdersCubit, StaffOrdersState>(
        listener: (context, state) {
          if (state is StaffOrdersLoaded && state.actionError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.actionError!),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.read<StaffOrdersCubit>().clearActionError();
          }
        },
        child: BlocBuilder<StaffOrdersCubit, StaffOrdersState>(
          builder: (context, state) {
            if (state is StaffOrdersLoading || state is StaffOrdersInitial) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (state is StaffOrdersError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'Error: ${state.message}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          context.read<StaffOrdersCubit>().loadActiveOrders(),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (state is StaffOrdersLoaded) {
              final allOrders = state.orders;
              final filteredOrders = _filterOrders(allOrders);

              return Column(
                children: [
                  const SizedBox(height: 12),
                  // ── Top Metric Cards Row ──
                  _buildMetricsRow(allOrders),

                  const SizedBox(height: 12),
                  // ── Filter Pills Row ──
                  _buildFilterPills(allOrders),

                  const SizedBox(height: 12),

                  // ── Orders List ──
                  Expanded(
                    child: filteredOrders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox_outlined,
                                    size: 56, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  'No ${_filters[_selectedFilterIndex].toLowerCase()} orders',
                                  style: TextStyle(
                                      fontSize: 15, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: filteredOrders.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              return _StaffOrderCard(order: filteredOrders[index]);
                            },
                          ),
                  ),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildMetricsRow(List<OrderEntity> orders) {
    final pending = _countPending(orders);
    final preparing = _countPreparing(orders);
    final assigned = _countAssigned(orders);
    final outForDelivery = _countOutForDelivery(orders);
    final delivered = _countDelivered(orders);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _metricCard('Pending', pending, Icons.description_outlined, Colors.orange, 1),
          const SizedBox(width: 10),
          _metricCard('Preparing', preparing, Icons.soup_kitchen_outlined, Colors.deepOrange, 2),
          const SizedBox(width: 10),
          _metricCard('Driver Assigned', assigned, Icons.two_wheeler_outlined, Colors.blue, 3),
          const SizedBox(width: 10),
          _metricCard('Out for Delivery', outForDelivery, Icons.share_location_outlined, Colors.purple, 4),
          const SizedBox(width: 10),
          _metricCard('Delivered', delivered, Icons.check_circle_outline, Colors.green, 5),
        ],
      ),
    );
  }

  Widget _metricCard(String title, int count, IconData icon, Color color, int filterIndex) {
    final isSelected = _selectedFilterIndex == filterIndex;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilterIndex = filterIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPills(List<OrderEntity> orders) {
    final counts = [
      orders.length,
      _countPending(orders),
      _countPreparing(orders),
      _countAssigned(orders),
      _countOutForDelivery(orders),
      _countDelivered(orders),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = _selectedFilterIndex == index;
          final label = '${_filters[index]} (${counts[index]})';

          return GestureDetector(
            onTap: () => setState(() => _selectedFilterIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Order Card Widget ───────────────────────────────────────────────────────

class _StaffOrderCard extends StatelessWidget {
  final OrderEntity order;

  const _StaffOrderCard({required this.order});

  Color get _statusColor => order.status.uiColor;

  String _formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    final hasDriver = order.driverName != null && order.driverName!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Accent Line
              Container(width: 4.5, color: _statusColor),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header Row: Order Number + Status Pill + Time ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.orderNumber.isNotEmpty
                                ? order.orderNumber
                                : '#${order.id.substring(0, 5).toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasDriver
                                      ? Icons.two_wheeler
                                      : Icons.radio_button_checked,
                                  size: 14,
                                  color: _statusColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  order.status.stepString,
                                  style: TextStyle(
                                    color: _statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatTime(order.createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                _timeAgo(order.createdAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert,
                                color: Colors.grey.shade600, size: 20),
                            onSelected: (val) {
                              if (val == 'cancel') {
                                context
                                    .read<StaffOrdersCubit>()
                                    .updateOrderStatus(
                                        order.id, OrderStatus.cancelled);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'cancel',
                                child: Text('Cancel Order',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ── Main Body Row: Customer & Address Details + Driver Box ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Details Column
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Customer Name & Phone
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline,
                                        size: 16, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        order.customerName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.phone_outlined,
                                        size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      order.customerPhone,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Address
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 16, color: Colors.deepOrange),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${order.customerAddress}${_formatBuildingDetails(order)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade800,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                if (order.deliveryNotes != null &&
                                    order.deliveryNotes!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.assignment_outlined,
                                          size: 14, color: Colors.blue),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Driver Notes: ${order.deliveryNotes}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                            color: Colors.blue.shade900,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Right Driver Info Box (if assigned)
                          if (hasDriver) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F8FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.blue.shade100, width: 1),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Driver',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        _buildDriverAvatar(order.driverPhotoUrl),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                order.driverName!,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                'Motorcycle',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Online',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green.shade800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ── Items Summary + Payment Cards Row ──
                      Row(
                        children: [
                          // Items Box
                          Expanded(
                            flex: 3,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.shopping_bag_outlined,
                                          size: 14, color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Items',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    order.itemsSummary,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Subtotal: \$${order.subtotal.toStringAsFixed(2)}',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600),
                                      ),
                                      Text(
                                        'Delivery: \$${order.deliveryFee.toStringAsFixed(2)}',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Total:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '\$${order.totalAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.deepOrange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Payment Box
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        order.paymentMethod.toLowerCase() ==
                                                'cash'
                                            ? Icons.payments_outlined
                                            : Icons.credit_card_outlined,
                                        size: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Payment',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    order.paymentMethod.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: order.paymentMethod.toLowerCase() ==
                                              'cash'
                                          ? Colors.green.shade700
                                          : Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ── Action Buttons Section (2-Row Layout) ──
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _smallActionButton(
                                  icon: Icons.phone_outlined,
                                  label: 'Call Customer',
                                  onTap: () => _callPhone(order.customerPhone),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _smallActionButton(
                                  icon: Icons.map_outlined,
                                  label: 'Open Maps',
                                  onTap: () => _openMaps(
                                    order.customerLat,
                                    order.customerLng,
                                    order.customerAddress,
                                  ),
                                ),
                              ),
                              if (hasDriver) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _smallActionButton(
                                    icon: Icons.chat_bubble_outline_rounded,
                                    label: 'Chat Driver',
                                    onTap: () =>
                                        _callPhone(order.driverPhone ?? ''),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (order.status != OrderStatus.delivered &&
                              order.status != OrderStatus.cancelled) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: _buildPrimaryWorkflowButton(context),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 38,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14, color: AppColors.textPrimary),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryWorkflowButton(BuildContext context) {
    final cubit = context.read<StaffOrdersCubit>();

    switch (order.status) {
      case OrderStatus.pending:
        return SizedBox(
          height: 38,
          child: ElevatedButton.icon(
            onPressed: () =>
                cubit.updateOrderStatus(order.id, OrderStatus.confirmed),
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Confirm Order',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );

      case OrderStatus.confirmed:
        return SizedBox(
          height: 38,
          child: ElevatedButton.icon(
            onPressed: () =>
                cubit.updateOrderStatus(order.id, OrderStatus.preparing),
            icon: const Icon(Icons.soup_kitchen_outlined, size: 16),
            label: const Text('Start Preparing',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );

      case OrderStatus.preparing:
        return SizedBox(
          height: 38,
          child: ElevatedButton.icon(
            onPressed: () => _showAssignDriverDialog(context),
            icon: const Icon(Icons.person_add_alt_1, size: 16),
            label: const Text('Assign Driver',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );

      case OrderStatus.driverAssigned:
      case OrderStatus.driverAccepted:
      case OrderStatus.driverPickedUp:
        return SizedBox(
          height: 38,
          child: ElevatedButton.icon(
            onPressed: () =>
                cubit.updateOrderStatus(order.id, OrderStatus.outForDelivery),
            icon: const Icon(Icons.two_wheeler, size: 16),
            label: const Text('Out for Delivery',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );

      case OrderStatus.outForDelivery:
        return SizedBox(
          height: 38,
          child: ElevatedButton.icon(
            onPressed: () =>
                cubit.updateOrderStatus(order.id, OrderStatus.delivered),
            icon: const Icon(Icons.task_alt_rounded, size: 16),
            label: const Text('Mark Delivered',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );

      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDriverAvatar(String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(photoUrl),
      );
    }
    return const CircleAvatar(
      radius: 18,
      backgroundColor: Colors.blue,
      child: Icon(Icons.person, color: Colors.white, size: 18),
    );
  }

  String _formatBuildingDetails(OrderEntity order) {
    final parts = <String>[];
    if (order.buildingNumber != null && order.buildingNumber!.isNotEmpty) {
      parts.add('Bldg ${order.buildingNumber}');
    }
    if (order.floor != null && order.floor!.isNotEmpty) {
      parts.add('Fl ${order.floor}');
    }
    if (order.apartment != null && order.apartment!.isNotEmpty) {
      parts.add('Apt ${order.apartment}');
    }
    if (order.landmark != null && order.landmark!.isNotEmpty) {
      parts.add('Near ${order.landmark}');
    }
    if (parts.isEmpty) return '';
    return ' (${parts.join(', ')})';
  }

  void _callPhone(String phone) {
    if (phone.isNotEmpty) {
      launchUrl(Uri.parse('tel:$phone'));
    }
  }

  void _openMaps(double lat, double lng, String address) {
    final query = (lat != 0 && lng != 0) ? '$lat,$lng' : Uri.encodeComponent(address);
    launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$query'));
  }

  void _showAssignDriverDialog(BuildContext context) {
    final cubit = context.read<StaffOrdersCubit>();
    cubit.fetchAvailableDrivers();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return BlocProvider.value(
          value: cubit,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: Colors.white,
            elevation: 10,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delivery_dining_rounded, color: AppColors.primary, size: 36),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Assign Available Driver',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  BlocBuilder<StaffOrdersCubit, StaffOrdersState>(
                    builder: (ctx, state) {
                      if (state is StaffOrdersLoaded) {
                        if (state.isLoadingDrivers) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: Center(
                              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
                            ),
                          );
                        }

                        final drivers = state.availableDrivers;
                        if (drivers.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'No available drivers found at the moment (drivers may be busy or offline).',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 14),
                            ),
                          );
                        }

                        return ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: drivers.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final driver = drivers[index];
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  leading: CircleAvatar(
                                    radius: 22,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                    child: const Icon(Icons.person, color: AppColors.primary, size: 20),
                                  ),
                                  title: Text(
                                    driver['name'] ?? 'Driver',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      driver['phone'] ?? '', 
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    ),
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () {
                                      cubit.assignDriver(order.id, driver['id']);
                                      Navigator.pop(dialogCtx);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                    child: const Text('Assign', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
