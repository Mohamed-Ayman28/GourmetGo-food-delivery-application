import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gourmet_go/consts/appColors.dart';
import 'package:gourmet_go/features/order_tracking/core/services/location_service.dart';

class DeliveryAddressesScreen extends StatefulWidget {
  const DeliveryAddressesScreen({super.key});

  @override
  State<DeliveryAddressesScreen> createState() => _DeliveryAddressesScreenState();
}

class _DeliveryAddressesScreenState extends State<DeliveryAddressesScreen> {
  final LocationService _locationService = LocationService();
  bool _isLoadingLocation = false;
  String? _currentAddress;
  double? _currentLat;
  double? _currentLng;

  final List<Map<String, dynamic>> _savedAddresses = [];
  String _selectedAddressId = 'current';

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
  }

  Future<void> _loadSavedAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAddr = prefs.getString('user_delivery_address');
    final savedLat = prefs.getDouble('user_delivery_lat');
    final savedLng = prefs.getDouble('user_delivery_lng');

    setState(() {
      _savedAddresses.clear();
      if (savedAddr != null && savedAddr.isNotEmpty) {
        _currentAddress = savedAddr;
        _currentLat = savedLat;
        _currentLng = savedLng;
        _savedAddresses.add({
          'id': 'current',
          'title': 'Current Location',
          'address': _currentAddress,
          'icon': Icons.my_location_rounded,
          'lat': _currentLat,
          'lng': _currentLng,
        });
      } else {
        _currentAddress = null;
        _currentLat = null;
        _currentLng = null;
      }
    });
  }

  void _openMapPicker() {
    final mapController = MapController();
    double tempLat = _currentLat ?? 30.0444;
    double tempLng = _currentLng ?? 31.2357;
    String tempAddress = _currentAddress ?? 'Tap on map or detect GPS...';
    bool isDetectingGps = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Pick Exact Location on Map',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(bottomCtx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: mapController,
                        options: MapOptions(
                          initialCenter: LatLng(tempLat, tempLng),
                          initialZoom: 16.0,
                          onTap: (tapPos, point) async {
                            tempLat = point.latitude;
                            tempLng = point.longitude;
                            mapController.move(point, mapController.camera.zoom);
                            final addr = await _locationService.reverseGeocode(tempLat, tempLng);
                            setModalState(() {
                              tempAddress = addr.fullAddress;
                            });
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
                                point: LatLng(tempLat, tempLng),
                                width: 50,
                                height: 50,
                                child: const Icon(
                                  Icons.location_on,
                                  color: AppColors.primary,
                                  size: 48,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Search Location Bar Overlay
                      Positioned(
                        top: 12,
                        left: 16,
                        right: 70,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Search city, street, or area...',
                              prefixIcon: Icon(Icons.search, color: AppColors.primary),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            onSubmitted: (query) async {
                              final results = await _locationService.searchAddress(query);
                              if (results.isNotEmpty) {
                                final first = results.first;
                                tempLat = first['lat'];
                                tempLng = first['lon'];
                                tempAddress = first['display_name'];
                                setModalState(() {});
                                mapController.move(LatLng(tempLat, tempLng), 16.0);
                              }
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        right: 16,
                        top: 12,
                        child: FloatingActionButton.small(
                          heroTag: 'map_picker_gps_btn',
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          elevation: 4,
                          onPressed: isDetectingGps
                              ? null
                              : () async {
                                  setModalState(() => isDetectingGps = true);
                                  try {
                                    final ok = await _locationService
                                        .promptLocationPermissionDialog(context);
                                    if (!ok) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Location permission denied or GPS is turned off.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    // Real GPS fix only — anti-spoof and
                                    // anti-stale checks live in LocationService.
                                    final pos = await _locationService.getCurrentPosition();
                                    final addr = await _locationService.reverseGeocode(
                                        pos.latitude, pos.longitude);

                                    if (!context.mounted) return;

                                    tempLat = pos.latitude;
                                    tempLng = pos.longitude;
                                    setModalState(() {
                                      tempAddress = addr.fullAddress;
                                    });

                                    mapController.move(
                                        LatLng(pos.latitude, pos.longitude), 16.0);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('GPS Error: $e'),
                                          backgroundColor: Colors.red.shade700,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setModalState(() => isDetectingGps = false);
                                    }
                                  }
                                },
                          child: isDetectingGps
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.primary,
                                  ),
                                )
                              : const Icon(Icons.my_location),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tempAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('user_delivery_address', tempAddress);
                            await prefs.setDouble('user_delivery_lat', tempLat);
                            await prefs.setDouble('user_delivery_lng', tempLng);

                            setState(() {
                              _currentAddress = tempAddress;
                              _currentLat = tempLat;
                              _currentLng = tempLng;
                              _selectedAddressId = 'current';

                              final idx = _savedAddresses.indexWhere((a) => a['id'] == 'current');
                              if (idx != -1) {
                                _savedAddresses[idx]['address'] = tempAddress;
                                _savedAddresses[idx]['lat'] = tempLat;
                                _savedAddresses[idx]['lng'] = tempLng;
                              } else {
                                _savedAddresses.add({
                                  'id': 'current',
                                  'title': 'Current Location',
                                  'address': tempAddress,
                                  'icon': Icons.my_location_rounded,
                                  'lat': tempLat,
                                  'lng': tempLng,
                                });
                              }
                            });

                            Navigator.pop(bottomCtx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Location updated to: $tempAddress'),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          child: const Text(
                            'Confirm Location',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Detects the device's real GPS location and stores it as the current
  /// delivery address. Reverse geocoding is delegated entirely to
  /// [LocationService.reverseGeocode] so there is exactly one, well-tested
  /// implementation of "coordinates -> worldwide address" in the app —
  /// no duplicated parsing logic that can drift out of sync or disagree.
  Future<void> _setCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final hasPermission = await _locationService.promptLocationPermissionDialog(context);
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location permission denied or services disabled.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Real device GPS fix only — no cached/mocked/IP-based location.
      final position = await _locationService.getCurrentPosition();
      final lat = position.latitude;
      final lng = position.longitude;

      final address = await _locationService.reverseGeocode(lat, lng);
      final formattedAddress = address.fullAddress;

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_delivery_address', formattedAddress);
      await prefs.setDouble('user_delivery_lat', lat);
      await prefs.setDouble('user_delivery_lng', lng);

      if (!mounted) return;

      setState(() {
        _currentAddress = formattedAddress;
        _currentLat = lat;
        _currentLng = lng;
        _selectedAddressId = 'current';

        // Update or add item in list
        final idx = _savedAddresses.indexWhere((a) => a['id'] == 'current');
        if (idx != -1) {
          _savedAddresses[idx]['address'] = formattedAddress;
          _savedAddresses[idx]['lat'] = lat;
          _savedAddresses[idx]['lng'] = lng;
        } else {
          _savedAddresses.add({
            'id': 'current',
            'title': 'Current Location',
            'address': formattedAddress,
            'icon': Icons.my_location_rounded,
            'lat': lat,
            'lng': lng,
          });
        }
        _isLoadingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delivery location updated to: $formattedAddress'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get current location: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _selectAddress(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final address = item['address'] as String?;
    final lat = item['lat'] as double?;
    final lng = item['lng'] as double?;

    // Only persist fields that actually exist for this saved address.
    // Never substitute a hardcoded city/country as a stand-in for missing
    // coordinates — that's exactly how a delivery app ends up quietly
    // routing an order to the wrong country.
    if (address != null) {
      await prefs.setString('user_delivery_address', address);
    }
    if (lat != null) {
      await prefs.setDouble('user_delivery_lat', lat);
    }
    if (lng != null) {
      await prefs.setDouble('user_delivery_lng', lng);
    }

    setState(() {
      _selectedAddressId = item['id'];
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected "${item['title']}" as delivery address'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Delivery Addresses',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Set Current Location Button Card ──
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isLoadingLocation ? null : _setCurrentLocation,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: _isLoadingLocation
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Set Current Location',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isLoadingLocation
                                    ? 'Detecting your GPS location...'
                                    : 'Tap to use device GPS location',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _openMapPicker,
                icon: const Icon(Icons.map_rounded, color: AppColors.primary),
                label: const Text(
                  'Choose Location on Map',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Saved Addresses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // ── Saved Addresses List / Empty State ──
            if (_savedAddresses.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.location_off_outlined,
                        size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    Text(
                      'No location set yet',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "Set Current Location" above to detect your current position via GPS.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _savedAddresses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _savedAddresses[index];
                final isSelected = _selectedAddressId == item['id'];

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _selectAddress(item),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                item['icon'] as IconData,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        item['title'] as String,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.success
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Active',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['address'] as String,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Radio<String>(
                              value: item['id'] as String,
                              groupValue: _selectedAddressId,
                              activeColor: AppColors.primary,
                              onChanged: (_) => _selectAddress(item),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}