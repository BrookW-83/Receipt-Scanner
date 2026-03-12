import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:receipt_scanner_mobile/core/api/api_client.dart';
import 'package:receipt_scanner_mobile/features/receipt_scanner/data/datasources/receipt_scanner_remote_data_source.dart';
import 'package:receipt_scanner_mobile/features/receipt_scanner/data/datasources/receipt_scanner_local_data_source.dart';
import 'package:receipt_scanner_mobile/features/receipt_scanner/data/repositories/receipt_scanner_repository_impl.dart';
import 'package:receipt_scanner_mobile/features/receipt_scanner/domain/repositories/receipt_scanner_repository.dart';
import 'package:receipt_scanner_mobile/features/receipt_scanner/domain/usecases/upload_receipt_usecase.dart';
import 'package:receipt_scanner_mobile/features/receipt_scanner/domain/usecases/get_receipt_details_usecase.dart';
import 'package:receipt_scanner_mobile/features/receipt_scanner/domain/usecases/capture_image_usecase.dart';
import 'package:receipt_scanner_mobile/features/receipt_scanner/domain/usecases/get_recent_scans_usecase.dart';
import 'package:receipt_scanner_mobile/features/receipt_scanner/presentation/bloc/receipt_scanner_bloc.dart';

Future<void> initReceiptScannerModule(
  GetIt sl, {
  required Future<String?> Function() tokenProvider,
}) async {
  if (!sl.isRegistered<http.Client>()) {
    sl.registerLazySingleton<http.Client>(() => http.Client());
  }

  if (!sl.isRegistered<ApiClient>()) {
    sl.registerLazySingleton<ApiClient>(
      () => ApiClient(client: sl<http.Client>(), tokenProvider: tokenProvider),
    );
  }

  // Data sources
  sl.registerLazySingleton<ReceiptScannerRemoteDataSource>(
    () => ReceiptScannerRemoteDataSourceImpl(apiClient: sl()),
  );

  sl.registerLazySingleton<ReceiptScannerLocalDataSource>(
    () => ReceiptScannerLocalDataSourceImpl(),
  );

  // Repository
  sl.registerLazySingleton<ReceiptScannerRepository>(
    () => ReceiptScannerRepositoryImpl(remote: sl(), local: sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => UploadReceiptUseCase(sl()));
  sl.registerLazySingleton(() => GetReceiptDetailsUseCase(sl()));
  sl.registerLazySingleton(() => CaptureImageUseCase(sl()));
  sl.registerLazySingleton(() => GetRecentScansUseCase(sl()));

  // BLoC
  sl.registerFactory(() => ReceiptScannerBloc(
        uploadReceiptUseCase: sl(),
        getReceiptDetailsUseCase: sl(),
        captureImageUseCase: sl(),
        getRecentScansUseCase: sl(),
      ));
}
