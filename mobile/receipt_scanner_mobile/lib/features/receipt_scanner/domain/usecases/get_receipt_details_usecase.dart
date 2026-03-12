import '../entities/receipt_scan_entity.dart';
import '../repositories/receipt_scanner_repository.dart';

class GetReceiptDetailsUseCase {
  final ReceiptScannerRepository repository;

  GetReceiptDetailsUseCase(this.repository);

  Future<ReceiptScanEntity> call(String scanId) {
    return repository.getReceiptDetails(scanId);
  }
}
