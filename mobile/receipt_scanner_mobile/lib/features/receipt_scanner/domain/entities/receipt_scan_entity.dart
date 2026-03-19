import 'package:equatable/equatable.dart';
import 'receipt_item_entity.dart';

class ReceiptScanEntity extends Equatable {
  final String id;
  final String merchantName;
  final num? total;
  final String currency;
  final String status;
  final List<ReceiptItemEntity> items;

  // New fields
  final DateTime? purchaseDate;
  final num? subtotal;
  final num? tax;
  final num? totalSavings;
  final num? totalMissedPromos;
  final int matchedItemsCount;
  final DateTime? createdAt;

  const ReceiptScanEntity({
    required this.id,
    required this.merchantName,
    required this.total,
    required this.currency,
    required this.status,
    required this.items,
    this.purchaseDate,
    this.subtotal,
    this.tax,
    this.totalSavings,
    this.totalMissedPromos,
    this.matchedItemsCount = 0,
    this.createdAt,
  });

  bool get isProcessing => status == 'pending' || status == 'processing' || status == 'matching';
  bool get isAwaitingReview => status == 'awaiting_review';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get hasSavings => (totalSavings ?? 0) > 0;
  bool get hasMissedPromos => (totalMissedPromos ?? 0) > 0;

  @override
  List<Object?> get props => [
        id,
        merchantName,
        total,
        currency,
        status,
        items,
        purchaseDate,
        subtotal,
        tax,
        totalSavings,
        totalMissedPromos,
        matchedItemsCount,
        createdAt,
      ];
}
