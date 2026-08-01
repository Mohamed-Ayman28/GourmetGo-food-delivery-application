import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Thrown whenever a real GPS location cannot be obtained.
/// Callers should catch this and show an appropriate UI message instead of
/// falling back to any guessed/fake location.
class LocationServiceException implements Exception {
  final String message;
  LocationServiceException(this.message);

  @override
  String toString() => message;
}

/// Structured, human-readable address returned from reverse geocoding.
class StructuredAddress {
  final String fullAddress;
  final String street;
  final String district;
  final String city;
  final String state;
  final String country;
  final String postcode;

  const StructuredAddress({
    required this.fullAddress,
    this.street = '',
    this.district = '',
    this.city = '',
    this.state = '',
    this.country = '',
    this.postcode = '',
  });
}

class LocationService {
  // How accurate a GPS fix must be (in meters) before we trust it.
  // 50m is good enough for delivery navigation and resolves much faster
  // than 20m, especially indoors or in dense urban areas.
  static const double _desiredAccuracyMeters = 50.0;

  // How long we wait for an accurate fix before giving up.
  // 10s is plenty for modern devices; the old 25s caused unacceptable waits.
  static const Duration _fixTimeout = Duration(seconds: 10);

  // How long we wait for the user to enable location services after being
  // sent to the settings screen.
  static const Duration _serviceEnableTimeout = Duration(seconds: 30);

  // Network timeout for geocoding requests.
  static const Duration _networkTimeout = Duration(seconds: 10);

  /// Shows a dialog explaining why we need GPS access, then walks the user
  /// through enabling location services and granting permission.
  ///
  /// If permission is granted (either because it was already granted, or
  /// because the user tapped "Allow & Detect GPS"), this method also
  /// resolves the device's real GPS coordinates and reverse-geocodes them
  /// automatically. Pass [onLocationResolved] to receive that position and
  /// address as soon as they're ready — e.g. to move a map camera and fill
  /// in an address field. This callback is optional so existing call sites
  /// that only care about the `Future<bool>` keep working unchanged.
  Future<bool> promptLocationPermissionDialog(
    BuildContext context, {
    void Function(Position position, StructuredAddress address)?
        onLocationResolved,
    void Function(Object error)? onLocationError,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();

    final alreadyGranted = serviceEnabled &&
        (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse);

    if (!alreadyGranted) {
      if (!context.mounted) return false;

      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.location_on, color: Colors.deepOrange),
              SizedBox(width: 10),
              Text('Enable Location Access',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Gourmet Go uses your device GPS to detect your real current location anywhere in the world for accurate delivery and live driver tracking.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Allow & Detect GPS',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (result != true) return false;

      final granted = await checkAndRequestPermissions();
      if (!granted) return false;
    }

    // Permission (and GPS) are confirmed on — resolve the real fix and the
    // address automatically so the caller can move its map camera right away.
    if (onLocationResolved != null) {
      try {
        final position = await getCurrentPosition();
        final address = await reverseGeocode(position.latitude, position.longitude);
        onLocationResolved(position, address);
      } catch (e) {
        if (onLocationError != null) {
          onLocationError(e);
        }
      }
    }

    return true;
  }

  /// Ensures location services are enabled and permission is granted.
  /// If services are disabled, opens the system settings and waits for the
  /// user to enable them before continuing.
  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      // Send the user to the OS settings screen to turn GPS on.
      await Geolocator.openLocationSettings();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    // Permanently denied — the OS will no longer show the request dialog.
    // The user must grant it manually from the app's system settings.
    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Listens for the device's location-service status until it becomes
  /// enabled, or until [timeout] elapses.
  Future<bool> _waitForLocationServiceEnabled(Duration timeout) async {
    if (await Geolocator.isLocationServiceEnabled()) return true;

    final completer = Completer<bool>();
    StreamSubscription<ServiceStatus>? subscription;
    Timer? timer;

    subscription = Geolocator.getServiceStatusStream().listen((status) {
      if (status == ServiceStatus.enabled && !completer.isCompleted) {
        completer.complete(true);
      }
    }, onError: (_) {
      if (!completer.isCompleted) completer.complete(false);
    });

    timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(false);
    });

    final enabled = await completer.future;
    timer.cancel();
    await subscription.cancel();
    return enabled;
  }

  /// Returns the platform's last cached GPS position instantly (no waiting).
  /// Returns `null` if no cached position is available.
  /// Use this to show the map immediately while a fresh fix is obtained.
  Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  /// Live position stream for driver/customer tracking — smooth updates
  /// every few meters at navigation-grade accuracy. Positions reported by a
  /// mock/fake-GPS provider are filtered out so tracking can't be spoofed.
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5, // Update every 5 meters for smooth live tracking.
      ),
    ).where((position) => kDebugMode || !position.isMocked);
  }

  /// Returns the device's real current GPS position.
  ///
  /// Waits for a fix accurate to within [_desiredAccuracyMeters] meters,
  /// up to [_fixTimeout]. If no sufficiently accurate fix arrives in time,
  /// the best fix seen so far is returned instead of failing outright —
  /// but if no fix at all is obtained, a [LocationServiceException] is
  /// thrown. There is no IP-based or hardcoded fallback: an error is always
  /// preferable to reporting the wrong location.
  ///
  /// Two classes of bad readings are explicitly rejected here, since they
  /// are the most common causes of an app reporting the wrong country:
  ///  1. Mocked/fake-GPS positions (`position.isMocked`) — e.g. an emulator,
  ///     a "fake GPS" app, or a spoofing tool.
  ///  2. Stale cached fixes — the platform's fused location provider can
  ///     hand back an old reading (sometimes from a previous country the
  ///     device visited) with a deceptively good accuracy value. We only
  ///     trust fixes timestamped at or after the moment we asked for one.
  Future<Position> getCurrentPosition() async {
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) {
      throw LocationServiceException(
          'Location permission denied or location services are disabled.');
    }

    final requestStartedAt = DateTime.now();
    final completer = Completer<Position>();
    StreamSubscription<Position>? subscription;
    Timer? timeoutTimer;
    Position? bestPosition;

    void cleanUp() {
      timeoutTimer?.cancel();
      subscription?.cancel();
    }

    timeoutTimer = Timer(_fixTimeout, () {
      if (completer.isCompleted) return;
      if (bestPosition != null) {
        // Didn't reach the desired accuracy in time, but we have a real,
        // fresh GPS reading — return the best one rather than failing.
        completer.complete(bestPosition);
      } else {
        completer.completeError(
          LocationServiceException(
              'Timed out waiting for a GPS fix. Make sure you are outdoors '
              'or near a window and try again.'),
        );
      }
      cleanUp();
    });

    // Try to get the current position directly first to avoid waiting for stream updates when stationary
    try {
      Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, // Changed from high to prevent 10s hang on load
        ),
      ).then((position) {
        if (completer.isCompleted) return;
        if (position.isMocked && !kDebugMode) return;

        final isStale = position.timestamp
            .isBefore(requestStartedAt.subtract(const Duration(seconds: 10)));
        if (!isStale && position.accuracy <= _desiredAccuracyMeters) {
          completer.complete(position);
          cleanUp();
        } else {
          if (bestPosition == null || position.accuracy < bestPosition!.accuracy) {
            bestPosition = position;
          }
        }
      }).catchError((_) {
        // Ignore error; the stream subscription below will handle it
      });
    } catch (_) {
      // Ignore synchronous exception; the stream subscription below will handle it
    }

    try {
      subscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).listen(
        (position) {
          // Never trust a mocked/spoofed location for a food-delivery app —
          // this alone explains most "wrong country" reports on emulators
          // or devices with a fake-GPS app installed.
          if (position.isMocked && !kDebugMode) return;

          // Discard cached fixes reported from before we started this
          // request (allowing a few seconds of clock/driver slack).
          final isStale = position.timestamp
              .isBefore(requestStartedAt.subtract(const Duration(seconds: 5)));
          if (isStale) return;

          if (bestPosition == null || position.accuracy < bestPosition!.accuracy) {
            bestPosition = position;
          }
          if (position.accuracy <= _desiredAccuracyMeters && !completer.isCompleted) {
            completer.complete(position);
            cleanUp();
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(
                LocationServiceException('Failed to read GPS location: $error'));
          }
          cleanUp();
        },
        cancelOnError: true,
      );
    } catch (e) {
      cleanUp();
      throw LocationServiceException('Unable to start GPS location updates: $e');
    }

    return completer.future;
  }

  /// Forward-geocodes a free-text query (e.g. "123 Main St, Cairo") into a
  /// list of candidate matches using Nominatim.
  Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return [];

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=json&q=${Uri.encodeComponent(trimmed)}&limit=5&addressdetails=1',
      );

      final response = await http
          .get(url, headers: {'User-Agent': 'GourmetGoApp/1.0'})
          .timeout(_networkTimeout);

      if (response.statusCode != 200) return [];

      final decoded = json.decode(response.body);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map((item) {
            final lat = double.tryParse(item['lat']?.toString() ?? '');
            final lon = double.tryParse(item['lon']?.toString() ?? '');
            if (lat == null || lon == null) return null;
            return {
              'display_name': item['display_name']?.toString() ?? '',
              'lat': lat,
              'lon': lon,
            };
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } on TimeoutException {
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Reverse-geocodes GPS coordinates into a structured, human-readable
  /// address using Nominatim.
  Future<StructuredAddress> reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );

      final response = await http
          .get(url, headers: {'User-Agent': 'GourmetGoApp/1.0'})
          .timeout(_networkTimeout);

      if (response.statusCode != 200) {
        return _fallbackAddress(lat, lng);
      }

      final data = json.decode(response.body);
      if (data is! Map<String, dynamic>) {
        return _fallbackAddress(lat, lng);
      }

      final addr = (data['address'] as Map<String, dynamic>?) ?? {};
      final fullAddr = data['display_name']?.toString() ?? '';

      // Nominatim uses different address-component keys depending on the
      // country and how that region is mapped in OpenStreetMap. To work
      // everywhere on Earth (dense cities, rural areas, GCC-style districts,
      // Japanese chome/ward naming, etc.) we try a broad, ordered list of
      // candidate keys for each field and take the first one present.
      final street = _firstNonEmpty(addr, [
        'road',
        'pedestrian',
        'residential',
        'street',
        'footway',
        'cycleway',
      ]);
      final district = _firstNonEmpty(addr, [
        'neighbourhood',
        'suburb',
        'quarter',
        'city_district',
        'district',
        'borough',
        'residential',
      ]);
      final city = _firstNonEmpty(addr, [
        'city',
        'town',
        'village',
        'municipality',
        'county',
        'state_district',
      ]);
      final state = _firstNonEmpty(addr, [
        'state',
        'region',
        'province',
        'state_district',
      ]);
      final country = _firstNonEmpty(addr, ['country']);
      final postcode = _firstNonEmpty(addr, ['postcode', 'post_code', 'zip']);

      return StructuredAddress(
        fullAddress: fullAddr.isNotEmpty ? fullAddr : _coordinateLabel(lat, lng),
        street: street,
        district: district,
        city: city,
        state: state,
        country: country,
        postcode: postcode,
      );
    } on TimeoutException {
      return _fallbackAddress(lat, lng);
    } catch (_) {
      return _fallbackAddress(lat, lng);
    }
  }

  /// Returns the first non-empty string value found in [map] among [keys],
  /// or '' if none are present. Used to handle the many different address
  /// component naming conventions Nominatim returns across countries.
  String _firstNonEmpty(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  StructuredAddress _fallbackAddress(double lat, double lng) {
    return StructuredAddress(fullAddress: _coordinateLabel(lat, lng));
  }

  String _coordinateLabel(double lat, double lng) {
    return 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}';
  }

  /// Straight-line distance in meters between two coordinates.
  double calculateDistanceInMeters(
      double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}