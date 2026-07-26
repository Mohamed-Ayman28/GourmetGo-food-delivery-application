import 'package:equatable/equatable.dart';
import '../../domain/entities/order_entity.dart';

abstract class CustomerOrdersState extends Equatable {
  const CustomerOrdersState();

  @override
  List<Object?> get props => [];
}

class CustomerOrdersInitial extends CustomerOrdersState {}

class CustomerOrdersLoading extends CustomerOrdersState {}

class CustomerOrdersLoaded extends CustomerOrdersState {
  final List<OrderEntity> orders;

  const CustomerOrdersLoaded({required this.orders});

  /// Filter orders by status category
  List<OrderEntity> get inProgressOrders => orders
      .where((o) =>
          o.status == OrderStatus.pending ||
          o.status == OrderStatus.confirmed ||
          o.status == OrderStatus.preparing ||
          o.status == OrderStatus.driverAssigned ||
          o.status == OrderStatus.driverAccepted ||
          o.status == OrderStatus.driverPickedUp ||
          o.status == OrderStatus.outForDelivery)
      .toList();

  List<OrderEntity> get deliveredOrders =>
      orders.where((o) => o.status == OrderStatus.delivered).toList();

  List<OrderEntity> get cancelledOrders =>
      orders.where((o) => o.status == OrderStatus.cancelled).toList();

  @override
  List<Object?> get props => [orders];
}

class CustomerOrdersError extends CustomerOrdersState {
  final String message;

  const CustomerOrdersError(this.message);

  @override
  List<Object?> get props => [message];
}
