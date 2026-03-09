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
  });

  factory ReceiptScanModel.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>? ?? [];
    return ReceiptScanModel(
      id: (json['id'] ?? '').toString(),
      merchantName: (json['merchant_name'] ?? '').toString(),
      total: json['total'] as num?,
      currency: (json['currency'] ?? 'USD').toString(),
      status: (json['status'] ?? 'pending').toString(),
      items: itemsRaw
          .map((e) => ReceiptItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
