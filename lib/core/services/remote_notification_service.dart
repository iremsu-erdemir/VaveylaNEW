import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_notification.dart';
import 'auth_service.dart';

class RemoteNotificationService {
  RemoteNotificationService({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  Future<List<AppNotification>> getNotifications({
    required String userId,
    int page = 1,
    int pageSize = 30,
    bool? isRead,
  }) async {
    final response = await _getWithFallback(
      '/api/notifications?userId=$userId&page=$page&pageSize=$pageSize'
      '${isRead == null ? '' : '&isRead=$isRead'}',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NotificationApiException(_extractError(response));
    }

    final dynamic data = jsonDecode(response.body);
    if (data is! List) {
      return const <AppNotification>[];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
  }

  Future<int> getUnreadCount({required String userId}) async {
    final response = await _getWithFallback(
      '/api/notifications/unread-count?userId=$userId',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NotificationApiException(_extractError(response));
    }

    final dynamic data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      return 0;
    }

    return (data['unreadCount'] as num?)?.toInt() ?? 0;
  }

  Future<void> markAsRead({
    required String userId,
    required String notificationId,
  }) async {
    final response = await _putWithFallback(
      '/api/notifications/$notificationId/read?userId=$userId',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NotificationApiException(_extractError(response));
    }
  }

  Future<void> markAllAsRead({required String userId}) async {
    final response = await _putWithFallback(
      '/api/notifications/read-all?userId=$userId',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NotificationApiException(_extractError(response));
    }
  }

  /// Optional: register FCM token after login.
  Future<void> registerDeviceToken({
    required String userId,
    required String platform,
    required String token,
  }) async {
    final response = await _postWithFallback(
      '/api/notifications/device-token',
      <String, dynamic>{
        'userId': userId,
        'platform': platform,
        'token': token,
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NotificationApiException(_extractError(response));
    }
  }

  Future<http.Response> _getWithFallback(String path) async {
    for (final baseUrl in _authService.baseUrls) {
      try {
        return await http
            .get(
              Uri.parse('$baseUrl$path'),
              headers: const <String, String>{
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 8));
      } on Exception {
        // Try next base URL.
      }
    }
    throw const NotificationApiException('Bildirim servisine bağlanılamadı.');
  }

  Future<http.Response> _putWithFallback(String path) async {
    for (final baseUrl in _authService.baseUrls) {
      try {
        return await http
            .put(
              Uri.parse('$baseUrl$path'),
              headers: const <String, String>{
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 8));
      } on Exception {
        // Try next base URL.
      }
    }
    throw const NotificationApiException('Bildirim servisine bağlanılamadı.');
  }

  Future<http.Response> _postWithFallback(
    String path,
    Map<String, dynamic> body,
  ) async {
    for (final baseUrl in _authService.baseUrls) {
      try {
        return await http
            .post(
              Uri.parse('$baseUrl$path'),
              headers: const <String, String>{
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 8));
      } on Exception {
        // Try next base URL.
      }
    }
    throw const NotificationApiException('Bildirim servisine bağlanılamadı.');
  }

  String _extractError(http.Response response) {
    try {
      final dynamic data = jsonDecode(response.body);
      if (data is Map<String, dynamic> && data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {}
    return response.body.isNotEmpty
        ? response.body
        : 'Bildirim işlemi sırasında hata oluştu.';
  }
}

class NotificationApiException implements Exception {
  const NotificationApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
