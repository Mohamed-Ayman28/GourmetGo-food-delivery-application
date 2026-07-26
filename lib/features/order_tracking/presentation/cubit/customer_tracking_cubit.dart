import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:latlong2/latlong.dart';
import '../../core/services/routing_service.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/tracking_repository.dart';
import 'customer_tracking_state.dart';

class CustomerTrackingCubit extends Cubit<CustomerTrackingState> {
  final OrderRepository orderRepository;
  final TrackingRepository trackingRepository;
  final RoutingService routingService;

  StreamSubscription? _orderSubscription;
  StreamSubscription? _locationSubscription;

  CustomerTrackingCubit({
    required this.orderRepository,
    required this.trackingRepository,
    required this.routingService,
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
      (location) async {
        if (state is CustomerTrackingLoaded) {
          final currentState = state as CustomerTrackingLoaded;
          emit(currentState.copyWith(driverLocation: location));

          // Fetch route from Driver to Customer
          try {
            final routeData = await routingService.getRoute(
              start: LatLng(location.latitude, location.longitude),
              end: LatLng(currentState.order.customerLat, currentState.order.customerLng),
            );

            emit((state as CustomerTrackingLoaded).copyWith(
              route: routeData['polyline'] as List<LatLng>,
              distance: routeData['distance'] as double,
              eta: routeData['duration'] as double,
            ));
          } catch (e) {
            // Error fetching route, maybe ignore or log
          }
        }
      },
      onError: (e) {
        // Location stream error
      },
    );
  }

  @override
  Future<void> close() {
    _orderSubscription?.cancel();
    _locationSubscription?.cancel();
    return super.close();
  }
}
