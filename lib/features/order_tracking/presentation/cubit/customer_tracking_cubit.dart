import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/services/osrm_service.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/tracking_repository.dart';
import 'customer_tracking_state.dart';

class CustomerTrackingCubit extends Cubit<CustomerTrackingState> {
  final OrderRepository orderRepository;
  final TrackingRepository trackingRepository;
  final OSRMService osrmService; // Switched to the robust OSRMService

  StreamSubscription? _orderSubscription;
  StreamSubscription? _locationSubscription;

  // Route refresh throttling — avoid hammering the OSRM API
  static const Duration _routeRefreshInterval = Duration(seconds: 30);
  static const double _routeRefreshDistanceMeters = 200.0;
  DateTime? _lastRouteRefreshTime;
  LatLng? _lastRouteRefreshPosition;
  bool _isRefreshingRoute = false;

  CustomerTrackingCubit({
    required this.orderRepository,
    required this.trackingRepository,
    required this.osrmService,
  }) : super(CustomerTrackingInitial());

  void trackOrder(String orderId, String customerId) {
    emit(CustomerTrackingLoading());

    _orderSubscription?.cancel();
    _orderSubscription = orderRepository.streamCustomerOrders(customerId).listen(
      (orders) {
        final order = orders.firstWhere(
          (o) => o.id == orderId,
          orElse: () => throw Exception('Order not found'),
        );

        if (state is CustomerTrackingLoaded) {
          emit((state as CustomerTrackingLoaded).copyWith(order: order));
        } else {
          emit(CustomerTrackingLoaded(order: order));
        }

        // Start tracking driver location if driver is assigned
        if (order.driverId != null && _locationSubscription == null) {
          _trackDriverLocation(order.driverId!, order);
        }
      },
      onError: (e) => emit(CustomerTrackingError(e.toString())),
    );
  }

  void _trackDriverLocation(String driverId, order) {
    _locationSubscription?.cancel();
    _locationSubscription = trackingRepository.streamDriverLocation(driverId).listen(
      (location) {
        if (state is CustomerTrackingLoaded) {
          final currentState = state as CustomerTrackingLoaded;
          final driverLoc = LatLng(location.latitude, location.longitude);
          final customerLoc = LatLng(currentState.order.customerLat, currentState.order.customerLng);

          // Calculate straight-line distance as a fallback
          final straightLineDistance = Geolocator.distanceBetween(
            driverLoc.latitude, driverLoc.longitude,
            customerLoc.latitude, customerLoc.longitude,
          );

          emit(currentState.copyWith(
            driverLocation: location,
            distance: currentState.distance ?? straightLineDistance,
          ));

          _maybeRefreshRoute(driverLoc, customerLoc);
        }
      },
      onError: (e) {
        // Location stream error handled silently to not break UI completely
      },
    );
  }

  /// Refreshes the OSRM route if enough time or distance has passed.
  void _maybeRefreshRoute(LatLng driverLoc, LatLng customerLoc) {
    if (_isRefreshingRoute) return;

    final now = DateTime.now();
    final timeSinceLastRefresh = _lastRouteRefreshTime != null
        ? now.difference(_lastRouteRefreshTime!)
        : _routeRefreshInterval; // trigger on first call

    final distanceSinceLastRefresh = _lastRouteRefreshPosition != null
        ? Geolocator.distanceBetween(
            driverLoc.latitude, driverLoc.longitude,
            _lastRouteRefreshPosition!.latitude, _lastRouteRefreshPosition!.longitude,
          )
        : _routeRefreshDistanceMeters;

    final shouldRefresh = timeSinceLastRefresh >= _routeRefreshInterval ||
        distanceSinceLastRefresh >= _routeRefreshDistanceMeters;

    if (!shouldRefresh) return;

    _isRefreshingRoute = true;

    osrmService.getRoute(driverLoc, customerLoc).then((route) {
      if (route != null && state is CustomerTrackingLoaded) {
        _lastRouteRefreshTime = DateTime.now();
        _lastRouteRefreshPosition = driverLoc;

        emit((state as CustomerTrackingLoaded).copyWith(
          route: route.polylinePoints,
          distance: route.distanceMeters,
          eta: route.durationSeconds,
        ));
      }
    }).whenComplete(() {
      _isRefreshingRoute = false;
    });
  }

  @override
  Future<void> close() {
    _orderSubscription?.cancel();
    _locationSubscription?.cancel();
    return super.close();
  }
}
