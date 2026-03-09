import 'package:equatable/equatable.dart';

class ReceiptItemEntity extends Equatable {
  final String id;
  final int lineNumber;
  final String description;
  final num quantity;
  final num? unitPrice;
  final num? totalPrice;

  const ReceiptItemEntity({
    required this.id,
    required this.lineNumber,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  @override
  List<Object?> get props => [id, lineNumber, description, quantity, unitPrice, totalPrice];
}
