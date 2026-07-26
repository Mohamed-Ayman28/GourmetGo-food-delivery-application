import 'package:dartz/dartz.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/order_remote_datasource.dart';

class OrderRepositoryImpl implements OrderRepository {
  final OrderRemoteDataSource remoteDataSource;

  OrderRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<OrderEntity>> streamCustomerOrders(String customerId) {
    return remoteDataSource.streamCustomerOrders(customerId);
  }

  @override
  Stream<List<OrderEntity>> streamAllActiveOrders() {
    return remoteDataSource.streamAllActiveOrders();
  }

  @override
  Stream<List<OrderEntity>> streamDriverOrders(String driverId) {
    return remoteDataSource.streamDriverOrders(driverId);
  }

  @override
  Future<Either<String, void>> updateOrderStatus(
      String orderId, OrderStatus status) async {
    try {
      await remoteDataSource.updateOrderStatus(orderId, status);
      return const Right(null);
    } catch (e) {
      return Left('Failed to update order status: $e');
    }
  }

  @override
  Future<Either<String, void>> assignDriver(
      String orderId, String driverId) async {
    try {
      await remoteDataSource.assignDriver(orderId, driverId);
      return const Right(null);
    } catch (e) {
      return Left(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Future<Either<String, List<Map<String, dynamic>>>> fetchAvailableDrivers() async {
    try {
      final drivers = await remoteDataSource.fetchAvailableDrivers();
      return Right(drivers);
    } catch (e) {
      return Left('Failed to fetch available drivers: $e');
    }
  }

  @override
  Future<Either<String, void>> deleteOrder(String orderId) async {
    try {
      await remoteDataSource.deleteOrder(orderId);
      return const Right(null);
    } catch (e) {
      return Left('Failed to delete order: $e');
    }
  }
}
