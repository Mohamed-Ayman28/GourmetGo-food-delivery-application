import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:gourmet_go/features/order_tracking/domain/entities/order_entity.dart';
import 'package:gourmet_go/features/order_tracking/domain/repositories/order_repository.dart';
import 'package:gourmet_go/features/order_tracking/presentation/cubit/staff_orders_cubit.dart';
import 'package:gourmet_go/features/order_tracking/presentation/cubit/staff_orders_state.dart';

class FakeOrderRepository implements OrderRepository {
  final StreamController<List<OrderEntity>> _controller = StreamController<List<OrderEntity>>.broadcast();

  void emitOrders(List<OrderEntity> orders) {
    _controller.add(orders);
  }

  @override
  Stream<List<OrderEntity>> streamAllActiveOrders() => _controller.stream;

  @override
  Stream<List<OrderEntity>> streamCustomerOrders(String customerId) => _controller.stream;

  @override
  Stream<List<OrderEntity>> streamDriverOrders(String driverId) => _controller.stream;

  @override
  Future<Either<String, void>> updateOrderStatus(String orderId, OrderStatus status) async {
    return const Right(null);
  }

  @override
  Future<Either<String, void>> assignDriver(String orderId, String driverId) async {
    return const Right(null);
  }

  @override
  Future<Either<String, List<Map<String, dynamic>>>> fetchAvailableDrivers() async {
    return const Right([{'id': 'drv_1', 'name': 'Driver Ali', 'phone': '12345'}]);
  }

  @override
  Future<Either<String, void>> deleteOrder(String orderId) async {
    return const Right(null);
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  group('StaffOrdersCubit Unit Tests', () {
    late FakeOrderRepository fakeRepo;
    late StaffOrdersCubit cubit;

    setUp(() {
      fakeRepo = FakeOrderRepository();
      cubit = StaffOrdersCubit(orderRepository: fakeRepo);
    });

    tearDown(() {
      cubit.close();
      fakeRepo.dispose();
    });

    test('Initial state is StaffOrdersInitial', () {
      expect(cubit.state, isA<StaffOrdersInitial>());
    });

    test('loadActiveOrders emits Loading and then Loaded when stream yields', () async {
      cubit.loadActiveOrders();
      expect(cubit.state, isA<StaffOrdersLoading>());

      final testOrder = OrderEntity(
        id: 'ord_1',
        customerId: 'c1',
        customerName: 'Alice',
        customerPhone: '111',
        customerLat: 30.0,
        customerLng: 31.0,
        customerAddress: 'Cairo',
        restaurantName: 'Gourmet',
        restaurantPhone: '222',
        restaurantLat: 30.1,
        restaurantLng: 31.1,
        items: const [OrderItemEntity(name: 'Burger', quantity: 1)],
        subtotal: 10.0,
        deliveryFee: 2.0,
        totalAmount: 12.0,
        status: OrderStatus.pending,
        paymentMethod: 'cash',
        createdAt: DateTime.now(),
      );

      fakeRepo.emitOrders([testOrder]);

      await expectLater(
        cubit.stream,
        emits(isA<StaffOrdersLoaded>().having(
          (s) => s.orders.length,
          'orders length',
          equals(1),
        )),
      );
    });

    test('fetchAvailableDrivers updates availableDrivers list on success', () async {
      cubit.loadActiveOrders();
      fakeRepo.emitOrders([]);
      await Future.delayed(Duration.zero);

      await cubit.fetchAvailableDrivers();

      final state = cubit.state as StaffOrdersLoaded;
      expect(state.availableDrivers.length, equals(1));
      expect(state.availableDrivers.first['name'], equals('Driver Ali'));
    });
  });
}
