import '../entities/receipt_scan_entity.dart';
import '../repositories/receipt_scanner_repository.dart';

class UploadReceiptUseCase {
  final ReceiptScannerRepository repository;

  UploadReceiptUseCase(this.repository);

  Future<ReceiptScanEntity> call({
    required List<int> imageBytes,
    required String filename,
  }) {
    return repository.uploadReceipt(imageBytes: imageBytes, filename: filename);
  }
}
