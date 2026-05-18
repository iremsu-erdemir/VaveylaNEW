import 'package:flutter/foundation.dart';

import 'app_session.dart';
import 'remote_notification_service.dart';

class NotificationBadgeService {
  NotificationBadgeService._();

  static final NotificationBadgeService instance = NotificationBadgeService._();

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  final RemoteNotificationService _remoteService = RemoteNotificationService();

  Future<void> refresh() async {
    final userId = AppSession.userId;
    if (userId.isEmpty) {
      unreadCount.value = 0;
      return;
    }

    try {
      final count = await _remoteService.getUnreadCount(userId: userId);
      unreadCount.value = count;
    } catch (_) {
      // Keep current value on temporary API errors.
    }
  }

  Future<void> clearOnServerAndLocal() async {
    final userId = AppSession.userId;
    if (userId.isEmpty) {
      unreadCount.value = 0;
      return;
    }

    unreadCount.value = 0;
    try {
      await _remoteService.markAllAsRead(userId: userId);
    } catch (_) {
      // Badge is intentionally optimistic here.
    }
  }
}
