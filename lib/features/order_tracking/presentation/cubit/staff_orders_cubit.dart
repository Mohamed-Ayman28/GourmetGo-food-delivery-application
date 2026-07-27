import 'dart:async';
import 'package:bloc/bloc.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import 'staff_orders_state.dart';

class StaffOrdersCubit extends Cubit<StaffOrdersState> {
  final OrderRepository orderRepository;
  StreamSubscription? _ordersSubscription;

  StaffOrdersCubit({required this.orderRepository}) : super(StaffOrdersInitial());

  void loadActiveOrders() {
    emit(StaffOrdersLoading());
    _ordersSubscription?.cancel();
    _ordersSubscription = orderRepository.streamAllActiveOrders().listen(
      (orders) {
        if (state is StaffOrdersLoaded) {
          emit((state as StaffOrdersLoaded).copyWith(orders: orders));
        } else {
          emit(StaffOrdersLoaded(orders));
        }
      },
      onError: (e) {
        emit(StaffOrdersError(e.toString()));
      },
    );
  }

  Future<void> fetchAvailableDrivers() async {
    if (state is StaffOrdersLoaded) {
      final current = state as StaffOrdersLoaded;
      emit(current.copyWith(isLoadingDrivers: true));
      final result = await orderRepository.fetchAvailableDrivers();
      result.fold(
        (failure) => emit(current.copyWith(actionError: failure, isLoadingDrivers: false)),
        (drivers) => emit(current.copyWith(availableDrivers: drivers, isLoadingDrivers: false)),
      );
    }
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final result = await orderRepository.updateOrderStatus(orderId, status);
    result.fold(
      (failure) {
        if (state is StaffOrdersLoaded) {
          emit((state as StaffOrdersLoaded).copyWith(actionError: failure));
        } else {
          emit(StaffOrdersError(failure));
        }
      },
      (_) {
        if (state is StaffOrdersLoaded) {
          emit((state as StaffOrdersLoaded).copyWith(clearActionError: true));
        }
      },
    );
  }

  Future<void> assignDriver(String orderId, String driverId) async {
    final result = await orderRepository.assignDriver(orderId, driverId);
    result.fold(
      (failure) {
        if (state is StaffOrdersLoaded) {
          emit((state as StaffOrdersLoaded).copyWith(actionError: failure));
        } else {
          emit(StaffOrdersError(failure));
        }
      },
      (_) {
        if (state is StaffOrdersLoaded) {
          emit((state as StaffOrdersLoaded).copyWith(clearActionError: true));
        }
      },
    );
  }

  Future<void> deleteOrder(String orderId) async {
    final result = await orderRepository.deleteOrder(orderId);
    result.fold(
      (failure) {
        if (state is StaffOrdersLoaded) {
          emit((state as StaffOrdersLoaded).copyWith(actionError: failure));
        } else {
          emit(StaffOrdersError(failure));
        }
      },
      (_) {
        if (state is StaffOrdersLoaded) {
          emit((state as StaffOrdersLoaded).copyWith(clearActionError: true));
        }
      },
    );
  }

  void clearActionError() {
    if (state is StaffOrdersLoaded) {
      emit((state as StaffOrdersLoaded).copyWith(clearActionError: true));
    }
  }

  @override
  Future<void> close() {
    _ordersSubscription?.cancel();
    return super.close();
  }
}
