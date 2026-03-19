import 'receipt_item_model.dart';

/// Response model for extracted items endpoint
class ExtractedItemsResponse {
  final String scanId;
  final String merchantName;
  final DateTime? purchaseDate;
  final num? subtotal;
  final num? tax;
  final num? total;
  final String currency;
  final List<ReceiptItemModel> items;

  const ExtractedItemsResponse({
    required this.scanId,
    required this.merchantName,
    this.purchaseDate,
    this.subtotal,
    this.tax,
    this.total,
    required this.currency,
    required this.items,
  });

  factory ExtractedItemsResponse.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>? ?? [];

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    num? parseNum(dynamic value) {
      if (value == null) return null;
      if (value is num) return value;
      if (value is String) return num.tryParse(value);
      return null;
    }

    return ExtractedItemsResponse(
      scanId: (json['scan_id'] ?? '').toString(),
      merchantName: (json['merchant_name'] ?? '').toString(),
      purchaseDate: parseDate(json['purchase_date']),
      subtotal: parseNum(json['subtotal']),
      tax: parseNum(json['tax']),
      total: parseNum(json['total']),
      currency: (json['currency'] ?? 'USD').toString(),
      items: itemsRaw
          .map((e) => ReceiptItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
