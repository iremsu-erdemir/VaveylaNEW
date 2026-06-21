import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/models/delivery_chat_message_model.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart'
    show AuthException, AuthService;
import 'package:http/http.dart' as http;

class DeliveryChatService {
  DeliveryChatService({AuthService? authService})
      : _baseUrls = authService?.baseUrls ?? AuthService().baseUrls;

  final List<String> _baseUrls;

  Future<List<DeliveryChatMessageModel>> fetchMessages({
    required String orderId,
    required String userId,
  }) async {
    final response = await _getWithFallback(
      path:
          '/api/orders/$orderId/delivery-chat/messages?userId=${Uri.encodeQueryComponent(userId)}',
    );
    final data = _decodeJson(response);
    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (e) =>
                DeliveryChatMessageModel.fromJson(e.cast<String, dynamic>()),
          )
          .toList();
    }
    return [];
  }

  Future<DeliveryChatMessageModel> sendMessage({
    required String orderId,
    required String userId,
    required String text,
  }) async {
    final response = await _postWithFallback(
      path:
          '/api/orders/$orderId/delivery-chat/messages?userId=${Uri.encodeQueryComponent(userId)}',
      body: {'message': text},
    );
    final data = _decodeJson(response) as Map<String, dynamic>;
    return DeliveryChatMessageModel.fromJson(data);
  }

  Future<DeliveryChatMessageModel> updateMessage({
    required String orderId,
    required String userId,
    required String messageId,
    required String text,
  }) async {
    final response = await _patchWithFallback(
      path:
          '/api/orders/$orderId/delivery-chat/messages/$messageId?userId=${Uri.encodeQueryComponent(userId)}',
      body: {'message': text},
    );
    final data = _decodeJson(response) as Map<String, dynamic>;
    return DeliveryChatMessageModel.fromJson(data);
  }

  Future<void> deleteMessage({
    required String orderId,
    required String userId,
    required String messageId,
  }) async {
    final response = await _deleteWithFallback(
      path:
          '/api/orders/$orderId/delivery-chat/messages/$messageId?userId=${Uri.encodeQueryComponent(userId)}',
    );
    final code = response.statusCode;
    if (code == 204 || code == 200) {
      return;
    }
    throw AuthException(_extractMessage(response));
  }

  Future<http.Response> _getWithFallback({required String path}) async {
    for (final baseUrl in _baseUrls) {
      try {
        return await http
            .get(Uri.parse('$baseUrl$path'))
            .timeout(const Duration(seconds: 12));
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('DeliveryChatService GET hata ($baseUrl): $error');
        }
      }
    }
    throw AuthException('Sunucuya bağlanılamadı.');
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
            .timeout(const Duration(seconds: 12));
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('DeliveryChatService POST hata ($baseUrl): $error');
        }
      }
    }
    throw AuthException('Sunucuya bağlanılamadı.');
  }

  Future<http.Response> _patchWithFallback({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    for (final baseUrl in _baseUrls) {
      try {
        return await http
            .patch(
              Uri.parse('$baseUrl$path'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 12));
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('DeliveryChatService PATCH hata ($baseUrl): $error');
        }
      }
    }
    throw AuthException('Sunucuya bağlanılamadı.');
  }

  Future<http.Response> _deleteWithFallback({required String path}) async {
    for (final baseUrl in _baseUrls) {
      try {
        return await http
            .delete(Uri.parse('$baseUrl$path'))
            .timeout(const Duration(seconds: 12));
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('DeliveryChatService DELETE hata ($baseUrl): $error');
        }
      }
    }
    throw AuthException('Sunucuya bağlanılamadı.');
  }

  dynamic _decodeJson(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    throw AuthException(_extractMessage(response));
  }

  String _extractMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic> && data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {}
    return response.body.isNotEmpty
        ? response.body
        : 'İşlem sırasında bir hata oluştu.';
  }
}
