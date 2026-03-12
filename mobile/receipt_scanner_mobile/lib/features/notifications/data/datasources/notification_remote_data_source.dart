import 'dart:io';
import 'package:receipt_scanner_mobile/core/api/api_client.dart';
import 'package:receipt_scanner_mobile/core/config/environment.dart';
import '../models/notification_model.dart';

abstract class NotificationRemoteDataSource {
  Future<void> registerDevice(String fcmToken, String deviceType);
  Future<void> unregisterDevice(String fcmToken);
  Future<List<NotificationModel>> getNotifications();
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final ApiClient apiClient;

  NotificationRemoteDataSourceImpl({required this.apiClient});

  String get _deviceType {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  @override
  Future<void> registerDevice(String fcmToken, String deviceType) async {
    final response = await apiClient.post(
      uri: Uri.parse('${ReceiptScannerEnvironment.apiBaseUrl}receipt-scanner/devices/'),
      body: {
        'fcm_token': fcmToken,
        'device_type': deviceType.isNotEmpty ? deviceType : _deviceType,
        'device_name': Platform.localHostname,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to register device (${response.statusCode}): ${response.body}');
    }
  }

  @override
  Future<void> unregisterDevice(String fcmToken) async {
    final response = await apiClient.post(
      uri: Uri.parse('${ReceiptScannerEnvironment.apiBaseUrl}receipt-scanner/devices/unregister/'),
      body: {'fcm_token': fcmToken},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to unregister device (${response.statusCode}): ${response.body}');
    }
  }

  @override
  Future<List<NotificationModel>> getNotifications() async {
    final response = await apiClient.get(
      uri: Uri.parse('${ReceiptScannerEnvironment.apiBaseUrl}receipt-scanner/notifications/'),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to get notifications (${response.statusCode}): ${response.body}');
    }

    final data = apiClient.parseJsonObject(response.body);
    final results = data['results'] as List<dynamic>? ?? [];
    return results
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    final response = await apiClient.patch(
      uri: Uri.parse(
          '${ReceiptScannerEnvironment.apiBaseUrl}receipt-scanner/notifications/$notificationId/read/'),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to mark notification as read (${response.statusCode}): ${response.body}');
    }
  }

  @override
  Future<void> markAllAsRead() async {
    final response = await apiClient.post(
      uri: Uri.parse(
          '${ReceiptScannerEnvironment.apiBaseUrl}receipt-scanner/notifications/mark_all_read/'),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to mark all notifications as read (${response.statusCode}): ${response.body}');
    }
  }
}
