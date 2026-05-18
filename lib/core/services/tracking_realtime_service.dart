import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/models/tracking_models.dart';
import 'package:http/http.dart' as http;
import 'package:signalr_netcore/signalr_client.dart';

class TrackingRealtimeService {
  TrackingRealtimeService({
    AuthService? authService,
    String? baseUrl,
    List<String>? baseUrls,
  }) : _baseUrls =
           baseUrl != null || (baseUrls != null && baseUrls.isNotEmpty)
               ? AuthService(baseUrl: baseUrl, baseUrls: baseUrls).baseUrls
               : (authService ?? AuthService()).baseUrls;

  static TrackingRealtimeService? _shared;
  static final Map<String, int> _orderRefCount = <String, int>{};

  /// Tek WebSocket: takip + teslimat sohbeti `delivery_chat_message` olayları.
  static TrackingRealtimeService get shared =>
      _shared ??= TrackingRealtimeService();

  static Future<void> disposeShared() async {
    await _shared?.disconnect();
    _shared = null;
  }

  final List<String> _baseUrls;
  HubConnection? _connection;

  final StreamController<Map<String, dynamic>> _deliveryChatController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Sipariş grubuna düşen yeni teslimat sohbeti mesajları (SignalR).
  Stream<Map<String, dynamic>> get deliveryChatMessages =>
      _deliveryChatController.stream;

  String get _hubUrl =>
      '${_baseUrls.firstWhere((url) => url.trim().isNotEmpty)}/hubs/tracking';

  Future<void> connect() async {
    if (_connection != null &&
        _connection!.state != HubConnectionState.Disconnected) {
      return;
    }

    final connectionBuilder =
        HubConnectionBuilder()
            .withUrl(
              _hubUrl,
              options: HttpConnectionOptions(
                transport: HttpTransportType.WebSockets,
              ),
            )
            .withAutomaticReconnect();

    _connection = connectionBuilder.build();
    await _connection!.start();
    _attachDeliveryChatHandler();

    for (final entry in _orderRefCount.entries.toList()) {
      if (entry.value > 0) {
        try {
          await _connection!.invoke('SubscribeOrder', args: <Object>[entry.key]);
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint(
              '[TrackingRealtime] resubscribe ${entry.key} failed: $e\n$st',
            );
          }
        }
      }
    }
  }

  void _attachDeliveryChatHandler() {
    _connection?.off('delivery_chat_message');
    _connection?.on('delivery_chat_message', (arguments) {
      if (arguments == null || arguments.isEmpty || arguments.first == null) {
        return;
      }
      final payload = arguments.first;
      if (payload is Map) {
        final map = Map<String, dynamic>.from(
          payload.map((k, v) => MapEntry(k.toString(), v)),
        );
        if (!_deliveryChatController.isClosed) {
          _deliveryChatController.add(map);
        }
      }
    });
  }

  Future<void> disconnect() async {
    final conn = _connection;
    _connection = null;
    _orderRefCount.clear();
    if (conn == null) return;
    try {
      await conn.stop();
    } catch (_) {}
  }

  Future<void> subscribeOrder(String orderId) async {
    final key = orderId.trim();
    if (key.isEmpty) return;
    await connect();
    final next = (_orderRefCount[key] ?? 0) + 1;
    _orderRefCount[key] = next;
    if (next == 1) {
      await _connection!.invoke('SubscribeOrder', args: <Object>[key]);
    }
  }

  Future<void> unsubscribeOrder(String orderId) async {
    final key = orderId.trim();
    if (key.isEmpty) return;
    final n = _orderRefCount[key] ?? 0;
    if (n <= 1) {
      _orderRefCount.remove(key);
      if (_connection != null) {
        try {
          await _connection!.invoke('UnsubscribeOrder', args: <Object>[key]);
        } catch (_) {}
      }
    } else {
      _orderRefCount[key] = n - 1;
    }
  }

  void onLocationUpdated(void Function(LocationUpdateModel update) listener) {
    _connection?.off('location_updated');
    _connection?.on('location_updated', (arguments) {
      if (arguments == null || arguments.isEmpty || arguments.first == null) {
        return;
      }
      final payload = arguments.first;
      if (payload is Map) {
        final model = LocationUpdateModel.tryFromJson(payload);
        if (model != null) {
          listener(model);
        }
      }
    });
  }

  void onTrackingStatusChanged(void Function(bool isActive) listener) {
    _connection?.off('tracking_status_changed');
    _connection?.on('tracking_status_changed', (arguments) {
      if (arguments == null || arguments.isEmpty || arguments.first == null) {
        return;
      }
      final payload = arguments.first;
      if (payload is Map) {
        listener(payload['isTrackingActive'] == true);
      }
    });
  }

  Future<void> startTracking({
    required String orderId,
    required String courierUserId,
  }) async {
    await _postWithFallback(
      path: '/api/location/orders/$orderId/start?courierUserId=$courierUserId',
      body: const {},
    );
  }

  Future<void> stopTracking({
    required String orderId,
    required String courierUserId,
  }) async {
    await _postWithFallback(
      path: '/api/location/orders/$orderId/stop?courierUserId=$courierUserId',
      body: const {},
    );
  }

  Future<void> sendLocationUpdate({
    required String orderId,
    required String courierUserId,
    required double lat,
    required double lng,
    required DateTime timestampUtc,
    double? bearing,
  }) async {
    await _postWithFallback(
      path: '/api/location/update',
      body: {
        'orderId': orderId,
        'courierUserId': courierUserId,
        'lat': lat,
        'lng': lng,
        'bearing': bearing,
        'timestampUtc': timestampUtc.toUtc().toIso8601String(),
      },
    );
  }

  Future<TrackingSnapshotModel?> getSnapshot({
    required String orderId,
    required String customerUserId,
  }) async {
    final response = await _getWithFallback(
      path:
          '/api/location/orders/$orderId/snapshot?customerUserId=$customerUserId',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    if (response.body.isEmpty) return null;
    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) return null;
    return TrackingSnapshotModel.fromJson(json);
  }

  Future<http.Response> _getWithFallback({required String path}) async {
    for (final baseUrl in _baseUrls) {
      try {
        return await http
            .get(Uri.parse('$baseUrl$path'))
            .timeout(const Duration(seconds: 8));
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('TrackingRealtimeService GET error ($baseUrl): $error');
        }
      }
    }
    throw AuthException('Sunucuya baglanilamadi.');
  }

  Future<http.Response> _postWithFallback({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    for (final baseUrl in _baseUrls) {
      try {
        return await http
            .post(
              Uri.parse('$baseUrl$path'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 8));
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('TrackingRealtimeService POST error ($baseUrl): $error');
        }
      }
    }
    throw AuthException('Sunucuya baglanilamadi.');
  }
}
