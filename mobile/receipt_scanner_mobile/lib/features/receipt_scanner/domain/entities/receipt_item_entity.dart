import 'package:equatable/equatable.dart';

class ReceiptItemEntity extends Equatable {
  final String id;
  final int lineNumber;
  final String description;
  final num quantity;
  final num? unitPrice;
  final num? totalPrice;

  // Product matching fields
  final String? matchedProductId;
  final String? matchedProductName;
  final String matchConfidence; // high, medium, low, no_match
  final num? confidenceScore;

  // Savings fields
  final num? databasePrice;
  final num? savingPerUnit;
  final num? totalSaving;

  // Promo fields
  final bool wasOnPromo;
  final num? promoPrice;
  final num? missedSavings;
  final String? promoDealId;

  const ReceiptItemEntity({
    required this.id,
    required this.lineNumber,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.matchedProductId,
    this.matchedProductName,
    this.matchConfidence = 'no_match',
    this.confidenceScore,
    this.databasePrice,
    this.savingPerUnit,
    this.totalSaving,
    this.wasOnPromo = false,
    this.promoPrice,
    this.missedSavings,
    this.promoDealId,
  });

  bool get isMatched => matchConfidence != 'no_match' && matchedProductId != null;
  bool get hasSavings => (totalSaving ?? 0) > 0;
  bool get hasMissedPromo => wasOnPromo && (missedSavings ?? 0) > 0;

  @override
  List<Object?> get props => [
        id,
        lineNumber,
        description,
        quantity,
        unitPrice,
        totalPrice,
        matchedProductId,
        matchedProductName,
        matchConfidence,
        confidenceScore,
        databasePrice,
        savingPerUnit,
        totalSaving,
        wasOnPromo,
        promoPrice,
        missedSavings,
        promoDealId,
      ];
}
