import 'package:gourmet_go/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../consts/appColors.dart';
import 'package:gourmet_go/features/order_tracking/core/services/location_service.dart';
import 'package:gourmet_go/widgets/map_location_picker_sheet.dart';

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
  final _latController = TextEditingController(text: '30.044400');
  final _lngController = TextEditingController(text: '31.235700');

  bool _isOpen = true;
  bool _isLoading = false;
  bool _isDetectingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _feeController.dispose();
    _openHourController.dispose();
    _closeHourController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
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

  Future<void> _detectRestaurantLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      final loc = LocationService();
      final ok = await loc.promptLocationPermissionDialog(context);
      if (!ok) {
        if (!mounted) return;
        setState(() => _isDetectingLocation = false);
        CustomSnackBar.show(context, message: 'Location permission is required to detect GPS.', type: SnackBarType.error);
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
      CustomSnackBar.show(
        context,
        message: addr.fullAddress.isNotEmpty ? 'GPS Detected: ${addr.fullAddress}' : 'GPS Detected',
        type: SnackBarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(context, message: 'Failed to get location: $e', type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final lat = double.tryParse(_latController.text.trim()) ?? 30.044400;
      final lng = double.tryParse(_lngController.text.trim()) ?? 31.235700;

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
      CustomSnackBar.show(context, message: 'Restaurant details updated successfully!', type: SnackBarType.success);
    } catch (e) {
      CustomSnackBar.show(context, message: 'Error saving changes: $e', type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMapPicker() {
    double initialLat = double.tryParse(_latController.text) ?? 30.0444;
    double initialLng = double.tryParse(_lngController.text) ?? 31.2357;

    MapLocationPickerSheet.show(
      context,
      initialLat: initialLat,
      initialLng: initialLng,
      initialAddress: _addressController.text,
      onLocationConfirmed: (lat, lng, address) {
        setState(() {
          _latController.text = lat.toStringAsFixed(6);
          _lngController.text = lng.toStringAsFixed(6);
          if (address.isNotEmpty) {
            _addressController.text = address;
          }
        });
        CustomSnackBar.show(
          context,
          message: 'Location confirmed!',
          type: SnackBarType.success,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFAF7F5),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top Store Header Banner ──
                  _buildHeaderBanner(),

                  const SizedBox(height: 20),

                  // ── Store Operating Status Card ──
                  _buildStatusCard(),

                  const SizedBox(height: 20),

                  // ── Store Details Form Card ──
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFEFE8E2)),
                    ),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'General Info',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Restaurant Name
                        _buildStyledTextField(
                          controller: _nameController,
                          label: 'Restaurant Name',
                          hint: 'Enter store name',
                          icon: Icons.storefront_rounded,
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),

                        // Delivery Fee
                        _buildStyledTextField(
                          controller: _feeController,
                          label: 'Standard Delivery Fee (\$)',
                          hint: '0.00',
                          icon: Icons.delivery_dining_rounded,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),

                        // Hours Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildStyledTextField(
                                controller: _openHourController,
                                label: 'Opening Hour',
                                hint: 'e.g. 09:00 AM',
                                icon: Icons.access_time_rounded,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildStyledTextField(
                                controller: _closeHourController,
                                label: 'Closing Hour',
                                hint: 'e.g. 11:00 PM',
                                icon: Icons.access_time_filled_rounded,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),
                        const Divider(height: 1, color: Color(0xFFF0EAE5)),
                        const SizedBox(height: 24),

                        // ── Location Section Header ──
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Restaurant Location',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Detect GPS Button
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: _isDetectingLocation ? null : _detectRestaurantLocation,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _isDetectingLocation
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.primary,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.my_location_rounded,
                                            color: AppColors.primary,
                                            size: 15,
                                          ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isDetectingLocation ? 'Detecting...' : 'Detect GPS',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Interactive Address Container Card
                        InkWell(
                          onTap: _showMapPicker,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8F5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFFFDCD0), width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.place_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _addressController.text.isNotEmpty
                                            ? _addressController.text
                                            : 'Tap to select restaurant location on map...',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _addressController.text.isNotEmpty
                                              ? AppColors.textPrimary
                                              : Colors.grey.shade500,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.gps_fixed, size: 12, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Lat: ${_latController.text} | Lng: ${_lngController.text}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.edit_location_alt_rounded,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Editable Address Text Field
                        _buildStyledTextField(
                          controller: _addressController,
                          label: 'Full Address',
                          hint: 'City, street, area details...',
                          icon: Icons.location_city_rounded,
                        ),

                        const SizedBox(height: 12),

                        // Latitude / Longitude Editable Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildStyledTextField(
                                controller: _latController,
                                label: 'Latitude',
                                hint: '30.044400',
                                icon: Icons.explore_rounded,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildStyledTextField(
                                controller: _lngController,
                                label: 'Longitude',
                                hint: '31.235700',
                                icon: Icons.compass_calibration_rounded,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Choose Location on Map Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _showMapPicker,
                            icon: const Icon(Icons.map_rounded, color: AppColors.primary, size: 20),
                            label: const Text(
                              'Choose Location on Map',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFF0EB),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: Color(0xFFFFCCB8), width: 1.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Save Changes Primary Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _isLoading ? null : _saveData,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8C42), Color(0xFFFF4500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Restaurant Setup',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage operating hours, delivery fees, and map location',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isOpen ? const Color(0xFFC8E6C9) : const Color(0xFFFFCDD2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isOpen
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isOpen ? Icons.storefront_rounded : Icons.store_mall_directory_outlined,
              color: _isOpen ? AppColors.success : AppColors.error,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Accepting Orders',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isOpen ? 'Online • Customers can place orders' : 'Offline • Store is currently closed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isOpen ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isOpen,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
            onChanged: (val) => setState(() => _isOpen = val),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.normal,
            ),
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E0DC)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E0DC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }
}
