import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/services/location_service.dart';
import '../../core/services/osrm_service.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../../domain/entities/location_entity.dart';
import 'driver_navigation_state.dart';

class DriverNavigationCubit extends Cubit<DriverNavigationState> {
  final LocationService locationService;
  final OSRMService osrmService;
  final OrderRepository orderRepository;
  final TrackingRepository trackingRepository;
  final String driverId;
  final OrderEntity order;

  StreamSubscription<Position>? _locationSub;

  // Route refresh throttling — avoid hammering the OSRM API
  static const Duration _routeRefreshInterval = Duration(seconds: 30);
  static const double _routeRefreshDistanceMeters = 200.0;
  DateTime? _lastRouteRefreshTime;
  LatLng? _lastRouteRefreshPosition;
  bool _isRefreshingRoute = false;

  DriverNavigationCubit({
    required this.locationService,
    required this.osrmService,
    required this.orderRepository,
    required this.trackingRepository,
    required this.driverId,
    required this.order,
  }) : super(DriverNavigationInitial());

  Future<void> startNavigation() async {
    emit(DriverNavigationLoading());

    // Update status to outForDelivery if not already
    if (order.status != OrderStatus.outForDelivery) {
      final res = await orderRepository.updateOrderStatus(order.id, OrderStatus.outForDelivery);
      if (res.isLeft()) {
        emit(DriverNavigationError(res.fold((l) => l, (r) => '')));
        return;
      }
    }

    final hasPerm = await locationService.checkAndRequestPermissions();
    if (!hasPerm) {
      emit(const DriverNavigationError('Location permission denied'));
      return;
    }

    final customerLatLng = LatLng(order.customerLat, order.customerLng);

    // ---- Phase 1: Show map INSTANTLY with last known position ----
    try {
      final lastKnown = await locationService.getLastKnownPosition();
      if (lastKnown != null) {
        final approxDriverLoc = LatLng(lastKnown.latitude, lastKnown.longitude);
        final approxDistance = Geolocator.distanceBetween(
          approxDriverLoc.latitude, approxDriverLoc.longitude,
          customerLatLng.latitude, customerLatLng.longitude,
        );

        // Emit immediately so the map renders right away
        emit(DriverNavigationActive(
          driverLocation: approxDriverLoc,
          heading: lastKnown.heading,
          customerLocation: customerLatLng,
          routePoints: const [],
          distanceMeters: approxDistance,
          etaSeconds: 0,
          isAutoFollow: true,
          canMarkDelivered: approxDistance <= 50.0,
          isLoadingRoute: true,
        ));
      }
    } catch (_) {
      // No cached position — stay on loading spinner, it's fine
    }

    // ---- Phase 2: Get accurate GPS + OSRM route in parallel ----
    try {
      final posFuture = locationService.getCurrentPosition();

      // If we already emitted a state above, the map is visible.
      // Now wait for the accurate position.
      final pos = await posFuture;
      final driverLatLng = LatLng(pos.latitude, pos.longitude);

      _pushFirebaseLocation(pos);

      // Fetch the route (don't block map display — it's already showing)
      final route = await osrmService.getRoute(driverLatLng, customerLatLng);

      final distance = route?.distanceMeters ?? Geolocator.distanceBetween(
        driverLatLng.latitude, driverLatLng.longitude,
        customerLatLng.latitude, customerLatLng.longitude,
      );

      _lastRouteRefreshTime = DateTime.now();
      _lastRouteRefreshPosition = driverLatLng;

      emit(DriverNavigationActive(
        driverLocation: driverLatLng,
        heading: pos.heading,
        customerLocation: customerLatLng,
        routePoints: route?.polylinePoints ?? [],
        distanceMeters: distance,
        etaSeconds: route?.durationSeconds ?? _estimateEta(distance),
        isAutoFollow: true,
        canMarkDelivered: distance <= 50.0,
        isLoadingRoute: false,
      ));

      _startLocationStream();
    } catch (e) {
      emit(DriverNavigationError(e.toString()));
    }
  }

  void _startLocationStream() {
    _locationSub = locationService.getPositionStream().listen(
      (pos) async {
        if (state is DriverNavigationActive) {
          final activeState = state as DriverNavigationActive;
          final newDriverLoc = LatLng(pos.latitude, pos.longitude);

          _pushFirebaseLocation(pos);

          // Use the latest route distance if we have route points,
          // otherwise fall back to straight-line distance.
          final straightLineDistance = Geolocator.distanceBetween(
            pos.latitude, pos.longitude,
            activeState.customerLocation.latitude, activeState.customerLocation.longitude,
          );

          emit(activeState.copyWith(
            driverLocation: newDriverLoc,
            heading: pos.heading,
            distanceMeters: straightLineDistance,
            canMarkDelivered: straightLineDistance <= 50.0,
          ));

          // ---- Periodic route refresh ----
          _maybeRefreshRoute(newDriverLoc, activeState.customerLocation);
        }
      },
      onError: (e) {
        emit(DriverNavigationError('Location tracking error: $e'));
      },
    );
  }

  /// Refreshes the OSRM route if enough time or distance has passed.
  /// Fire-and-forget: doesn't block the location stream.
  void _maybeRefreshRoute(LatLng currentPos, LatLng customerPos) {
    if (_isRefreshingRoute) return;

    final now = DateTime.now();
    final timeSinceLastRefresh = _lastRouteRefreshTime != null
        ? now.difference(_lastRouteRefreshTime!)
        : _routeRefreshInterval; // trigger on first call if never refreshed

    final distanceSinceLastRefresh = _lastRouteRefreshPosition != null
        ? Geolocator.distanceBetween(
            currentPos.latitude, currentPos.longitude,
            _lastRouteRefreshPosition!.latitude, _lastRouteRefreshPosition!.longitude,
          )
        : _routeRefreshDistanceMeters;

    final shouldRefresh = timeSinceLastRefresh >= _routeRefreshInterval ||
        distanceSinceLastRefresh >= _routeRefreshDistanceMeters;

    if (!shouldRefresh) return;

    _isRefreshingRoute = true;

    osrmService.getRoute(currentPos, customerPos).then((route) {
      if (route != null && state is DriverNavigationActive) {
        _lastRouteRefreshTime = DateTime.now();
        _lastRouteRefreshPosition = currentPos;

        emit((state as DriverNavigationActive).copyWith(
          routePoints: route.polylinePoints,
          distanceMeters: route.distanceMeters,
          etaSeconds: route.durationSeconds,
        ));
      }
    }).catchError((e) {
      debugPrint('[DriverNav] Route refresh failed: $e');
    }).whenComplete(() {
      _isRefreshingRoute = false;
    });
  }

  /// Simple ETA estimate when OSRM is unavailable: assume ~30 km/h average speed.
  double _estimateEta(double distanceMeters) {
    const avgSpeedMps = 30.0 * 1000.0 / 3600.0; // 30 km/h in m/s
    return distanceMeters / avgSpeedMps;
  }

  void toggleAutoFollow() {
    if (state is DriverNavigationActive) {
      final active = state as DriverNavigationActive;
      emit(active.copyWith(isAutoFollow: !active.isAutoFollow));
    }
  }

  Future<bool> markAsDelivered() async {
    _locationSub?.cancel();
    emit(DriverNavigationLoading());
    final res = await orderRepository.updateOrderStatus(order.id, OrderStatus.delivered);
    return res.fold(
      (error) {
        emit(DriverNavigationError(error));
        return false;
      },
      (_) => true,
    );
  }

  void _pushFirebaseLocation(Position pos) {
    trackingRepository.updateDriverLocation(
      driverId,
      LocationEntity(
        latitude: pos.latitude,
        longitude: pos.longitude,
        heading: pos.heading,
        timestamp: pos.timestamp,
      ),
    );
  }

  @override
  Future<void> close() {
    _locationSub?.cancel();
    return super.close();
  }
}
