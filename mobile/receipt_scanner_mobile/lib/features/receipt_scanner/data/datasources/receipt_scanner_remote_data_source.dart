import 'dart:convert';
import 'package:receipt_scanner_mobile/core/api/api_client.dart';
import 'package:receipt_scanner_mobile/core/config/environment.dart';
import '../models/receipt_scan_model.dart';
import '../models/receipt_item_model.dart';
import '../models/extracted_items_response.dart';

abstract class ReceiptScannerRemoteDataSource {
  Future<ReceiptScanModel> uploadReceipt({
    required List<int> imageBytes,
    required String filename,
  });

  Future<ReceiptScanModel> getReceiptDetails(String scanId);

  Future<List<ReceiptScanModel>> getRecentScans({int limit = 10});

  /// Get extracted items for review (when status is awaiting_review)
  Future<ExtractedItemsResponse> getExtractedItems(String scanId);

  /// Update extracted items before processing
  Future<void> updateExtractedItems(String scanId, List<Map<String, dynamic>> items);

  /// Confirm extracted items and start processing
  Future<void> confirmExtractedItems(String scanId);
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

  @override
  Future<ReceiptScanModel> getReceiptDetails(String scanId) async {
    final response = await apiClient.get(
      uri: Uri.parse('${ReceiptScannerEnvironment.apiBaseUrl}receipt-scanner/scans/$scanId/'),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to get receipt details (${response.statusCode}): ${response.body}');
    }

    return ReceiptScanModel.fromJson(apiClient.parseJsonObject(response.body));
  }

  @override
  Future<List<ReceiptScanModel>> getRecentScans({int limit = 10}) async {
    final response = await apiClient.get(
      uri: Uri.parse('${ReceiptScannerEnvironment.apiBaseUrl}receipt-scanner/scans/?limit=$limit'),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to get recent scans (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    final List<dynamic> results;
    if (decoded is List) {
      results = decoded;
    } else if (decoded is Map<String, dynamic>) {
      results = decoded['results'] as List<dynamic>? ?? [];
    } else {
      results = [];
    }
    return results
        .map((e) => ReceiptScanModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ExtractedItemsResponse> getExtractedItems(String scanId) async {
    final response = await apiClient.get(
      uri: Uri.parse('${ReceiptScannerEnvironment.apiBaseUrl}receipt-scanner/scans/$scanId/extracted-items/'),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to get extracted items (${response.statusCode}): ${response.body}');
    }

    return ExtractedItemsResponse.fromJson(apiClient.parseJsonObject(response.body));
  }

  @override
  Future<void> updateExtractedItems(String scanId, List<Map<String, dynamic>> items) async {
    final response = await apiClient.patch(
      uri: Uri.parse('${ReceiptScannerEnvironment.apiBaseUrl}receipt-scanner/scans/$scanId/extracted-items/'),
      body: {'items': items},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to update extracted items (${response.statusCode}): ${response.body}');
    }
  }

  @override
  Future<void> confirmExtractedItems(String scanId) async {
    final response = await apiClient.post(
      uri: Uri.parse('${ReceiptScannerEnvironment.apiBaseUrl}receipt-scanner/scans/$scanId/confirm/'),
      body: {},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to confirm extracted items (${response.statusCode}): ${response.body}');
    }
  }
}
