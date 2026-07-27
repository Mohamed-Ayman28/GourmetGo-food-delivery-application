import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../../domain/entities/order_entity.dart';

abstract class OrderRemoteDataSource {
  Stream<List<OrderModel>> streamCustomerOrders(String customerId);
  Stream<List<OrderModel>> streamAllActiveOrders();
  Stream<List<OrderModel>> streamDriverOrders(String driverId);
  Future<void> updateOrderStatus(String orderId, OrderStatus status);
  Future<void> assignDriver(String orderId, String driverId);
  Future<List<Map<String, dynamic>>> fetchAvailableDrivers();
  Future<void> deleteOrder(String orderId);
}

class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  final FirebaseFirestore _firestore;

  OrderRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<OrderModel>> streamCustomerOrders(String customerId) {
    return _firestore
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromJson(doc.data(), doc.id))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  @override
  Stream<List<OrderModel>> streamAllActiveOrders() {
    return _firestore
        .collection('orders')
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromJson(doc.data(), doc.id))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  @override
  Stream<List<OrderModel>> streamDriverOrders(String driverId) {
    return _firestore
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: [
          OrderStatus.driverAssigned.name,
          OrderStatus.driverAccepted.name,
          OrderStatus.driverPickedUp.name,
          OrderStatus.outForDelivery.name,
        ])
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromJson(doc.data(), doc.id))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAvailableDrivers() async {
    // Query users with role == 'driver'
    final driversQuery = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .get();

    // Query active orders to check which drivers currently have active orders
    final activeOrdersQuery = await _firestore
        .collection('orders')
        .where('status', whereIn: [
          OrderStatus.driverAssigned.name,
          OrderStatus.driverAccepted.name,
          OrderStatus.driverPickedUp.name,
          OrderStatus.outForDelivery.name,
        ])
        .get();

    final busyDriverIds = activeOrdersQuery.docs
        .map((doc) => doc.data()['driverId'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .toSet();

    final availableDrivers = <Map<String, dynamic>>[];
    for (final doc in driversQuery.docs) {
      final data = doc.data();
      final driverId = doc.id;
      final isActive = data['isActive'] ?? true;
      if (isActive && !busyDriverIds.contains(driverId)) {
        availableDrivers.add({
          'id': driverId,
          'name': data['name'] ?? 'Driver',
          'phone': data['phone'] ?? '',
          'photoUrl': data['photoUrl'] ?? data['driverPhotoUrl'],
        });
      }
    }
    return availableDrivers;
  }

  @override
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final orderRef = _firestore.collection('orders').doc(orderId);

    final snapshot = await orderRef.get();
    if (!snapshot.exists) {
      throw Exception("Order does not exist!");
    }

    final data = snapshot.data() as Map<String, dynamic>;
    final currentStatusStr = data['status'] as String? ?? 'pending';
    final currentStatus = OrderStatus.values.firstWhere(
      (e) => e.name == currentStatusStr,
      orElse: () => OrderStatus.pending,
    );

    // Validate allowed transitions
    final allowedNextStatuses = _getAllowedNextStatuses(currentStatus);
    if (!allowedNextStatuses.contains(newStatus)) {
      throw Exception(
        "Invalid status transition from ${currentStatus.name} to ${newStatus.name}",
      );
    }

    await orderRef.update({'status': newStatus.name});
  }

  @override
  Future<void> assignDriver(String orderId, String driverId) async {
    final orderRef = _firestore.collection('orders').doc(orderId);
    final driverRef = _firestore.collection('users').doc(driverId);

    await _firestore.runTransaction((transaction) async {
      // Perform all reads first (Firestore transaction requirement)
      final orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) {
        throw Exception("Order does not exist!");
      }

      final driverSnap = await transaction.get(driverRef);
      if (!driverSnap.exists) {
        throw Exception("Driver does not exist!");
      }

      final orderData = orderSnap.data() as Map<String, dynamic>;
      final currentStatusStr = orderData['status'] as String? ?? 'pending';
      final currentStatus = OrderStatus.values.firstWhere(
        (e) => e.name == currentStatusStr,
        orElse: () => OrderStatus.pending,
      );

      // Rule: Staff can assign driver only after Preparing (or during Preparing)
      if (currentStatus != OrderStatus.preparing && currentStatus != OrderStatus.confirmed) {
        throw Exception(
          "Driver can only be assigned when order is in Preparing or Confirmed status.",
        );
      }

      // Check if driver has any active non-delivered/non-cancelled order (Enforce 1 active order per driver)
      final activeOrdersQuery = await _firestore
          .collection('orders')
          .where('driverId', isEqualTo: driverId)
          .where('status', whereIn: [
            OrderStatus.driverAssigned.name,
            OrderStatus.driverAccepted.name,
            OrderStatus.driverPickedUp.name,
            OrderStatus.outForDelivery.name,
          ])
          .get();

      if (activeOrdersQuery.docs.isNotEmpty) {
        throw Exception("Driver already has an active order!");
      }

      final driverData = driverSnap.data() as Map<String, dynamic>;
      final driverName = driverData['name'] ?? 'Driver';
      final driverPhone = driverData['phone'] ?? '';
      final driverPhotoUrl = driverData['photoUrl'] ?? driverData['driverPhotoUrl'];

      final restaurantLat = (orderData['restaurantLat'] ?? 0.0).toDouble();
      final restaurantLng = (orderData['restaurantLng'] ?? 0.0).toDouble();

      final driverLocRef = _firestore.collection('driver_locations').doc(driverId);

      transaction.update(orderRef, {
        'driverId': driverId,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'driverPhotoUrl': driverPhotoUrl,
        'status': OrderStatus.driverAssigned.name,
      });

      transaction.set(driverLocRef, {
        'latitude': restaurantLat,
        'longitude': restaurantLng,
        'heading': 0.0,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  List<OrderStatus> _getAllowedNextStatuses(OrderStatus current) {
    switch (current) {
      case OrderStatus.pending:
        return [OrderStatus.confirmed, OrderStatus.preparing, OrderStatus.cancelled];
      case OrderStatus.confirmed:
        return [OrderStatus.preparing, OrderStatus.driverAssigned, OrderStatus.cancelled];
      case OrderStatus.preparing:
        return [OrderStatus.driverAssigned, OrderStatus.outForDelivery, OrderStatus.cancelled];
      case OrderStatus.driverAssigned:
        return [OrderStatus.driverAccepted, OrderStatus.outForDelivery, OrderStatus.cancelled];
      case OrderStatus.driverAccepted:
        return [OrderStatus.driverPickedUp, OrderStatus.outForDelivery, OrderStatus.cancelled];
      case OrderStatus.driverPickedUp:
        return [OrderStatus.outForDelivery, OrderStatus.cancelled];
      case OrderStatus.outForDelivery:
        return [OrderStatus.delivered, OrderStatus.cancelled];
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return [];
    }
  }

  @override
  Future<void> deleteOrder(String orderId) async {
    final orderRef = _firestore.collection('orders').doc(orderId);
    final snap = await orderRef.get();
    if (!snap.exists) {
      throw Exception('Order does not exist!');
    }
    final data = snap.data();
    final statusStr = data?['status'] as String? ?? '';
    if (statusStr != OrderStatus.delivered.name) {
      throw Exception('Only delivered orders can be deleted.');
    }
    await orderRef.delete();
  }
}
