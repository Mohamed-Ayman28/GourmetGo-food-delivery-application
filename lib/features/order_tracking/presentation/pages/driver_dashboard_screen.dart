import 'package:gourmet_go/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../consts/appColors.dart';
import '../../../../injection_container.dart';
import '../../../../screens/login_screen.dart';
import '../../domain/entities/order_entity.dart';
import '../cubit/driver_orders_cubit.dart';
import '../cubit/driver_orders_state.dart';
import 'driver_navigation_screen.dart';

class DriverDashboardScreen extends StatelessWidget {
  final String driverId;

  const DriverDashboardScreen({
    super.key,
    required this.driverId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DriverOrdersCubit>()..loadDriverOrders(driverId),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          title: const Text(
            'Driver Dashboard',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
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
        body: BlocListener<DriverOrdersCubit, DriverOrdersState>(
          listener: (context, state) {
            if (state is DriverOrdersError) {
              CustomSnackBar.show(context, message: state.message, type: SnackBarType.error);
            }
          },
          child: BlocBuilder<DriverOrdersCubit, DriverOrdersState>(
            builder: (context, state) {
              if (state is DriverOrdersLoading || state is DriverOrdersInitial) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              if (state is DriverOrdersError && state is! DriverOrdersLoaded) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text('Error: ${state.message}'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => context.read<DriverOrdersCubit>().loadDriverOrders(driverId),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (state is DriverOrdersLoaded) {
                final orders = state.orders;
                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.two_wheeler_rounded, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text(
                          'No assigned orders right now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Available orders assigned by staff will appear here instantly.',
                          style: TextStyle(fontSize: 12, color: AppColors.textLight),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _DriverOrderCard(order: order);
                  },
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}

class _DriverOrderCard extends StatelessWidget {
  final OrderEntity order;

  const _DriverOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DriverOrdersCubit>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order ${order.orderNumber.isNotEmpty ? order.orderNumber : '#${order.id.substring(0, 5).toUpperCase()}'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: order.status.uiColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.status.stepString,
                  style: TextStyle(
                    color: order.status.uiColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),

          // Restaurant Info
          Row(
            children: [
              const Icon(Icons.store_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.restaurantName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Customer Info & Delivery Address
          Row(
            children: [
              const Icon(Icons.person_rounded, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 8),
              Text(
                order.customerName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const Spacer(),
              Text(
                order.customerPhone,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.customerAddress,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Items: ${order.itemsSummary}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),

          // Action Workflow Button
          // Steps: Accept -> Pick Up -> Start Delivery -> Deliver
          _buildDriverActionButton(context, cubit),
        ],
      ),
    );
  }

  Widget _buildDriverActionButton(BuildContext context, DriverOrdersCubit cubit) {
    switch (order.status) {
      case OrderStatus.driverAssigned:
        return SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: () => cubit.updateOrderStatus(order.id, OrderStatus.driverAccepted),
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Accept Delivery', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );

      case OrderStatus.driverAccepted:
        return SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: () => cubit.updateOrderStatus(order.id, OrderStatus.driverPickedUp),
            icon: const Icon(Icons.shopping_bag_rounded),
            label: const Text('Pick Up Order', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );

      case OrderStatus.driverPickedUp:
      case OrderStatus.outForDelivery:
        return SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverNavigationScreen(
                    order: order,
                    driverId: FirebaseAuth.instance.currentUser?.uid ?? '',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.navigation_rounded),
            label: const Text('Go to Customer', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
