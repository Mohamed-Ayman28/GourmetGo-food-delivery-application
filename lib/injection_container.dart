import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';

import 'features/order_tracking/core/services/location_service.dart';
import 'features/order_tracking/core/services/routing_service.dart';
import 'features/order_tracking/core/services/osrm_service.dart';
import 'features/order_tracking/data/datasources/order_remote_datasource.dart';
import 'features/order_tracking/data/datasources/tracking_remote_datasource.dart';
import 'features/order_tracking/data/repositories/order_repository_impl.dart';
import 'features/order_tracking/data/repositories/tracking_repository_impl.dart';
import 'features/order_tracking/domain/repositories/order_repository.dart';
import 'features/order_tracking/domain/repositories/tracking_repository.dart';
import 'features/order_tracking/presentation/cubit/customer_tracking_cubit.dart';
import 'features/order_tracking/presentation/cubit/customer_orders_cubit.dart';
import 'features/order_tracking/presentation/cubit/driver_orders_cubit.dart';
import 'features/order_tracking/presentation/cubit/staff_orders_cubit.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Cubits
  sl.registerFactory(() => CustomerOrdersCubit(
        orderRepository: sl(),
      ));
  sl.registerFactory(() => CustomerTrackingCubit(
        orderRepository: sl(),
        trackingRepository: sl(),
        osrmService: sl(),
      ));
  sl.registerFactory(() => DriverOrdersCubit(
        orderRepository: sl(),
        locationService: sl(),
        trackingRepository: sl(),
      ));
  sl.registerFactory(() => StaffOrdersCubit(
        orderRepository: sl(),
      ));

  // Repositories
  sl.registerLazySingleton<OrderRepository>(
      () => OrderRepositoryImpl(remoteDataSource: sl()));
  sl.registerLazySingleton<TrackingRepository>(
      () => TrackingRepositoryImpl(remoteDataSource: sl()));

  // Data Sources
  sl.registerLazySingleton<OrderRemoteDataSource>(
      () => OrderRemoteDataSourceImpl(firestore: sl()));
  sl.registerLazySingleton<TrackingRemoteDataSource>(
      () => TrackingRemoteDataSourceImpl(firestore: sl()));

  // Core Services
  sl.registerLazySingleton(() => LocationService());
  sl.registerLazySingleton(() => RoutingService(dio: sl()));
  sl.registerLazySingleton(() => OSRMService());

  // External
  sl.registerLazySingleton(() => FirebaseFirestore.instance);
  sl.registerLazySingleton(() => Dio());
}
