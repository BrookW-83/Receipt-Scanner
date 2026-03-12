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
    return ReceiptItemModel(
      id: (json['id'] ?? '').toString(),
      lineNumber: (json['line_number'] ?? 0) as int,
      description: (json['description'] ?? '').toString(),
      quantity: (json['quantity'] ?? 1) as num,
      unitPrice: json['unit_price'] as num?,
      totalPrice: json['total_price'] as num?,
      matchedProductId: json['matched_product_id'] as String?,
      matchedProductName: json['matched_product_name'] as String?,
      matchConfidence: (json['match_confidence'] ?? 'no_match').toString(),
      confidenceScore: json['confidence_score'] as num?,
      databasePrice: json['database_price'] as num?,
      savingPerUnit: json['saving_per_unit'] as num?,
      totalSaving: json['total_saving'] as num?,
      wasOnPromo: json['was_on_promo'] == true,
      promoPrice: json['promo_price'] as num?,
      missedSavings: json['missed_savings'] as num?,
      promoDealId: json['promo_deal_id'] as String?,
    );
  }
}
