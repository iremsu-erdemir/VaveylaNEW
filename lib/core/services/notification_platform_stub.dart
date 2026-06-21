import 'notification_platform.dart';

class _StubNotificationPlatform implements NotificationPlatform {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> showNotification({
    required String title,
    required String body,
  }) async {}
}

NotificationPlatform createPlatformNotifier() => _StubNotificationPlatform();
