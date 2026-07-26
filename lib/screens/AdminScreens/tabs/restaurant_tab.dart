import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../consts/appColors.dart';
import '../../../widgets/admin_widgets.dart';
import 'package:gourmet_go/features/order_tracking/core/services/location_service.dart';

class RestaurantTab extends StatefulWidget {
  const RestaurantTab({super.key});

  @override
  State<RestaurantTab> createState() => _RestaurantTabState();
}

class _RestaurantTabState extends State<RestaurantTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _feeController = TextEditingController();
  final _openHourController = TextEditingController();
  final _closeHourController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController(text: '40.735610');
  final _lngController = TextEditingController(text: '-73.991270');
  bool _isOpen = true;
  bool _isLoading = false;
  bool _isDetectingLocation = false;

  Future<void> _detectRestaurantLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      final loc = LocationService();
      final ok = await loc.promptLocationPermissionDialog(context);
      if (!ok) {
        if (!mounted) return;
        setState(() => _isDetectingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required to detect GPS.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final pos = await loc.getCurrentPosition();
      final addr = await loc.reverseGeocode(pos.latitude, pos.longitude);

      setState(() {
        if (addr.fullAddress.isNotEmpty) {
          _addressController.text = addr.fullAddress;
        }
        _latController.text = pos.latitude.toStringAsFixed(6);
        _lngController.text = pos.longitude.toStringAsFixed(6);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(addr.fullAddress.isNotEmpty
              ? 'GPS Detected: ${addr.fullAddress}'
              : 'GPS Detected: ${pos.latitude}, ${pos.longitude}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get current location: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final doc = await FirebaseFirestore.instance.collection('restaurant_info').doc('default').get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _nameController.text = data['name'] ?? '';
        _feeController.text = (data['deliveryFee'] ?? 0).toString();
        _openHourController.text = data['openingHour'] ?? '';
        _closeHourController.text = data['closingHour'] ?? '';
        _addressController.text = data['address'] ?? '';
        if (data['latitude'] != null) {
          _latController.text = data['latitude'].toString();
        }
        if (data['longitude'] != null) {
          _lngController.text = data['longitude'].toString();
        }
        _isOpen = data['isOpen'] ?? true;
      });
    }
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final lat = double.tryParse(_latController.text.trim()) ?? 40.735610;
      final lng = double.tryParse(_lngController.text.trim()) ?? -73.991270;

      await FirebaseFirestore.instance.collection('restaurant_info').doc('default').set({
        'name': _nameController.text.trim(),
        'deliveryFee': double.tryParse(_feeController.text.trim()) ?? 0.0,
        'openingHour': _openHourController.text.trim(),
        'closingHour': _closeHourController.text.trim(),
        'address': _addressController.text.trim(),
        'latitude': lat,
        'longitude': lng,
        'isOpen': _isOpen,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('restaurant_lat', lat);
      await prefs.setDouble('restaurant_lng', lng);
      await prefs.setString('restaurant_address', _addressController.text.trim());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved successfully!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMapPicker() {
    final mapController = MapController();
    double tempLat = double.tryParse(_latController.text) ?? 30.0444;
    double tempLng = double.tryParse(_lngController.text) ?? 31.2357;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Select Restaurant Location on Map'),
            content: SizedBox(
              width: double.maxFinite,
              height: 380,
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FlutterMap(
                        mapController: mapController,
                        options: MapOptions(
                          initialCenter: LatLng(tempLat, tempLng),
                          initialZoom: 14.0,
                          onTap: (tapPos, point) {
                            setDialogState(() {
                              tempLat = point.latitude;
                              tempLng = point.longitude;
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
                                child: const Icon(
                                  Icons.storefront_rounded,
                                  color: AppColors.primary,
                                  size: 38,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Position • (${tempLat.toStringAsFixed(5)}, ${tempLng.toStringAsFixed(5)})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.my_location, size: 16),
                label: const Text('Detect GPS'),
                onPressed: () async {
                  try {
                    final loc = LocationService();
                    final ok = await loc.promptLocationPermissionDialog(context);
                    if (!ok) return;

                    final pos = await loc.getCurrentPosition();
                    setDialogState(() {
                      tempLat = pos.latitude;
                      tempLng = pos.longitude;
                    });
                    mapController.move(LatLng(pos.latitude, pos.longitude), 15.0);

                    final addr = await loc.reverseGeocode(pos.latitude, pos.longitude);
                    if (addr.fullAddress.isNotEmpty) {
                      _addressController.text = addr.fullAddress;
                    }
                    _latController.text = pos.latitude.toStringAsFixed(6);
                    _lngController.text = pos.longitude.toStringAsFixed(6);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('GPS Detected: ${addr.fullAddress}'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Location error: $e'),
                          backgroundColor: Colors.red.shade700,
                        ),
                      );
                    }
                  }
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () async {
                  try {
                    final loc = LocationService();
                    final addr = await loc.reverseGeocode(tempLat, tempLng);
                    if (addr.fullAddress.isNotEmpty) {
                      _addressController.text = addr.fullAddress;
                    }
                  } catch (_) {}
                  setState(() {
                    _latController.text = tempLat.toStringAsFixed(6);
                    _lngController.text = tempLng.toStringAsFixed(6);
                  });
                  Navigator.pop(dialogCtx);
                },
                child: const Text('Set Location', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Restaurant Configuration', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 24),
                    SwitchListTile(
                      title: const Text('Currently Accepting Orders', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_isOpen ? 'Online' : 'Offline', style: TextStyle(color: _isOpen ? AppColors.success : AppColors.error)),
                      value: _isOpen,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => _isOpen = val),
                    ),
                    const Divider(),
                    const SizedBox(height: 16),
                    AdminTextField(
                      controller: _nameController,
                      label: 'Restaurant Name',
                      icon: Icons.store,
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    AdminTextField(
                      controller: _feeController,
                      label: 'Standard Delivery Fee (\$)',
                      icon: Icons.delivery_dining,
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: AdminTextField(
                            controller: _openHourController,
                            label: 'Opening Hour (e.g. 09:00 AM)',
                            icon: Icons.access_time,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AdminTextField(
                            controller: _closeHourController,
                            label: 'Closing Hour (e.g. 11:00 PM)',
                            icon: Icons.access_time_filled,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    // ── Restaurant Location Section ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Restaurant Location',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        TextButton.icon(
                          onPressed: _isDetectingLocation
                              ? null
                              : _detectRestaurantLocation,
                          icon: _isDetectingLocation
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary))
                              : const Icon(Icons.my_location_rounded,
                                  color: AppColors.primary, size: 18),
                          label: Text(
                              _isDetectingLocation
                                  ? 'Detecting...'
                                  : 'Detect GPS',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600)),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AdminTextField(
                      controller: _addressController,
                      label: 'Restaurant Address',
                      icon: Icons.location_on,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AdminTextField(
                            controller: _latController,
                            label: 'Latitude',
                            icon: Icons.map,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AdminTextField(
                            controller: _lngController,
                            label: 'Longitude',
                            icon: Icons.map_outlined,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _showMapPicker,
                        icon: const Icon(Icons.map, color: AppColors.primary),
                        label: const Text('Choose Location on Map', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isLoading ? null : _saveData,
                        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
