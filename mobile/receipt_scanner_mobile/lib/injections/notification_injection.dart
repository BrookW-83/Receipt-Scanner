import 'package:get_it/get_it.dart';
import 'package:receipt_scanner_mobile/core/api/api_client.dart';
import 'package:receipt_scanner_mobile/features/notifications/data/datasources/fcm_data_source.dart';
import 'package:receipt_scanner_mobile/features/notifications/data/datasources/notification_remote_data_source.dart';
import 'package:receipt_scanner_mobile/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:receipt_scanner_mobile/features/notifications/domain/repositories/notification_repository.dart';
import 'package:receipt_scanner_mobile/features/notifications/domain/usecases/initialize_fcm_usecase.dart';
import 'package:receipt_scanner_mobile/features/notifications/domain/usecases/get_notifications_usecase.dart';
import 'package:receipt_scanner_mobile/features/notifications/presentation/bloc/notification_bloc.dart';

Future<void> initNotificationModule(GetIt sl) async {
  // Data sources
  sl.registerLazySingleton<FCMDataSource>(
    () => FCMDataSourceImpl(),
  );

  sl.registerLazySingleton<NotificationRemoteDataSource>(
    () => NotificationRemoteDataSourceImpl(apiClient: sl<ApiClient>()),
  );

  // Repository
  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(
      fcmDataSource: sl(),
      remoteDataSource: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => InitializeFCMUseCase(sl()));
  sl.registerLazySingleton(() => GetNotificationsUseCase(sl()));

  // BLoC
  sl.registerFactory(() => NotificationBloc(
        initializeFCMUseCase: sl(),
        getNotificationsUseCase: sl(),
        repository: sl(),
      ));
}
