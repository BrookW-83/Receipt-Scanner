import '../entities/receipt_scan_entity.dart';

abstract class ReceiptScannerRepository {
  Future<ReceiptScanEntity> uploadReceipt({
    required List<int> imageBytes,
    required String filename,
  });
}
