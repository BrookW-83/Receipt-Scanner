import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/fcm_data_source.dart';
import '../datasources/notification_remote_data_source.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final FCMDataSource fcmDataSource;
  final NotificationRemoteDataSource remoteDataSource;

  NotificationRepositoryImpl({
    required this.fcmDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<String?> getFCMToken() {
    return fcmDataSource.getToken();
  }

  @override
  Future<void> registerDevice(String fcmToken, String deviceType) {
    return remoteDataSource.registerDevice(fcmToken, deviceType);
  }

  @override
  Future<void> unregisterDevice(String fcmToken) {
    return remoteDataSource.unregisterDevice(fcmToken);
  }

  @override
  Future<List<NotificationEntity>> getNotifications() {
    return remoteDataSource.getNotifications();
  }

  @override
  Future<void> markAsRead(String notificationId) {
    return remoteDataSource.markAsRead(notificationId);
  }

  @override
  Future<void> markAllAsRead() {
    return remoteDataSource.markAllAsRead();
  }
}
