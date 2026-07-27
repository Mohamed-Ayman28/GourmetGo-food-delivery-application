import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

abstract class DriverNavigationState extends Equatable {
  const DriverNavigationState();
  @override
  List<Object?> get props => [];
}

class DriverNavigationInitial extends DriverNavigationState {}

class DriverNavigationLoading extends DriverNavigationState {}

class DriverNavigationActive extends DriverNavigationState {
  final LatLng driverLocation;
  final double heading;
  final LatLng customerLocation;
  final List<LatLng> routePoints;
  final double distanceMeters;
  final double etaSeconds;
  final bool isAutoFollow;
  final bool canMarkDelivered;
  final bool isLoadingRoute;

  const DriverNavigationActive({
    required this.driverLocation,
    required this.heading,
    required this.customerLocation,
    required this.routePoints,
    required this.distanceMeters,
    required this.etaSeconds,
    required this.isAutoFollow,
    required this.canMarkDelivered,
    this.isLoadingRoute = false,
  });

  DriverNavigationActive copyWith({
    LatLng? driverLocation,
    double? heading,
    LatLng? customerLocation,
    List<LatLng>? routePoints,
    double? distanceMeters,
    double? etaSeconds,
    bool? isAutoFollow,
    bool? canMarkDelivered,
    bool? isLoadingRoute,
  }) {
    return DriverNavigationActive(
      driverLocation: driverLocation ?? this.driverLocation,
      heading: heading ?? this.heading,
      customerLocation: customerLocation ?? this.customerLocation,
      routePoints: routePoints ?? this.routePoints,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      isAutoFollow: isAutoFollow ?? this.isAutoFollow,
      canMarkDelivered: canMarkDelivered ?? this.canMarkDelivered,
      isLoadingRoute: isLoadingRoute ?? this.isLoadingRoute,
    );
  }

  @override
  List<Object?> get props => [
        driverLocation,
        heading,
        customerLocation,
        routePoints,
        distanceMeters,
        etaSeconds,
        isAutoFollow,
        canMarkDelivered,
        isLoadingRoute,
      ];
}

class DriverNavigationError extends DriverNavigationState {
  final String message;
  const DriverNavigationError(this.message);
  @override
  List<Object?> get props => [message];
}

