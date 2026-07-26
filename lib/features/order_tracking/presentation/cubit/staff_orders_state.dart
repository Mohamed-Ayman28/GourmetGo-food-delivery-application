import 'package:equatable/equatable.dart';
import '../../domain/entities/order_entity.dart';

abstract class StaffOrdersState extends Equatable {
  const StaffOrdersState();

  @override
  List<Object?> get props => [];
}

class StaffOrdersInitial extends StaffOrdersState {}

class StaffOrdersLoading extends StaffOrdersState {}

class StaffOrdersLoaded extends StaffOrdersState {
  final List<OrderEntity> orders;
  final String? actionError;
  final List<Map<String, dynamic>> availableDrivers;
  final bool isLoadingDrivers;

  const StaffOrdersLoaded(
    this.orders, {
    this.actionError,
    this.availableDrivers = const [],
    this.isLoadingDrivers = false,
  });

  StaffOrdersLoaded copyWith({
    List<OrderEntity>? orders,
    String? actionError,
    bool clearActionError = false,
    List<Map<String, dynamic>>? availableDrivers,
    bool? isLoadingDrivers,
  }) {
    return StaffOrdersLoaded(
      orders ?? this.orders,
      actionError: clearActionError ? null : (actionError ?? this.actionError),
      availableDrivers: availableDrivers ?? this.availableDrivers,
      isLoadingDrivers: isLoadingDrivers ?? this.isLoadingDrivers,
    );
  }

  @override
  List<Object?> get props => [orders, actionError, availableDrivers, isLoadingDrivers];
}

class StaffOrdersError extends StaffOrdersState {
  final String message;

  const StaffOrdersError(this.message);

  @override
  List<Object?> get props => [message];
}
