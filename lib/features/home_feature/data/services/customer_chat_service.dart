import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/models/customer_chat_conversation_model.dart';
import 'package:http/http.dart' as http;

class CustomerChatService {
  CustomerChatService({
    AuthService? authService,
    String? baseUrl,
    List<String>? baseUrls,
  }) : _baseUrls =
            baseUrl != null || (baseUrls != null && baseUrls.isNotEmpty)
                ? AuthService(baseUrl: baseUrl, baseUrls: baseUrls).baseUrls
                : (authService ?? AuthService()).baseUrls;

  final List<String> _baseUrls;

  /// Listeden gizlenen sipariş / restoran kimlikleri (istemci sipariş birleştirmesi için).
  Future<({Set<String> orderIds, Set<String> restaurantIds})> getHiddenInboxIds({
    required String customerUserId,
  }) async {
    if (customerUserId.isEmpty) {
      return (orderIds: <String>{}, restaurantIds: <String>{});
    }
    final q = Uri.encodeQueryComponent(customerUserId);
    final response = await _getWithFallback(
      path: '/api/customer/chats/inbox/hidden?customerUserId=$q',
    );
    final status = response.statusCode;
    if (status < 200 || status >= 300) {
      return (orderIds: <String>{}, restaurantIds: <String>{});
    }
    if (response.body.isEmpty) {
      return (orderIds: <String>{}, restaurantIds: <String>{});
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      return (orderIds: <String>{}, restaurantIds: <String>{});
    }
    Set<String> parseIds(String key) {
      final raw = data[key];
      if (raw is! List) {
        return {};
      }
      return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toSet();
    }

    return (
      orderIds: parseIds('orderIds'),
      restaurantIds: parseIds('restaurantIds'),
    );
  }

  /// Sohbetler listesinden satırı gizler (sunucu kaydı; mesajlar silinmez).
  Future<void> hideInboxRow({
    required String customerUserId,
    String? restaurantId,
    String? orderId,
  }) async {
    final hasR = restaurantId != null && restaurantId.trim().isNotEmpty;
    final hasO = orderId != null && orderId.trim().isNotEmpty;
    if (hasR == hasO) {
      throw AuthException('Geçersiz gizleme isteği.');
    }
    final q = Uri.encodeQueryComponent(customerUserId);
    final body = <String, dynamic>{};
    if (hasR) {
      body['restaurantId'] = restaurantId.trim();
    }
    if (hasO) {
      body['orderId'] = orderId.trim();
    }
    final response = await _postWithFallback(
      path: '/api/customer/chats/inbox/hide?customerUserId=$q',
      body: body,
    );
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      return;
    }
    throw AuthException(
      'Sohbet gizlenemedi (HTTP $status): ${_responseSnippet(response)}',
    );
  }

  Future<List<CustomerChatConversationModel>> getChatConversations({
    required String customerUserId,
  }) async {
    final q = Uri.encodeQueryComponent(customerUserId);
    final response = await _getWithFallback(
      path: '/api/customer/chats/conversations?customerUserId=$q',
    );
    final data = _decodeJson(response);
    final list = _coerceToList(data);
    if (list == null) {
      return [];
    }

    return list
        .whereType<Map>()
        .map(
          (item) => CustomerChatConversationModel.fromJson(
            item.cast<String, dynamic>(),
          ),
        )
        .toList();
  }

  /// Bazı sunucular dizi yerine sarmalayan nesne döndürebilir.
  static List<dynamic>? _coerceToList(dynamic data) {
    if (data is List) {
      return data;
    }
    if (data is Map) {
      for (final key in <String>[
        'items',
        'data',
        'conversations',
        'results',
        'value',
      ]) {
        final v = data[key];
        if (v is List) {
          return v;
        }
      }
    }
    return null;
  }

  Future<http.Response> _getWithFallback({required String path}) async {
    for (final baseUrl in _baseUrls) {
      final url = '$baseUrl$path';
      if (kDebugMode) {
        debugPrint('[API DEBUG] CustomerChatService GET: $url');
      }
      try {
        return await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 8));
      } on Exception catch (error, stack) {
        if (kDebugMode) {
          debugPrint('[API DEBUG] CustomerChatService GET hata: $url');
          debugPrint('[API DEBUG] Hata: $error');
          debugPrint('[API DEBUG] Stack: $stack');
        }
      }
    }
    throw AuthException('Sohbetler yüklenemedi.');
  }

  Future<http.Response> _postWithFallback({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    for (final baseUrl in _baseUrls) {
      final url = '$baseUrl$path';
      if (kDebugMode) {
        debugPrint('[API DEBUG] CustomerChatService POST: $url');
      }
      try {
        return await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json; charset=utf-8'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 15));
      } on Exception catch (error, stack) {
        if (kDebugMode) {
          debugPrint('[API DEBUG] CustomerChatService POST hata: $url');
          debugPrint('[API DEBUG] Hata: $error');
          debugPrint('[API DEBUG] Stack: $stack');
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
    throw AuthException(
      'Sohbetler yüklenemedi (HTTP $status): ${_responseSnippet(response)}',
    );
  }

  String _responseSnippet(http.Response response) {
    final b = response.body;
    if (b.isEmpty) return '';
    return b.length > 200 ? '${b.substring(0, 200)}…' : b;
  }
}

