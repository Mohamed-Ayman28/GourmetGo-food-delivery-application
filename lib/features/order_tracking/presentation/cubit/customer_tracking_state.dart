import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/entities/location_entity.dart';

abstract class CustomerTrackingState extends Equatable {
  const CustomerTrackingState();

  @override
  List<Object?> get props => [];
}

class CustomerTrackingInitial extends CustomerTrackingState {}

class CustomerTrackingLoading extends CustomerTrackingState {}

class CustomerTrackingLoaded extends CustomerTrackingState {
  final OrderEntity order;
  final LocationEntity? driverLocation;
  final List<LatLng>? route;
  final double? distance;
  final double? eta; // in seconds

  const CustomerTrackingLoaded({
    required this.order,
    this.driverLocation,
    this.route,
    this.distance,
    this.eta,
  });

  CustomerTrackingLoaded copyWith({
    OrderEntity? order,
    LocationEntity? driverLocation,
    List<LatLng>? route,
    double? distance,
    double? eta,
  }) {
    return CustomerTrackingLoaded(
      order: order ?? this.order,
      driverLocation: driverLocation ?? this.driverLocation,
      route: route ?? this.route,
      distance: distance ?? this.distance,
      eta: eta ?? this.eta,
    );
  }

  @override
  List<Object?> get props => [order, driverLocation, route, distance, eta];
}

class CustomerTrackingError extends CustomerTrackingState {
  final String message;

  const CustomerTrackingError(this.message);

  @override
  List<Object?> get props => [message];
}
