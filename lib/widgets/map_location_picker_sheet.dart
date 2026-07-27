import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../consts/appColors.dart';
import '../features/order_tracking/core/services/location_service.dart';
import 'custom_snackbar.dart';

/// Interactive Map Location Picker modal sheet matching the modern map UI.
/// Includes top search bar, GPS target button, center location marker,
/// reverse geocoding, and a bottom card with address & 'Confirm Location' button.
class MapLocationPickerSheet extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;
  final Function(double lat, double lng, String address) onLocationConfirmed;

  const MapLocationPickerSheet({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialAddress,
    required this.onLocationConfirmed,
  });

  static Future<void> show(
    BuildContext context, {
    double? initialLat,
    double? initialLng,
    String? initialAddress,
    required Function(double lat, double lng, String address) onLocationConfirmed,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MapLocationPickerSheet(
        initialLat: initialLat,
        initialLng: initialLng,
        initialAddress: initialAddress,
        onLocationConfirmed: onLocationConfirmed,
      ),
    );
  }

  @override
  State<MapLocationPickerSheet> createState() => _MapLocationPickerSheetState();
}

class _MapLocationPickerSheetState extends State<MapLocationPickerSheet> {
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  late double _tempLat;
  late double _tempLng;
  String _tempAddress = 'Tap map or search location...';
  bool _isDetectingGps = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tempLat = widget.initialLat ?? 30.0444; // Default to Cairo if null
    _tempLng = widget.initialLng ?? 31.2357;
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _tempAddress = widget.initialAddress!;
    } else {
      _reverseGeocodeCurrentPos();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocodeCurrentPos() async {
    try {
      final addr = await _locationService.reverseGeocode(_tempLat, _tempLng);
      if (mounted && addr.fullAddress.isNotEmpty) {
        setState(() {
          _tempAddress = addr.fullAddress;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);
    FocusScope.of(context).unfocus();

    try {
      final results = await _locationService.searchAddress(query);
      if (results.isNotEmpty) {
        final first = results.first;
        final lat = first['lat'] as double;
        final lon = first['lon'] as double;
        final display = first['display_name'] as String;

        setState(() {
          _tempLat = lat;
          _tempLng = lon;
          _tempAddress = display;
        });

        _mapController.move(LatLng(lat, lon), 16.0);
      } else {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: 'No location matches found for "$query".',
            type: SnackBarType.warning,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Error searching address: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _detectGpsLocation() async {
    setState(() => _isDetectingGps = true);
    try {
      final ok = await _locationService.promptLocationPermissionDialog(context);
      if (!ok) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: 'Location permission denied or GPS is turned off.',
            type: SnackBarType.error,
          );
        }
        return;
      }

      final pos = await _locationService.getCurrentPosition();
      final addr = await _locationService.reverseGeocode(pos.latitude, pos.longitude);

      if (!mounted) return;

      setState(() {
        _tempLat = pos.latitude;
        _tempLng = pos.longitude;
        _tempAddress = addr.fullAddress;
      });

      _mapController.move(LatLng(pos.latitude, pos.longitude), 16.0);
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'GPS Error: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isDetectingGps = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Stack(
          children: [
            // ── Full Map ──
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(_tempLat, _tempLng),
                initialZoom: 16.0,
                onTap: (tapPos, point) async {
                  setState(() {
                    _tempLat = point.latitude;
                    _tempLng = point.longitude;
                  });
                  _mapController.move(point, _mapController.camera.zoom);

                  final addr = await _locationService.reverseGeocode(
                    point.latitude,
                    point.longitude,
                  );
                  if (mounted) {
                    setState(() {
                      _tempAddress = addr.fullAddress;
                    });
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.gourmet_go',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_tempLat, _tempLng),
                      width: 50,
                      height: 50,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                            size: 46,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ── Top Search Bar Overlay (Left) ──
            Positioned(
              top: 16,
              left: 16,
              right: 74,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _handleSearch,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search city, street, or area...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                    prefixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(14.0),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.search,
                            color: AppColors.primary,
                            size: 22,
                          ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (val) => setState(() {}),
                ),
              ),
            ),

            // ── Top GPS Target Button Overlay (Right) ──
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _isDetectingGps ? null : _detectGpsLocation,
                    child: Center(
                      child: _isDetectingGps
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(
                              Icons.my_location_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom Address & Confirm Location Card ──
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _tempAddress,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          widget.onLocationConfirmed(_tempLat, _tempLng, _tempAddress);
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Confirm Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
