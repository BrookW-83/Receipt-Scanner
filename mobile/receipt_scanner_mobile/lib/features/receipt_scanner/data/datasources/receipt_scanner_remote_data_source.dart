import 'package:receipt_scanner_mobile/core/api/api_client.dart';
import 'package:receipt_scanner_mobile/core/config/environment.dart';
import '../models/receipt_scan_model.dart';

abstract class ReceiptScannerRemoteDataSource {
  Future<ReceiptScanModel> uploadReceipt({
    required List<int> imageBytes,
    required String filename,
  });
}

class ReceiptScannerRemoteDataSourceImpl implements ReceiptScannerRemoteDataSource {
  final ApiClient apiClient;

  ReceiptScannerRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<ReceiptScanModel> uploadReceipt({
    required List<int> imageBytes,
    required String filename,
  }) async {
    final response = await apiClient.postMultipart(
      uri: Uri.parse('${ReceiptScannerEnvironment.apiBaseUrl}receipt-scanner/scans/'),
      fieldName: 'receipt_image',
      fileBytes: imageBytes,
      filename: filename,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Upload failed (${response.statusCode}): ${response.body}');
    }

    return ReceiptScanModel.fromJson(apiClient.parseJsonObject(response.body));
  }
}
