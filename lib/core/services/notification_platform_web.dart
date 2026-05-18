// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'notification_platform.dart';

class _WebNotificationPlatform implements NotificationPlatform {
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    final status = await html.Notification.requestPermission();
    return status == 'granted';
  }

  @override
  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    if (html.Notification.permission != 'granted') {
      return;
    }

    html.Notification(title, body: body);
  }
}

NotificationPlatform createPlatformNotifier() => _WebNotificationPlatform();
