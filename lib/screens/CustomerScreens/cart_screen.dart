import 'package:gourmet_go/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:gourmet_go/consts/appColors.dart';
import 'package:gourmet_go/features/order_tracking/domain/entities/order_entity.dart';
import 'package:gourmet_go/features/order_tracking/presentation/pages/customer_tracking_screen.dart';
import 'package:gourmet_go/helper/customer_user_helper.dart';
import 'package:gourmet_go/helper/cart_manager.dart';
import 'package:gourmet_go/models/cart_item.dart';


import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gourmet_go/features/order_tracking/core/services/location_service.dart';
import 'delivery_addresses_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartManager _cartManager = CartManager();

  // Selected payment method
  String _selectedPayment = 'Card';

  // Delivery details state
  String _deliveryLocationName = "Detecting GPS Location...";
  String _deliveryAddress = "Loading your current location...";

  @override
  void initState() {
    super.initState();
    // Add listener so the state rebuilds when the cart updates
    _cartManager.addListener(_onCartChanged);
    _loadSavedDeliveryAddress();
  }

  Future<void> _loadSavedDeliveryAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAddr = prefs.getString('user_delivery_address');
    if (savedAddr != null && savedAddr.isNotEmpty && mounted) {
      setState(() {
        _deliveryAddress = savedAddr;
        _deliveryLocationName = "Current Delivery Location";
      });
      return;
    }

    // Auto-detect real device GPS location if no address saved yet
    try {
      final locService = LocationService();
      final hasPerm = await locService.checkAndRequestPermissions();
      if (hasPerm) {
        final pos = await locService.getCurrentPosition();
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&zoom=18&addressdetails=1',
        );
        final res = await http.get(url, headers: {'User-Agent': 'GourmetGoApp/1.0'});
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final displayName = data['display_name'] ?? '';
          if (displayName.isNotEmpty && mounted) {
            await prefs.setString('user_delivery_address', displayName);
            await prefs.setDouble('user_delivery_lat', pos.latitude);
            await prefs.setDouble('user_delivery_lng', pos.longitude);
            setState(() {
              _deliveryAddress = displayName;
              _deliveryLocationName = "GPS Current Location";
            });
            return;
          }
        }
      }
    } catch (_) {}

    // Fallback if location permission or GPS unavailable
    if (mounted) {
      setState(() {
        _deliveryAddress = "100 Mott St, New York, NY 10013";
        _deliveryLocationName = "Default Delivery Address";
      });
    }
  }

  @override
  void dispose() {
    _cartManager.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showChangeAddressSheet() {
    final nameController = TextEditingController(text: _deliveryLocationName);
    final addressController = TextEditingController(text: _deliveryAddress);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Change Delivery Address',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Location Label',
                  hintText: 'e.g. Home, Work, Greenwich Village',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Full Address',
                  hintText: 'Street, Apartment, City, State, ZIP',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty &&
                        addressController.text.isNotEmpty) {
                      setState(() {
                        _deliveryLocationName = nameController.text.trim();
                        _deliveryAddress = addressController.text.trim();
                      });
                      Navigator.pop(ctx);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Save Address',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // Detailed checkout state controllers
  final TextEditingController _buildingController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _apartmentController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _deliveryNotesController = TextEditingController();
  final TextEditingController _orderNotesController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController(text: '+1 555-0199');

  double get _subtotal => _cartManager.total;
  double get _deliveryFee => 2.99;
  double get _serviceFee => 1.50;
  double get _tax => _subtotal * 0.08;
  double get _grandTotal => _subtotal + _deliveryFee + _serviceFee + _tax;

  void _onPlaceOrder() {
    if (_cartManager.items.isEmpty) {
      CustomSnackBar.show(context, message: 'Your cart is empty! Add some delicious food first.', type: SnackBarType.info);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Checkout Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Delivery Address Section ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Delivery Address',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.edit_location_alt_rounded, size: 18),
                                label: const Text('Change'),
                                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const DeliveryAddressesScreen(),
                                    ),
                                  );
                                  await _loadSavedDeliveryAddress();
                                },
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_rounded, color: AppColors.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _deliveryAddress,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _buildingController,
                                  decoration: InputDecoration(
                                    labelText: 'Building',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _floorController,
                                  decoration: InputDecoration(
                                    labelText: 'Floor',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _apartmentController,
                                  decoration: InputDecoration(
                                    labelText: 'Apt / Suite',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _landmarkController,
                            decoration: InputDecoration(
                              labelText: 'Landmark (Optional)',
                              hintText: 'e.g. Near Central Park West gate',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _deliveryNotesController,
                            decoration: InputDecoration(
                              labelText: 'Delivery Instructions for Driver',
                              hintText: 'e.g. Leave at door, call upon arrival',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Contact & Notes ──
                          const Text(
                            'Customer Contact',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: const Icon(Icons.phone, size: 18),
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _orderNotesController,
                            decoration: InputDecoration(
                              labelText: 'Kitchen Order Notes (Optional)',
                              hintText: 'e.g. Extra napkins, no cutlery',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Payment Method ──
                          const Text(
                            'Payment Method',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: ['Card', 'Apple Pay', 'Cash'].map((method) {
                              final isSel = _selectedPayment == method;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      _selectedPayment = method;
                                    });
                                    setState(() {});
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSel ? AppColors.primary : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSel ? AppColors.primary : AppColors.border,
                                      ),
                                    ),
                                    child: Text(
                                      method,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isSel ? Colors.white : AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 20),

                          // ── Financial Breakdown ──
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                _summaryRow('Subtotal', '\$${_subtotal.toStringAsFixed(2)}'),
                                _summaryRow('Delivery Fee', '\$${_deliveryFee.toStringAsFixed(2)}'),
                                _summaryRow('Service Fee', '\$${_serviceFee.toStringAsFixed(2)}'),
                                _summaryRow('Tax (8%)', '\$${_tax.toStringAsFixed(2)}'),
                                const Divider(height: 16),
                                _summaryRow(
                                  'Total Amount',
                                  '\$${_grandTotal.toStringAsFixed(2)}',
                                  isBold: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _submitOrderToFirestore();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'Confirm & Place Order • \$${_grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 16 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOrderToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    final customerId = await CustomerUserHelper.getCustomerId();
    if (!mounted) return;
    final customerName = (user?.displayName != null && user!.displayName!.isNotEmpty)
        ? user.displayName!
        : 'Gourmet Customer';

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      double lat = prefs.getDouble('user_delivery_lat') ?? 0.0;
      double lng = prefs.getDouble('user_delivery_lng') ?? 0.0;

      // If lat/lng missing, attempt immediate high-accuracy GPS fix
      if (lat == 0.0 || lng == 0.0) {
        try {
          final loc = LocationService();
          if (await loc.checkAndRequestPermissions()) {
            final pos = await loc.getCurrentPosition();
            lat = pos.latitude;
            lng = pos.longitude;
            await prefs.setDouble('user_delivery_lat', lat);
            await prefs.setDouble('user_delivery_lng', lng);
          }
        } catch (_) {}
      }

      // Query active restaurant info configured by Admin
      double restLat = lat != 0.0 ? (lat + 0.0075) : 0.0;
      double restLng = lng != 0.0 ? (lng + 0.0075) : 0.0;
      String restaurantName = 'Gourmet GO Kitchen';
      String restaurantPhone = '+1 800-468-7638';

      try {
        final restDoc = await FirebaseFirestore.instance
            .collection('restaurant_info')
            .doc('default')
            .get();
        if (restDoc.exists) {
          final rData = restDoc.data()!;
          if (rData['latitude'] != null && rData['longitude'] != null) {
            restLat = (rData['latitude'] as num).toDouble();
            restLng = (rData['longitude'] as num).toDouble();
          }
          if (rData['name'] != null && (rData['name'] as String).isNotEmpty) {
            restaurantName = rData['name'];
          }
          if (rData['phone'] != null && (rData['phone'] as String).isNotEmpty) {
            restaurantPhone = rData['phone'];
          }
        }
      } catch (_) {}

      final docRef = FirebaseFirestore.instance.collection('orders').doc();
      final orderId = docRef.id;
      final orderNumber = '#${orderId.substring(0, 5).toUpperCase()}';

      final itemsData = _cartManager.items.map((item) {
        return {
          'name': item.foodItem.name,
          'quantity': item.quantity,
          'imageUrl': item.foodItem.img,
        };
      }).toList();

      final now = DateTime.now();

      await docRef.set({
        'id': orderId,
        'orderNumber': orderNumber,
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : '+1 555-0199',
        'customerAddress': _deliveryAddress,
        'customerLat': lat,
        'customerLng': lng,
        'buildingNumber': _buildingController.text.trim(),
        'floor': _floorController.text.trim(),
        'apartment': _apartmentController.text.trim(),
        'landmark': _landmarkController.text.trim(),
        'deliveryNotes': _deliveryNotesController.text.trim(),
        'restaurantName': restaurantName,
        'restaurantPhone': restaurantPhone,
        'restaurantLat': restLat,
        'restaurantLng': restLng,
        'status': OrderStatus.pending.name,
        'items': itemsData,
        'subtotal': _subtotal,
        'deliveryFee': _deliveryFee,
        'serviceFee': _serviceFee,
        'tax': _tax,
        'discount': 0.0,
        'totalAmount': _grandTotal,
        'paymentMethod': _selectedPayment,
        'orderNotes': _orderNotesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'estimatedArrival': Timestamp.fromDate(now.add(const Duration(minutes: 35))),
      });

      _cartManager.clearCart();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Navigate directly to Customer Tracking Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerTrackingScreen(
            orderId: orderId,
            customerId: customerId,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place order: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final emptyCart = _cartManager.items.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'GourmetGo',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: emptyCart ? _buildEmptyCartState() : _buildCartContent(),
      bottomNavigationBar: emptyCart ? null : _buildStickyBottomBar(),
    );
  }

  Widget _buildEmptyCartState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Cart is Empty',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Browse our delicious menu categories to add items here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
              child: const Text(
                'Explore Menu',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Review Your Order',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Order items list
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _cartManager.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, idx) =>
                  _buildCartItemCard(_cartManager.items[idx]),
            ),

            const SizedBox(height: 24),

            // Delivery Panel
            _buildDeliveryPanel(),

            const SizedBox(height: 24),

            // Payment Panel
            _buildPaymentPanel(),

            const SizedBox(height: 24),

            // Pricing summary card
            _buildPriceSummary(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItemCard(CartItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Food Image
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              item.foodItem.img,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 80,
                height: 80,
                color: AppColors.secondary,
                child: const Icon(
                  Icons.fastfood_rounded,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Details column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.foodItem.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.extrasSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${item.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),

                    // Quantity Counter Badge
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F6F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () =>
                                _cartManager.decrementQuantity(item.uniqueId),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.remove_rounded,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            alignment: Alignment.center,
                            child: Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                _cartManager.incrementQuantity(item.uniqueId),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.add_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.primary, width: 4),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'DELIVERY TO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary.withValues(alpha: 0.8),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _showChangeAddressSheet,
                    child: const Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _deliveryLocationName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _deliveryAddress,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PAYMENT METHOD',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary.withValues(alpha: 0.5),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildPaymentOption('Card', Icons.credit_card_rounded),
            const SizedBox(width: 12),
            _buildPaymentOption('Apple', Icons.grid_view_rounded),
            const SizedBox(width: 12),
            _buildPaymentOption('Cash', Icons.payments_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentOption(String method, IconData icon) {
    final isSelected = _selectedPayment == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPayment = method),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                method,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceSummary() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSummaryRow(
            'Subtotal',
            '\$${_cartManager.subtotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'Delivery Fee',
            _cartManager.deliveryFee == 0.0
                ? 'Free'
                : '\$${_cartManager.deliveryFee.toStringAsFixed(2)}',
            valueColor: _cartManager.deliveryFee == 0.0
                ? AppColors.success
                : AppColors.textPrimary,
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'Service Tax (8%)',
            '\$${_cartManager.serviceTax.toStringAsFixed(2)}',
          ),
          const Divider(height: 24, thickness: 1),
          _buildSummaryRow(
            'Total',
            '\$${_cartManager.total.toStringAsFixed(2)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isTotal = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 20 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.bold,
            color:
                valueColor ??
                (isTotal ? AppColors.primary : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Loyalty points notice banner
            Container(
              color: AppColors.primary.withValues(alpha: 0.06),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.stars_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w400,
                        ),
                        children: [
                          const TextSpan(text: "You're earning "),
                          TextSpan(
                            text:
                                "${_cartManager.loyaltyPointsEarned} GourmetPoints",
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(text: " with this order!"),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Placement check bar button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton(
                  onPressed: _onPlaceOrder,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Place Order',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '\$${_cartManager.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
