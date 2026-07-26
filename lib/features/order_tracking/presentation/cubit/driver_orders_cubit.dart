import 'dart:async';
import 'package:bloc/bloc.dart';
import '../../core/services/location_service.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/tracking_repository.dart';
import 'driver_orders_state.dart';

class DriverOrdersCubit extends Cubit<DriverOrdersState> {
  final OrderRepository orderRepository;
  final LocationService locationService;
  final TrackingRepository trackingRepository;

  StreamSubscription? _ordersSubscription;
  StreamSubscription? _locationSubscription;
  String? _currentDriverId;

  DriverOrdersCubit({
    required this.orderRepository,
    required this.locationService,
    required this.trackingRepository,
  }) : super(DriverOrdersInitial());

  void loadDriverOrders(String driverId) {
    _currentDriverId = driverId;
    emit(DriverOrdersLoading());

    _ordersSubscription?.cancel();
    _ordersSubscription = orderRepository.streamDriverOrders(driverId).listen(
      (orders) {
        if (state is DriverOrdersLoaded) {
          emit((state as DriverOrdersLoaded).copyWith(orders: orders));
        } else {
          emit(DriverOrdersLoaded(orders));
        }
      },
      onError: (e) {
        emit(DriverOrdersError(e.toString()));
      },
    );
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final result = await orderRepository.updateOrderStatus(orderId, status);
    if (result.isLeft()) {
      emit(DriverOrdersError(result.fold((l) => l, (r) => '')));
    }
  }

  Future<void> startDelivery(String orderId) async {
    if (_currentDriverId == null) return;
    
    // Request permission first
    final hasPermission = await locationService.checkAndRequestPermissions();
    if (!hasPermission) {
      emit(const DriverOrdersError('Location permission denied or GPS disabled.'));
      return;
    }

    // Update order status
    final result = await orderRepository.updateOrderStatus(orderId, OrderStatus.outForDelivery);
    if (result.isLeft()) {
      emit(DriverOrdersError(result.fold((l) => l, (r) => '')));
      return;
    }

    // Publish initial high-accuracy GPS fix immediately
    try {
      final initialPos = await locationService.getCurrentPosition();
      final initLocation = LocationEntity(
        latitude: initialPos.latitude,
        longitude: initialPos.longitude,
        heading: initialPos.heading,
        timestamp: initialPos.timestamp,
      );
      await trackingRepository.updateDriverLocation(_currentDriverId!, initLocation);
    } catch (_) {}

    // Start streaming continuous position updates
    _locationSubscription?.cancel();
    _locationSubscription = locationService.getPositionStream().listen(
      (position) {
        final location = LocationEntity(
          latitude: position.latitude,
          longitude: position.longitude,
          heading: position.heading,
          timestamp: position.timestamp,
        );
        trackingRepository.updateDriverLocation(_currentDriverId!, location);
      },
      onError: (e) {
        // Handle location stream errors
      },
    );

    if (state is DriverOrdersLoaded) {
      emit((state as DriverOrdersLoaded).copyWith(isTracking: true));
    }
  }

  Future<void> stopDelivery(String orderId) async {
    // Update order status
    await orderRepository.updateOrderStatus(orderId, OrderStatus.delivered);

    // Stop streaming location
    _locationSubscription?.cancel();
    _locationSubscription = null;

    if (state is DriverOrdersLoaded) {
      emit((state as DriverOrdersLoaded).copyWith(isTracking: false));
    }
  }

  @override
  Future<void> close() {
    _ordersSubscription?.cancel();
    _locationSubscription?.cancel();
    return super.close();
  }
}
