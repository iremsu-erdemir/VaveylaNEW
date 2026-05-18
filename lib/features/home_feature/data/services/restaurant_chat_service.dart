import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/models/restaurant_chat_message_model.dart';
import 'package:http/http.dart' as http;

class RestaurantChatService {
  RestaurantChatService({
    AuthService? authService,
    String? baseUrl,
    List<String>? baseUrls,
  }) : _baseUrls =
           baseUrl != null || (baseUrls != null && baseUrls.isNotEmpty)
               ? AuthService(baseUrl: baseUrl, baseUrls: baseUrls).baseUrls
               : (authService ?? AuthService()).baseUrls;

  final List<String> _baseUrls;

  Future<List<RestaurantChatMessageModel>> getMessages({
    required String customerUserId,
    required String restaurantId,
    int limit = 100,
  }) async {
    final response = await _getWithFallback(
      path:
          '/api/customer/chats/messages?customerUserId=$customerUserId&restaurantId=$restaurantId&limit=$limit',
    );
    final data = _decodeJson(response);
    if (data is! Map<String, dynamic>) {
      return const [];
    }
    final rawItems = data['items'];
    if (rawItems is! List) {
      return const [];
    }
    return rawItems
        .whereType<Map>()
        .map(
          (item) =>
              RestaurantChatMessageModel.fromJson(item.cast<String, dynamic>()),
        )
        .toList();
  }

  Future<RestaurantChatMessageModel> sendMessage({
    required String customerUserId,
    required String restaurantId,
    required String message,
  }) async {
    final response = await _postWithFallback(
      path: '/api/customer/chats/messages?customerUserId=$customerUserId',
      body: {'restaurantId': restaurantId, 'message': message},
    );
    final data = _decodeJson(response);
    if (data is! Map<String, dynamic>) {
      throw AuthException('Mesaj gönderilemedi.');
    }
    return RestaurantChatMessageModel.fromJson(data);
  }

  Future<void> deleteCustomerMessage({
    required String customerUserId,
    required String messageId,
  }) async {
    await _deleteWithFallback(
      path:
          '/api/customer/chats/messages/$messageId?customerUserId=$customerUserId',
    );
  }

  Future<http.Response> _getWithFallback({required String path}) async {
    for (final baseUrl in _baseUrls) {
      try {
        return await http
            .get(Uri.parse('$baseUrl$path'))
            .timeout(const Duration(seconds: 8));
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('RestaurantChatService GET hata ($baseUrl): $error');
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
            .timeout(const Duration(seconds: 8));
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('RestaurantChatService POST hata ($baseUrl): $error');
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
            .timeout(const Duration(seconds: 8));
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('RestaurantChatService DELETE hata ($baseUrl): $error');
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
    return response.body.isNotEmpty ? response.body : 'İşlem başarısız.';
  }
}
