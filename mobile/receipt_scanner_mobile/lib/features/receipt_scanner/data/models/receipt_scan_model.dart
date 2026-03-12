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
  });

  factory ReceiptScanModel.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>? ?? [];

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return ReceiptScanModel(
      id: (json['id'] ?? '').toString(),
      merchantName: (json['merchant_name'] ?? '').toString(),
      total: json['total'] as num?,
      currency: (json['currency'] ?? 'USD').toString(),
      status: (json['status'] ?? 'pending').toString(),
      items: itemsRaw
          .map((e) => ReceiptItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      purchaseDate: parseDate(json['purchase_date']),
      subtotal: json['subtotal'] as num?,
      tax: json['tax'] as num?,
      totalSavings: json['total_savings'] as num?,
      totalMissedPromos: json['total_missed_promos'] as num?,
      matchedItemsCount: (json['matched_items_count'] ?? 0) as int,
      createdAt: parseDate(json['created_at']),
    );
  }
}
