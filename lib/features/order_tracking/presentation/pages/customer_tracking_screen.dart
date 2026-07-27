import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../../consts/appColors.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/order_entity.dart';
import '../cubit/customer_tracking_cubit.dart';
import '../cubit/customer_tracking_state.dart';
import '../../core/services/location_service.dart';

class CustomerTrackingScreen extends StatelessWidget {
  final String orderId;
  final String customerId;

  const CustomerTrackingScreen({
    super.key,
    required this.orderId,
    required this.customerId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<CustomerTrackingCubit>()..trackOrder(orderId, customerId),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: BlocBuilder<CustomerTrackingCubit, CustomerTrackingState>(
          builder: (context, state) {
            if (state is CustomerTrackingLoading ||
                state is CustomerTrackingInitial) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (state is CustomerTrackingError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('Error: ${state.message}',
                        style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context
                          .read<CustomerTrackingCubit>()
                          .trackOrder(orderId, customerId),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (state is CustomerTrackingLoaded) {
              return _TalabatTrackingView(state: state);
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

// ─── Main Tracking View ──────────────────────────────────────────────────────

class _TalabatTrackingView extends StatefulWidget {
  final CustomerTrackingLoaded state;

  const _TalabatTrackingView({required this.state});

  @override
  State<_TalabatTrackingView> createState() => _TalabatTrackingViewState();
}

class _TalabatTrackingViewState extends State<_TalabatTrackingView>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _showOrderDetails = false;

  // Animation controller for smooth motorcycle movement
  late AnimationController _animController;
  LatLng? _oldDriverPos;
  LatLng? _targetDriverPos;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void didUpdateWidget(covariant _TalabatTrackingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newLoc = widget.state.driverLocation;
    if (newLoc != null) {
      final newPos = LatLng(newLoc.latitude, newLoc.longitude);
      if (_oldDriverPos == null) {
        _oldDriverPos = newPos;
        _targetDriverPos = newPos;
      } else if (_targetDriverPos != newPos) {
        _oldDriverPos = LatLng(
          _oldDriverPos!.latitude +
              (_targetDriverPos!.latitude - _oldDriverPos!.latitude) *
                  _animController.value,
          _oldDriverPos!.longitude +
              (_targetDriverPos!.longitude - _oldDriverPos!.longitude) *
                  _animController.value,
        );
        _targetDriverPos = newPos;
        _animController.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  LatLng _animatedDriverPosition() {
    if (_oldDriverPos == null || _targetDriverPos == null) {
      if (widget.state.driverLocation != null) {
        return LatLng(
          widget.state.driverLocation!.latitude,
          widget.state.driverLocation!.longitude,
        );
      }
      return LatLng(widget.state.order.restaurantLat,
          widget.state.order.restaurantLng);
    }
    final t = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    ).value;
    final lat =
        _oldDriverPos!.latitude + (_targetDriverPos!.latitude - _oldDriverPos!.latitude) * t;
    final lng =
        _oldDriverPos!.longitude + (_targetDriverPos!.longitude - _oldDriverPos!.longitude) * t;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.state.order;
    final customerLatLng = LatLng(order.customerLat, order.customerLng);
    final restaurantLatLng = LatLng(order.restaurantLat, order.restaurantLng);
    final currentDriverLatLng = _animatedDriverPosition();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Order Tracking',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _callPhone(context, order.restaurantPhone),
            child: const Text(
              'Help',
              style: TextStyle(
                color: Colors.deepOrange,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Top Floating ETA & Stepper Card ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _buildTopEtaCard(order),
          ),

          // ── Map Section & Floating Controls ──
          Expanded(
            child: Stack(
              children: [
                // Map Canvas
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: currentDriverLatLng,
                    initialZoom: 14.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.gourmet_go',
                    ),

                    // Route Polyline
                    if (widget.state.route != null &&
                        widget.state.route!.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: widget.state.route!,
                            color: Colors.deepOrange,
                            strokeWidth: 4.5,
                          ),
                        ],
                      ),

                    // Markers Layer
                    MarkerLayer(
                      markers: [
                        // Restaurant Marker with Label Badge
                        Marker(
                          point: restaurantLatLng,
                          width: 110,
                          height: 65,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E2022),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Restaurant',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1E2022),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.storefront_rounded,
                                    color: Colors.white, size: 16),
                              ),
                            ],
                          ),
                        ),

                        // Customer Location Marker with Badge
                        Marker(
                          point: customerLatLng,
                          width: 120,
                          height: 70,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E2022),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Your Location',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withAlpha(50),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const Icon(Icons.location_on,
                                      color: Colors.blue, size: 28),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Moving Rider Motorcycle Marker
                        Marker(
                          point: currentDriverLatLng,
                          width: 48,
                          height: 48,
                          child: Transform.rotate(
                            angle: ((widget.state.driverLocation?.heading ?? 0) *
                                (3.14159 / 180)),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(40),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.two_wheeler_rounded,
                                color: Colors.deepOrange,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Floating Map Control Buttons (Right Side)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'fit_all_btn',
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 3,
                        onPressed: () {
                          final points = [
                            customerLatLng,
                            restaurantLatLng,
                            currentDriverLatLng,
                          ];
                          _mapController.fitCamera(
                            CameraFit.bounds(
                              bounds: LatLngBounds.fromPoints(points),
                              padding: const EdgeInsets.all(60),
                            ),
                          );
                        },
                        child: const Icon(Icons.crop_free_rounded),
                      ),
                      const SizedBox(height: 10),
                      FloatingActionButton.small(
                        heroTag: 'recenter_customer_btn',
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 3,
                        onPressed: () async {
                          try {
                            final loc = LocationService();
                            final pos = await loc.getCurrentPosition();
                            _mapController.move(
                              LatLng(pos.latitude, pos.longitude),
                              16.0,
                            );
                          } catch (_) {
                            _mapController.move(customerLatLng, 16.0);
                          }
                        },
                        child: const Icon(Icons.my_location),
                      ),
                      const SizedBox(height: 10),
                      FloatingActionButton.small(
                        heroTag: 'call_driver_btn',
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 3,
                        onPressed: () =>
                            _callPhone(context, order.driverPhone),
                        child: const Icon(Icons.phone),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Rider Sheet & Order Summary Drawer ──
          _buildBottomRiderSheet(order),
        ],
      ),
    );
  }

  // ─── Top Floating ETA & Stepper Card ───────────────────────────────────────

  Widget _buildTopEtaCard(OrderEntity order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated Arrival',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.estimatedArrival != null
                          ? DateFormat('h:mm a').format(order.estimatedArrival!)
                          : _fallbackEta(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.deepOrange,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _remainingMinsText(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.radar_rounded,
                            size: 16, color: Colors.deepOrange),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _distanceText(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),


            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // 4-Step Horizontal Stepper
          _buildTalabatStepper(order.status),
        ],
      ),
    );
  }

  Widget _buildTalabatStepper(OrderStatus status) {
    int activeIndex = 0;
    switch (status) {
      case OrderStatus.pending:
      case OrderStatus.confirmed:
        activeIndex = 0;
        break;
      case OrderStatus.preparing:
        activeIndex = 1;
        break;
      case OrderStatus.driverAssigned:
      case OrderStatus.driverAccepted:
      case OrderStatus.driverPickedUp:
      case OrderStatus.outForDelivery:
        activeIndex = 2;
        break;
      case OrderStatus.delivered:
        activeIndex = 3;
        break;
      case OrderStatus.cancelled:
        activeIndex = -1;
        break;
    }

    final steps = [
      {'label': 'Confirmed', 'icon': Icons.check},
      {'label': 'Preparing', 'icon': Icons.check},
      {'label': 'Out for\nDelivery', 'icon': Icons.two_wheeler},
      {'label': 'Delivered', 'icon': Icons.chat_bubble_outline},
    ];

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isEven) {
          final stepIdx = index ~/ 2;
          final step = steps[stepIdx];
          final isCompleted = stepIdx < activeIndex;
          final isActive = stepIdx == activeIndex;

          Color bg = Colors.grey.shade200;
          Color iconColor = Colors.grey.shade500;
          if (isCompleted || isActive) {
            bg = Colors.deepOrange;
            iconColor = Colors.white;
          }

          return Expanded(
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: bg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(step['icon'] as IconData,
                      size: 18, color: iconColor),
                ),
                const SizedBox(height: 6),
                Text(
                  step['label'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? Colors.deepOrange : Colors.grey.shade700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          );
        } else {
          final stepBefore = index ~/ 2;
          final isCompleted = stepBefore < activeIndex;

          return Container(
            width: 20,
            height: 3,
            margin: const EdgeInsets.only(bottom: 20),
            color: isCompleted ? Colors.deepOrange : Colors.grey.shade300,
          );
        }
      }),
    );
  }

  // ─── Bottom Rider Sheet ───────────────────────────────────────────────────

  Widget _buildBottomRiderSheet(OrderEntity order) {
    final hasDriver = order.driverName != null && order.driverName!.isNotEmpty;
    final driverName = hasDriver ? order.driverName! : 'Driver';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Only show Rider details when out for delivery
            if (order.status == OrderStatus.outForDelivery && hasDriver) ...[
              // Rider Info Row
              Row(
                children: [

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driverName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (order.driverPhone != null &&
                            order.driverPhone!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            order.driverPhone!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Orange Call Button
                  if (order.driverPhone != null &&
                      order.driverPhone!.isNotEmpty)
                    GestureDetector(
                      onTap: () => _callPhone(context, order.driverPhone),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.phone,
                            color: Colors.deepOrange, size: 20),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 14),

              // Rider Status Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.two_wheeler,
                        color: AppColors.textPrimary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your rider is on the way',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Please be ready to receive your order',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Accordion Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _showOrderDetails = !_showOrderDetails;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepOrange,
                  side: const BorderSide(color: Colors.deepOrange),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _showOrderDetails
                          ? 'Hide Order Details'
                          : 'View Order Details',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _showOrderDetails
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            // Expandable Order Details Drawer
            if (_showOrderDetails) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order ${order.orderNumber}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Items: ${order.itemsSummary}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '\$${order.totalAmount.toStringAsFixed(2)} (${order.paymentMethod.toUpperCase()})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fallbackEta() {
    if (widget.state.eta != null) {
      final mins = (widget.state.eta! / 60).round();
      final arrival = DateTime.now().add(Duration(minutes: mins));
      return DateFormat('h:mm a').format(arrival);
    }
    return '12:45 PM';
  }

  String _remainingMinsText() {
    if (widget.state.eta != null) {
      final mins = (widget.state.eta! / 60).round();
      return '$mins min remaining';
    }
    return '12–15 min remaining';
  }

  String _distanceText() {
    if (widget.state.distance != null) {
      final miles = widget.state.distance! / 1609.34;
      return 'Rider is ${miles.toStringAsFixed(1)} miles away';
    }
    return 'Rider is 1.2 miles away';
  }

  void _callPhone(BuildContext context, String? phone) {
    if (phone != null && phone.isNotEmpty) {
      launchUrl(Uri.parse('tel:$phone'));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calling rider...'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
