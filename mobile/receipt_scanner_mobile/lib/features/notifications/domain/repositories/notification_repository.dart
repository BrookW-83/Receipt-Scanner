import '../entities/notification_entity.dart';

abstract class NotificationRepository {
  Future<String?> getFCMToken();
  Future<void> registerDevice(String fcmToken, String deviceType);
  Future<void> unregisterDevice(String fcmToken);
  Future<List<NotificationEntity>> getNotifications();
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
}
