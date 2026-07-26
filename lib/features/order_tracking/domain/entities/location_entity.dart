import 'package:equatable/equatable.dart';

class LocationEntity extends Equatable {
  final double latitude;
  final double longitude;
  final double heading;
  final DateTime timestamp;

  const LocationEntity({
    required this.latitude,
    required this.longitude,
    required this.heading,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [latitude, longitude, heading, timestamp];
}
