import 'package:image_picker/image_picker.dart';
import '../../domain/entities/receipt_scan_entity.dart';
import '../../domain/repositories/receipt_scanner_repository.dart';
import '../datasources/receipt_scanner_remote_data_source.dart';
import '../datasources/receipt_scanner_local_data_source.dart';
import '../models/extracted_items_response.dart';

class ReceiptScannerRepositoryImpl implements ReceiptScannerRepository {
  final ReceiptScannerRemoteDataSource remote;
  final ReceiptScannerLocalDataSource local;

  ReceiptScannerRepositoryImpl({required this.remote, required this.local});

  @override
  Future<ReceiptScanEntity> uploadReceipt({
    required List<int> imageBytes,
    required String filename,
  }) {
    return remote.uploadReceipt(imageBytes: imageBytes, filename: filename);
  }

  @override
  Future<ReceiptScanEntity> getReceiptDetails(String scanId) {
    return remote.getReceiptDetails(scanId);
  }

  @override
  Future<List<ReceiptScanEntity>> getRecentScans({int limit = 10}) {
    return remote.getRecentScans(limit: limit);
  }

  @override
  Future<XFile?> captureFromCamera() {
    return local.captureFromCamera();
  }

  @override
  Future<XFile?> pickFromGallery() {
    return local.pickFromGallery();
  }

  @override
  Future<ExtractedItemsResponse> getExtractedItems(String scanId) {
    return remote.getExtractedItems(scanId);
  }

  @override
  Future<void> updateExtractedItems(String scanId, List<Map<String, dynamic>> items) {
    return remote.updateExtractedItems(scanId, items);
  }

  @override
  Future<void> confirmExtractedItems(String scanId) {
    return remote.confirmExtractedItems(scanId);
  }
}
