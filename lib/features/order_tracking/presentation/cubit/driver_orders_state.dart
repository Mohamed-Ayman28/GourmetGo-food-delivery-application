import 'package:equatable/equatable.dart';
import '../../domain/entities/order_entity.dart';

abstract class DriverOrdersState extends Equatable {
  const DriverOrdersState();

  @override
  List<Object?> get props => [];
}

class DriverOrdersInitial extends DriverOrdersState {}

class DriverOrdersLoading extends DriverOrdersState {}

class DriverOrdersLoaded extends DriverOrdersState {
  final List<OrderEntity> orders;
  final bool isTracking;

  const DriverOrdersLoaded(this.orders, {this.isTracking = false});

  DriverOrdersLoaded copyWith({
    List<OrderEntity>? orders,
    bool? isTracking,
  }) {
    return DriverOrdersLoaded(
      orders ?? this.orders,
      isTracking: isTracking ?? this.isTracking,
    );
  }

  @override
  List<Object?> get props => [orders, isTracking];
}

class DriverOrdersError extends DriverOrdersState {
  final String message;

  const DriverOrdersError(this.message);

  @override
  List<Object?> get props => [message];
}
