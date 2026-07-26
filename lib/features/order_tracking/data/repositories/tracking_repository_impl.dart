import 'package:dartz/dartz.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../datasources/tracking_remote_datasource.dart';
import '../models/location_model.dart';

class TrackingRepositoryImpl implements TrackingRepository {
  final TrackingRemoteDataSource remoteDataSource;

  TrackingRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<LocationEntity> streamDriverLocation(String driverId) {
    return remoteDataSource.streamDriverLocation(driverId);
  }

  @override
  Future<Either<String, void>> updateDriverLocation(
      String driverId, LocationEntity location) async {
    try {
      final model = LocationModel(
        latitude: location.latitude,
        longitude: location.longitude,
        heading: location.heading,
        timestamp: location.timestamp,
      );
      await remoteDataSource.updateDriverLocation(driverId, model);
      return const Right(null);
    } catch (e) {
      return Left('Failed to update location: $e');
    }
  }
}
