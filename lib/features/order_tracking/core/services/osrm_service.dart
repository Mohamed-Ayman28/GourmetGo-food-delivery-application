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
        final url = '$_baseUrl/${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=polyline';
        final response = await http
            .get(Uri.parse(url), headers: {'User-Agent': 'GourmetGoApp/1.0'})
            .timeout(_timeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
            final route = data['routes'][0];
            final geometry = route['geometry'] as String;
            final distance = (route['distance'] as num).toDouble();
            final duration = (route['duration'] as num).toDouble();

            final decodedPoints = _decodePolyline(geometry);

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

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      final p = LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble());
      poly.add(p);
    }
    return poly;
  }
}
