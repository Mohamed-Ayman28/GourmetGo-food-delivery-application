import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class RoutingService {
  final Dio _dio;

  RoutingService({Dio? dio}) : _dio = dio ?? Dio();

  /// Fetches a route from OSRM driving API.
  /// Returns a Map containing 'polyline' (List of LatLng), 'distance' (double in meters), and 'duration' (double in seconds).
  Future<Map<String, dynamic>> getRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
      
      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          
          final geometry = route['geometry']['coordinates'] as List;
          final List<LatLng> polyline = geometry
              .map((point) => LatLng(point[1].toDouble(), point[0].toDouble()))
              .toList();

          return {
            'polyline': polyline,
            'distance': route['distance'].toDouble(),
            'duration': route['duration'].toDouble(),
          };
        }
      }
      throw Exception('Failed to fetch route');
    } catch (e) {
      throw Exception('Error fetching route: $e');
    }
  }
}
