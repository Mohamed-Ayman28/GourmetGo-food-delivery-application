import 'package:gourmet_go/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:get_it/get_it.dart';

import '../../core/services/location_service.dart';
import '../../core/services/osrm_service.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../cubit/driver_navigation_cubit.dart';
import '../cubit/driver_navigation_state.dart';
import '../../../../consts/appColors.dart';

class DriverNavigationScreen extends StatelessWidget {
  final OrderEntity order;
  final String driverId;

  const DriverNavigationScreen({
    super.key,
    required this.order,
    required this.driverId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DriverNavigationCubit(
        locationService: GetIt.I<LocationService>(),
        osrmService: OSRMService(),
        orderRepository: GetIt.I<OrderRepository>(),
        trackingRepository: GetIt.I<TrackingRepository>(),
        driverId: driverId,
        order: order,
      )..startNavigation(),
      child: const _DriverNavigationView(),
    );
  }
}

class _DriverNavigationView extends StatefulWidget {
  const _DriverNavigationView();

  @override
  State<_DriverNavigationView> createState() => _DriverNavigationViewState();
}

class _DriverNavigationViewState extends State<_DriverNavigationView> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocConsumer<DriverNavigationCubit, DriverNavigationState>(
        listener: (context, state) {
          if (state is DriverNavigationActive && state.isAutoFollow) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _mapController.move(state.driverLocation, 16.0);
              }
            });
          }
          if (state is DriverNavigationError) {
            CustomSnackBar.show(context, message: state.message, type: SnackBarType.info);
          }
        },
        builder: (context, state) {
          if (state is DriverNavigationLoading || state is DriverNavigationInitial) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (state is DriverNavigationError) {
            return Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
                backgroundColor: Colors.white,
                elevation: 0,
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off_rounded, color: AppColors.primary, size: 64),
                      const SizedBox(height: 24),
                      const Text(
                        'Navigation Error',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => context.read<DriverNavigationCubit>().startNavigation(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text(
                            'Retry',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (state is DriverNavigationActive) {
            return Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: state.driverLocation,
                    initialZoom: 16.0,
                    onPositionChanged: (pos, hasGesture) {
                      if (hasGesture && state.isAutoFollow) {
                        context.read<DriverNavigationCubit>().toggleAutoFollow();
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.gourmet_go',
                    ),
                    if (state.routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: state.routePoints,
                            strokeWidth: 5.0,
                            color: AppColors.primary.withValues(alpha: 0.8),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // Customer Marker
                        Marker(
                          point: state.customerLocation,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                    // Driver Marker with custom smooth interpolation
                    SmoothDriverMarkerLayer(
                      targetPosition: state.driverLocation,
                      targetHeading: state.heading,
                    ),
                  ],
                ),

                // Route loading indicator — shows while OSRM is fetching
                if (state.isLoadingRoute)
                  Positioned(
                    top: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Calculating route...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                // Auto-follow toggle button
                Positioned(
                  top: 50,
                  right: 20,
                  child: FloatingActionButton(
                    backgroundColor: Colors.white,
                    heroTag: 'autoFollow',
                    onPressed: () => context.read<DriverNavigationCubit>().toggleAutoFollow(),
                    child: Icon(
                      state.isAutoFollow ? Icons.my_location : Icons.location_disabled,
                      color: state.isAutoFollow ? AppColors.primary : Colors.grey,
                    ),
                  ),
                ),
                
                // Back button
                Positioned(
                  top: 50,
                  left: 20,
                  child: FloatingActionButton(
                    backgroundColor: Colors.white,
                    heroTag: 'backNav',
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: Colors.black),
                  ),
                ),

                // Bottom Info Sheet
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
                    ),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.etaSeconds > 0
                                      ? '${(state.etaSeconds / 60).toStringAsFixed(0)} min'
                                      : 'Calculating...',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                                Text(
                                  '${(state.distanceMeters / 1000).toStringAsFixed(1)} km remaining',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20)),
                              child: const Text('En Route', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const Divider(height: 32),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.background,
                            child: Icon(Icons.person, color: AppColors.primary),
                          ),
                          title: Text(context.read<DriverNavigationCubit>().order.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(context.read<DriverNavigationCubit>().order.customerAddress, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.phone, color: AppColors.primary),
                            onPressed: () {
                              // Call customer
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: state.canMarkDelivered
                                ? () async {
                                    final success = await context.read<DriverNavigationCubit>().markAsDelivered();
                                    if (success && context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              disabledBackgroundColor: Colors.grey.shade300,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(
                              state.canMarkDelivered ? 'Mark as Delivered' : 'Too far to deliver',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class SmoothDriverMarkerLayer extends StatefulWidget {
  final LatLng targetPosition;
  final double targetHeading;

  const SmoothDriverMarkerLayer({
    super.key,
    required this.targetPosition,
    required this.targetHeading,
  });

  @override
  State<SmoothDriverMarkerLayer> createState() => _SmoothDriverMarkerLayerState();
}

class _SmoothDriverMarkerLayerState extends State<SmoothDriverMarkerLayer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late LatLng _currentPosition;
  late double _currentHeading;
  
  LatLng? _oldPosition;
  double? _oldHeading;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.targetPosition;
    _currentHeading = widget.targetHeading;
    
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _controller.addListener(() {
      setState(() {
        if (_oldPosition != null) {
          _currentPosition = LatLng(
            _oldPosition!.latitude + (widget.targetPosition.latitude - _oldPosition!.latitude) * _controller.value,
            _oldPosition!.longitude + (widget.targetPosition.longitude - _oldPosition!.longitude) * _controller.value,
          );
        }
        if (_oldHeading != null) {
          _currentHeading = _oldHeading! + (widget.targetHeading - _oldHeading!) * _controller.value;
        }
      });
    });
  }

  @override
  void didUpdateWidget(SmoothDriverMarkerLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetPosition != widget.targetPosition || oldWidget.targetHeading != widget.targetHeading) {
      _oldPosition = _currentPosition;
      _oldHeading = _currentHeading;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: [
        Marker(
          point: _currentPosition,
          width: 50,
          height: 50,
          child: Transform.rotate(
            angle: _currentHeading * (3.141592653589793 / 180.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: const Icon(Icons.motorcycle, color: AppColors.primary, size: 30),
            ),
          ),
        ),
      ],
    );
  }
}
