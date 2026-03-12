import 'dart:io';
import '../repositories/notification_repository.dart';

class InitializeFCMUseCase {
  final NotificationRepository repository;

  InitializeFCMUseCase(this.repository);

  Future<void> call() async {
    final token = await repository.getFCMToken();
    if (token != null) {
      final deviceType = Platform.isIOS ? 'ios' : 'android';
      await repository.registerDevice(token, deviceType);
    }
  }
}
