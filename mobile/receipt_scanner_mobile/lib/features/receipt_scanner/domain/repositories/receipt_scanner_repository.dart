import 'package:image_picker/image_picker.dart';
import '../entities/receipt_scan_entity.dart';
import '../entities/receipt_item_entity.dart';
import '../../data/models/extracted_items_response.dart';

abstract class ReceiptScannerRepository {
  Future<ReceiptScanEntity> uploadReceipt({
    required List<int> imageBytes,
    required String filename,
  });

  Future<ReceiptScanEntity> getReceiptDetails(String scanId);

  Future<List<ReceiptScanEntity>> getRecentScans({int limit = 10});

  Future<XFile?> captureFromCamera();

  Future<XFile?> pickFromGallery();

  /// Get extracted items for review (when status is awaiting_review)
  Future<ExtractedItemsResponse> getExtractedItems(String scanId);

  /// Update extracted items before processing
  Future<void> updateExtractedItems(String scanId, List<Map<String, dynamic>> items);

  /// Confirm extracted items and start processing
  Future<void> confirmExtractedItems(String scanId);
}
