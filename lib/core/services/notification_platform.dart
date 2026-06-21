import 'notification_platform_stub.dart'
    if (dart.library.html) 'notification_platform_web.dart'
    if (dart.library.io) 'notification_platform_mobile.dart';

abstract class NotificationPlatform {
  Future<void> initialize();

  Future<bool> requestPermission();

  Future<void> showNotification({
    required String title,
    required String body,
  });
}

NotificationPlatform createNotificationPlatform() => createPlatformNotifier();
