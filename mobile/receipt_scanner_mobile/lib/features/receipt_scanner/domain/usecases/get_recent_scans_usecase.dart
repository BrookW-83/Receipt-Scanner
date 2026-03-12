import '../entities/receipt_scan_entity.dart';
import '../repositories/receipt_scanner_repository.dart';

class GetRecentScansUseCase {
  final ReceiptScannerRepository repository;

  GetRecentScansUseCase(this.repository);

  Future<List<ReceiptScanEntity>> call({int limit = 10}) {
    return repository.getRecentScans(limit: limit);
  }
}
