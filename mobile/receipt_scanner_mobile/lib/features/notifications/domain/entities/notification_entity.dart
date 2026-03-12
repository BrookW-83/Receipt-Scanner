import 'package:equatable/equatable.dart';

class NotificationEntity extends Equatable {
  final String id;
  final String notificationType;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isSent;
  final DateTime? sentAt;
  final DateTime? readAt;
  final DateTime createdAt;

  const NotificationEntity({
    required this.id,
    required this.notificationType,
    required this.title,
    required this.body,
    required this.data,
    required this.isSent,
    this.sentAt,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;
  bool get isPriceDrop => notificationType == 'price_drop';
  bool get isMissedPromo => notificationType == 'missed_promo';
  bool get isScanComplete => notificationType == 'scan_complete';

  @override
  List<Object?> get props => [
        id,
        notificationType,
        title,
        body,
        data,
        isSent,
        sentAt,
        readAt,
        createdAt,
      ];
}
