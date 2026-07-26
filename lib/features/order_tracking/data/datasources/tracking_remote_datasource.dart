import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/location_model.dart';

abstract class TrackingRemoteDataSource {
  Stream<LocationModel> streamDriverLocation(String driverId);
  Future<void> updateDriverLocation(String driverId, LocationModel location);
}

class TrackingRemoteDataSourceImpl implements TrackingRemoteDataSource {
  final FirebaseFirestore _firestore;

  TrackingRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<LocationModel> streamDriverLocation(String driverId) {
    return _firestore
        .collection('driver_locations')
        .doc(driverId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return LocationModel.fromJson(snapshot.data()!);
      }
      throw Exception('Driver location not found');
    });
  }

  @override
  Future<void> updateDriverLocation(
      String driverId, LocationModel location) async {
    await _firestore
        .collection('driver_locations')
        .doc(driverId)
        .set(location.toJson());
  }
}
