import 'package:image_picker/image_picker.dart';
import '../entities/receipt_scan_entity.dart';

abstract class ReceiptScannerRepository {
  Future<ReceiptScanEntity> uploadReceipt({
    required List<int> imageBytes,
    required String filename,
  });

  Future<ReceiptScanEntity> getReceiptDetails(String scanId);

  Future<List<ReceiptScanEntity>> getRecentScans({int limit = 10});

  Future<XFile?> captureFromCamera();

  Future<XFile?> pickFromGallery();
}
