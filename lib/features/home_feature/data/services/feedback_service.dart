import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/services/app_session.dart';
import '../../../../core/services/auth_service.dart';

/// API ile aynı: `bakeryProduct` | `bakeryOrder` | `courier`
enum CustomerFeedbackTargetType {
  bakeryProduct,
  bakeryOrder,
  courier,
}

class FeedbackService {
  FeedbackService({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  /// Kimlik sunucuda JWT ile belirlenir; [targetEntityId] hedef varlık GUID'i (ürün / sipariş / kurye).
  Future<void> submitCustomerFeedback({
    required CustomerFeedbackTargetType targetType,
    required String targetEntityId,
    required String message,
  }) async {
    final tid = targetEntityId.trim();
    if (tid.isEmpty) {
      throw AuthException('Hedef kimliği (targetEntityId) gerekli.');
    }
    final body = <String, dynamic>{
      'targetType': _targetTypeJson(targetType),
      'targetEntityId': tid,
      'message': message,
    };
    await _requestWithFallback(
      method: 'POST',
      path: '/api/feedbacks',
      body: body,
      sendAuth: true,
    );
  }

  String _targetTypeJson(CustomerFeedbackTargetType t) {
    switch (t) {
      case CustomerFeedbackTargetType.bakeryProduct:
        return 'bakeryProduct';
      case CustomerFeedbackTargetType.bakeryOrder:
        return 'bakeryOrder';
      case CustomerFeedbackTargetType.courier:
        return 'courier';
    }
  }

  Future<http.Response> _requestWithFallback({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    bool sendAuth = false,
  }) async {
    for (final baseUrl in _authService.baseUrls) {
      try {
        final uri = _buildRequestUri(baseUrl: baseUrl, path: path);
        final request = http.Request(method, uri);
        request.headers['Content-Type'] = 'application/json; charset=utf-8';
        if (sendAuth) {
          final token = AppSession.token;
          if (token.isNotEmpty) {
            request.headers['Authorization'] = 'Bearer $token';
          }
        }
        if (body != null) {
          final normalizedBody = _normalizeRequestBody(body);
          request.bodyBytes = utf8.encode(jsonEncode(normalizedBody));
        }
        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 8),
        );
        final responseBytes = await streamedResponse.stream.toBytes();
        final responseBody = utf8.decode(responseBytes);
        final response = http.Response(
          responseBody,
          streamedResponse.statusCode,
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }
        if (response.statusCode >= 400 && response.statusCode < 500) {
          final msg = _tryParseErrorMessage(response.body);
          throw AuthException(msg ?? 'İstek reddedildi (${response.statusCode}).');
        }
        if (kDebugMode) {
          debugPrint(
            'FeedbackService $method response error '
            '($baseUrl): ${response.statusCode} ${response.body}',
          );
        }
      } on AuthException {
        rethrow;
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('FeedbackService $method error ($baseUrl): $error');
        }
      }
    }

    throw AuthException(
      'Sunucuya baglanilamadi. Lutfen baglantinizi kontrol edin.',
    );
  }

  String? _tryParseErrorMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {}
    return null;
  }

  Uri _buildRequestUri({required String baseUrl, required String path}) {
    final normalizedBase = baseUrl.trim();
    if (normalizedBase.isEmpty) {
      throw ArgumentError('Base URL is empty.');
    }
    return Uri.parse(normalizedBase).resolve(path);
  }

  Map<String, dynamic> _normalizeRequestBody(Map<String, dynamic> body) {
    return body.map((key, value) => MapEntry(key, _normalizePayloadValue(value)));
  }

  dynamic _normalizePayloadValue(dynamic value) {
    if (value is String) {
      var text = value.trim();
      for (var i = 0; i < 2; i++) {
        final looksJsonString =
            (text.startsWith('"') && text.endsWith('"')) ||
            (text.startsWith('{') && text.endsWith('}')) ||
            (text.startsWith('[') && text.endsWith(']'));
        if (!looksJsonString) {
          break;
        }
        try {
          final decoded = jsonDecode(text);
          if (decoded is String) {
            text = decoded.trim();
            continue;
          }
          if (decoded is Map<String, dynamic>) {
            return decoded.map(
              (k, v) => MapEntry(k, _normalizePayloadValue(v)),
            );
          }
          if (decoded is List) {
            return decoded.map(_normalizePayloadValue).toList();
          }
          break;
        } catch (_) {
          break;
        }
      }
      return _sanitizeText(text);
    }

    if (value is Map<String, dynamic>) {
      return value.map(
        (key, nestedValue) => MapEntry(key, _normalizePayloadValue(nestedValue)),
      );
    }

    if (value is List) {
      return value.map(_normalizePayloadValue).toList();
    }

    return value;
  }

  String _sanitizeText(String input) {
    final compactWhitespace = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    return compactWhitespace.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '');
  }

}
