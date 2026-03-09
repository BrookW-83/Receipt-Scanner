import '../../domain/entities/receipt_scan_entity.dart';
import '../../domain/repositories/receipt_scanner_repository.dart';
import '../datasources/receipt_scanner_remote_data_source.dart';

class ReceiptScannerRepositoryImpl implements ReceiptScannerRepository {
  final ReceiptScannerRemoteDataSource remote;

  ReceiptScannerRepositoryImpl({required this.remote});

  @override
  Future<ReceiptScanEntity> uploadReceipt({
    required List<int> imageBytes,
    required String filename,
  }) {
    return remote.uploadReceipt(imageBytes: imageBytes, filename: filename);
  }
}
