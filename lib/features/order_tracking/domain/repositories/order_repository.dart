import 'package:dartz/dartz.dart';
import '../entities/order_entity.dart';

abstract class OrderRepository {
  /// Stream of orders for a specific customer
  Stream<List<OrderEntity>> streamCustomerOrders(String customerId);

  /// Stream of all active orders (for staff)
  Stream<List<OrderEntity>> streamAllActiveOrders();

  /// Stream of orders assigned to a specific driver
  Stream<List<OrderEntity>> streamDriverOrders(String driverId);

  /// Update the status of an order
  Future<Either<String, void>> updateOrderStatus(String orderId, OrderStatus status);

  /// Assign a driver to an order
  Future<Either<String, void>> assignDriver(String orderId, String driverId);

  /// Fetch list of available drivers (active drivers without an assigned active order)
  Future<Either<String, List<Map<String, dynamic>>>> fetchAvailableDrivers();

  /// Delete an order
  Future<Either<String, void>> deleteOrder(String orderId);
}

