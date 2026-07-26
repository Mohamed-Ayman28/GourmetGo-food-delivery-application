import 'dart:async';
import 'package:bloc/bloc.dart';
import '../../domain/repositories/order_repository.dart';
import 'customer_orders_state.dart';

class CustomerOrdersCubit extends Cubit<CustomerOrdersState> {
  final OrderRepository orderRepository;

  StreamSubscription? _ordersSubscription;

  CustomerOrdersCubit({
    required this.orderRepository,
  }) : super(CustomerOrdersInitial());

  void loadOrders(String customerId) {
    emit(CustomerOrdersLoading());

    _ordersSubscription?.cancel();
    _ordersSubscription =
        orderRepository.streamCustomerOrders(customerId).listen(
      (orders) {
        emit(CustomerOrdersLoaded(orders: orders));
      },
      onError: (e) => emit(CustomerOrdersError(e.toString())),
    );
  }

  Future<void> deleteOrder(String orderId) async {
    await orderRepository.deleteOrder(orderId);
  }

  @override
  Future<void> close() {
    _ordersSubscription?.cancel();
    return super.close();
  }
}
