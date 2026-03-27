import '../../domain/entities/receipt_scan_entity.dart';
import 'receipt_item_model.dart';

class ReceiptScanModel extends ReceiptScanEntity {
  const ReceiptScanModel({
    required super.id,
    required super.merchantName,
    required super.total,
    required super.currency,
    required super.status,
    required super.items,
    super.purchaseDate,
    super.subtotal,
    super.tax,
    super.totalSavings,
    super.totalMissedPromos,
    super.matchedItemsCount = 0,
    super.createdAt,
    super.receiptImageUrl,
  });

  factory ReceiptScanModel.fromJson(Map<String, dynamic> json) {
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

    return ReceiptScanModel(
      id: (json['id'] ?? '').toString(),
      merchantName: (json['merchant_name'] ?? '').toString(),
      total: parseNum(json['total']),
      currency: (json['currency'] ?? 'USD').toString(),
      status: (json['status'] ?? 'pending').toString(),
      items: itemsRaw
          .map((e) => ReceiptItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      purchaseDate: parseDate(json['purchase_date']),
      subtotal: parseNum(json['subtotal']),
      tax: parseNum(json['tax']),
      totalSavings: parseNum(json['total_savings']),
      totalMissedPromos: parseNum(json['total_missed_promos']),
      matchedItemsCount: (json['matched_items_count'] as num?)?.toInt() ?? 0,
      createdAt: parseDate(json['created_at']),
      receiptImageUrl: json['receipt_image']?.toString().replaceFirst('http://', 'https://'),
    );
  }
}
