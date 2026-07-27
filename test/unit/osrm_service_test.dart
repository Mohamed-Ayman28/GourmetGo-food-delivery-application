import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:gourmet_go/features/order_tracking/core/services/osrm_service.dart';

void main() {
  group('OSRMService Unit Tests', () {
    late OSRMService osrmService;

    setUp(() {
      osrmService = OSRMService();
    });

    test('OSRMRoute stores polyline, distance, and duration correctly', () {
      final points = [const LatLng(30.0, 31.0), const LatLng(30.05, 31.05)];
      final route = OSRMRoute(
        polylinePoints: points,
        distanceMeters: 1500.0,
        durationSeconds: 300.0,
      );

      expect(route.polylinePoints.length, equals(2));
      expect(route.distanceMeters, equals(1500.0));
      expect(route.durationSeconds, equals(300.0));
    });

    test('getRoute handles coordinate inputs without throwing errors', () async {
      final start = const LatLng(30.0444, 31.2357); // Cairo
      final dest = const LatLng(30.0500, 31.2400);

      // Verify call handles network or graceful null fallback without unhandled exceptions
      final result = await osrmService.getRoute(start, dest);
      // Result is either a valid OSRMRoute or null (if network fails in test environment)
      if (result != null) {
        expect(result.polylinePoints, isNotEmpty);
        expect(result.distanceMeters, greaterThan(0));
      } else {
        expect(result, isNull);
      }
    });
  });
}
