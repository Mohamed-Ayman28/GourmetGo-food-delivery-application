import 'package:dartz/dartz.dart';
import '../entities/location_entity.dart';

abstract class TrackingRepository {
  /// Stream driver's location from Firestore for tracking
  Stream<LocationEntity> streamDriverLocation(String driverId);

  /// Update driver's location in Firestore
  Future<Either<String, void>> updateDriverLocation(String driverId, LocationEntity location);
}
