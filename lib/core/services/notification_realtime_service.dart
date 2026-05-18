import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/notification_badge_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/notification_service.dart';
import 'package:signalr_netcore/signalr_client.dart';

/// SignalR `/hubs/notifications` — `notification_received` ile anlık bildirim (teslimat sohbeti vb.).
class NotificationRealtimeService {
  NotificationRealtimeService._();

  static final NotificationRealtimeService instance =
      NotificationRealtimeService._();

  final AuthService _authService = AuthService();
  HubConnection? _connection;
  String? _subscribedUserId;

  String get _hubUrl {
    final base = _authService.baseUrls.firstWhere(
      (u) => u.trim().isNotEmpty,
      orElse: () => '',
    );
    return '$base/hubs/notifications';
  }

  /// Giriş sonrası kullanıcı grubuna abone olur ve hub dinlemeyi başlatır.
  Future<void> connectForUser(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return;

    if (_connection != null &&
        _connection!.state != HubConnectionState.Disconnected) {
      if (_subscribedUserId != id) {
        try {
          await _connection!.invoke('SubscribeUser', args: <Object>[id]);
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint('[NotificationRealtime] SubscribeUser failed: $e\n$st');
          }
        }
        _subscribedUserId = id;
      }
      return;
    }

    try {
      final connectionBuilder =
          HubConnectionBuilder()
              .withUrl(
                _hubUrl,
                options: HttpConnectionOptions(
                  transport: HttpTransportType.WebSockets,
                ),
              )
              .withAutomaticReconnect();

      final conn = connectionBuilder.build();
      conn.on('notification_received', _onNotificationReceived);
      _connection = conn;
      await conn.start();
      await conn.invoke('SubscribeUser', args: <Object>[id]);
      _subscribedUserId = id;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[NotificationRealtime] connect failed: $e\n$st');
      }
      _connection = null;
      _subscribedUserId = null;
    }
  }

  void _onNotificationReceived(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) return;
    final raw = arguments.first;
    if (raw is! Map) return;

    final type = raw['type']?.toString() ?? '';
    final title = raw['title']?.toString() ?? 'Bildirim';
    final message = raw['message']?.toString() ?? '';

    if (type == 'DeliveryChatMessage') {
      NotificationService.instance.showLocalNotification(
        title: title,
        body: message,
      );
    }

    NotificationBadgeService.instance.refresh();
  }

  Future<void> disconnect() async {
    final conn = _connection;
    _connection = null;
    _subscribedUserId = null;
    if (conn == null) return;
    try {
      await conn.stop();
    } catch (_) {}
  }
}
