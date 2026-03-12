import '../../domain/entities/notification_entity.dart';

class NotificationModel extends NotificationEntity {
  const NotificationModel({
    required super.id,
    required super.notificationType,
    required super.title,
    required super.body,
    required super.data,
    required super.isSent,
    super.sentAt,
    super.readAt,
    required super.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return NotificationModel(
      id: (json['id'] ?? '').toString(),
      notificationType: (json['notification_type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      data: json['data'] as Map<String, dynamic>? ?? {},
      isSent: json['is_sent'] == true,
      sentAt: parseDate(json['sent_at']),
      readAt: parseDate(json['read_at']),
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
    );
  }
}
