import 'package:equatable/equatable.dart';
import 'receipt_item_entity.dart';

class ReceiptScanEntity extends Equatable {
  final String id;
  final String merchantName;
  final num? total;
  final String currency;
  final String status;
  final List<ReceiptItemEntity> items;

  const ReceiptScanEntity({
    required this.id,
    required this.merchantName,
    required this.total,
    required this.currency,
    required this.status,
    required this.items,
  });

  @override
  List<Object?> get props => [id, merchantName, total, currency, status, items];
}
