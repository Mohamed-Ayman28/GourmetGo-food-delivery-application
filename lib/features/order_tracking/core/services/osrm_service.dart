import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OSRMRoute {
  final List<LatLng> polylinePoints;
  final double distanceMeters;
  final double durationSeconds;

  OSRMRoute({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

class OSRMService {
  static const String _baseUrl = 'https://router.project-osrm.org/route/v1/driving';
  static const Duration _timeout = Duration(seconds: 8);
  static const int _maxRetries = 1;

  Future<OSRMRoute?> getRoute(LatLng start, LatLng destination) async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        // Use geometries=geojson to avoid Dart 64-bit int polyline decoding bugs
        final url = '$_baseUrl/${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson';
        final response = await http
            .get(Uri.parse(url), headers: {'User-Agent': 'GourmetGoApp/1.0'})
            .timeout(_timeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
            final route = data['routes'][0];
            final geometry = route['geometry'];
            final coordinates = geometry['coordinates'] as List<dynamic>;
            final distance = (route['distance'] as num).toDouble();
            final duration = (route['duration'] as num).toDouble();

            // GeoJSON coordinates are in [longitude, latitude] order
            final decodedPoints = coordinates.map((c) {
              return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
            }).toList();

            return OSRMRoute(
              polylinePoints: decodedPoints,
              distanceMeters: distance,
              durationSeconds: duration,
            );
          }
        }

        // Non-200 or no route found — don't retry, it won't help
        debugPrint('[OSRM] No route found (status=${response.statusCode})');
        return null;
      } catch (e) {
        debugPrint('[OSRM] Route fetch failed (attempt ${attempt + 1}/${_maxRetries + 1}): $e');
        if (attempt == _maxRetries) return null;
        // Brief pause before retry
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return null;
  }
}
