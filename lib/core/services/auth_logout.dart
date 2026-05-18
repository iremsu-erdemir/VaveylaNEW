import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/notification_realtime_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/tracking_realtime_service.dart';

/// Çıkışta SignalR bağlantılarını kapatır ve oturumu temizler.
Future<void> performAuthLogout() async {
  await NotificationRealtimeService.instance.disconnect();
  await TrackingRealtimeService.disposeShared();
  AppSession.clear();
}
