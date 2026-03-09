import '../../domain/entities/receipt_item_entity.dart';

class ReceiptItemModel extends ReceiptItemEntity {
  const ReceiptItemModel({
    required super.id,
    required super.lineNumber,
    required super.description,
    required super.quantity,
    required super.unitPrice,
    required super.totalPrice,
  });

  factory ReceiptItemModel.fromJson(Map<String, dynamic> json) {
    return ReceiptItemModel(
      id: (json['id'] ?? '').toString(),
      lineNumber: (json['line_number'] ?? 0) as int,
      description: (json['description'] ?? '').toString(),
      quantity: (json['quantity'] ?? 1) as num,
      unitPrice: json['unit_price'] as num?,
      totalPrice: json['total_price'] as num?,
    );
  }
}
