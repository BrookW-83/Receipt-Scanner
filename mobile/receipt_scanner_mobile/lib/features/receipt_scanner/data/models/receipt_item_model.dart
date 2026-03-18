import '../../domain/entities/receipt_item_entity.dart';

class ReceiptItemModel extends ReceiptItemEntity {
  const ReceiptItemModel({
    required super.id,
    required super.lineNumber,
    required super.description,
    required super.quantity,
    required super.unitPrice,
    required super.totalPrice,
    super.matchedProductId,
    super.matchedProductName,
    super.matchConfidence = 'no_match',
    super.confidenceScore,
    super.databasePrice,
    super.savingPerUnit,
    super.totalSaving,
    super.wasOnPromo = false,
    super.promoPrice,
    super.missedSavings,
    super.promoDealId,
  });

  factory ReceiptItemModel.fromJson(Map<String, dynamic> json) {
    num? parseNum(dynamic value) {
      if (value == null) return null;
      if (value is num) return value;
      if (value is String) return num.tryParse(value);
      return null;
    }

    return ReceiptItemModel(
      id: (json['id'] ?? '').toString(),
      lineNumber: (parseNum(json['line_number']) ?? 0).toInt(),
      description: (json['description'] ?? '').toString(),
      quantity: parseNum(json['quantity']) ?? 1,
      unitPrice: parseNum(json['unit_price']),
      totalPrice: parseNum(json['total_price']),
      matchedProductId: json['matched_product_id']?.toString(),
      matchedProductName: json['matched_product_name']?.toString(),
      matchConfidence: (json['match_confidence'] ?? 'no_match').toString(),
      confidenceScore: parseNum(json['confidence_score']),
      databasePrice: parseNum(json['database_price']),
      savingPerUnit: parseNum(json['saving_per_unit']),
      totalSaving: parseNum(json['total_saving']),
      wasOnPromo: json['was_on_promo'] == true,
      promoPrice: parseNum(json['promo_price']),
      missedSavings: parseNum(json['missed_savings']),
      promoDealId: json['promo_deal_id']?.toString(),
    );
  }
}
