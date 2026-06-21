import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/services/auth_service.dart';
import '../models/payment_saved_card.dart';

class PaymentCardService {
  PaymentCardService({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  Future<List<PaymentSavedCard>> getCards({required String userId}) async {
    final normalizedUserId = _extractGuid(_normalizeId(userId, key: 'userId'));
    final response = await _requestWithFallback(
      method: 'GET',
      path: '/api/users/${Uri.encodeComponent(normalizedUserId)}/payment-cards',
    );
    final data = _decodeResponseList(response.body);
    return data
        .whereType<dynamic>()
        .map<Map<String, dynamic>>((item) {
          if (item is Map<String, dynamic>) {
            return item;
          }
          if (item is Map) {
            return item.map(
              (key, value) => MapEntry(key.toString(), value),
            );
          }
          return <String, dynamic>{};
        })
        .where((item) => item.isNotEmpty)
        .map(PaymentSavedCard.fromJson)
        .toList();
  }

  Future<PaymentSavedCard> createCard({
    required String userId,
    required PaymentSavedCard card,
  }) async {
    final normalizedUserId = _extractGuid(_normalizeId(userId, key: 'userId'));
    final requestBody = <String, dynamic>{
      ...card.toRequestJson(),
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
    };
    final response = await _requestWithFallback(
      method: 'POST',
      path: '/api/users/${Uri.encodeComponent(normalizedUserId)}/payment-cards',
      body: requestBody,
    );
    final data = _decodeResponseMap(response.body);
    return PaymentSavedCard.fromJson(data);
  }

  Future<PaymentSavedCard> updateCard({
    required String userId,
    required String paymentCardId,
    required PaymentSavedCard card,
  }) async {
    final normalizedUserId = _extractGuid(_normalizeId(userId, key: 'userId'));
    final normalizedCardId = _extractGuid(
      _normalizeId(paymentCardId, key: 'paymentCardId'),
    );
    final response = await _requestWithFallback(
      method: 'PUT',
      path:
          '/api/users/${Uri.encodeComponent(normalizedUserId)}/payment-cards/'
          '${Uri.encodeComponent(normalizedCardId)}',
      body: card.toRequestJson(),
    );
    final data = _decodeResponseMap(response.body);
    return PaymentSavedCard.fromJson(data);
  }

  Future<void> deleteCard({
    required String userId,
    required String paymentCardId,
  }) async {
    final normalizedUserId = _extractGuid(_normalizeId(userId, key: 'userId'));
    final normalizedCardId = _extractGuid(
      _normalizeId(paymentCardId, key: 'paymentCardId'),
    );
    await _requestWithFallback(
      method: 'DELETE',
      path:
          '/api/users/${Uri.encodeComponent(normalizedUserId)}/payment-cards/'
          '${Uri.encodeComponent(normalizedCardId)}',
    );
  }

  Future<http.Response> _requestWithFallback({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    for (final baseUrl in _authService.baseUrls) {
      try {
        final uri = _buildRequestUri(baseUrl: baseUrl, path: path);
        final request = http.Request(method, uri);
        request.headers['Content-Type'] = 'application/json; charset=utf-8';
        if (body != null) {
          final normalizedBody = _normalizeRequestBody(body);
          final encodedBody = jsonEncode(normalizedBody);
          if (kDebugMode) {
            debugPrint('PaymentCardService $method encoded body: $encodedBody');
          }
          request.bodyBytes = utf8.encode(encodedBody);
        }
        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 8),
        );
        final response = await http.Response.fromStream(streamedResponse);
        if (kDebugMode) {
          debugPrint(
            'PaymentCardService $method response status: ${response.statusCode}',
          );
          debugPrint('PaymentCardService $method response body: ${response.body}');
        }
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }
        if (kDebugMode) {
          debugPrint(
            'PaymentCardService $method response error '
            '($baseUrl): ${response.statusCode} ${response.body}',
          );
        }
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('PaymentCardService $method error ($baseUrl): $error');
        }
      }
    }

    throw AuthException(
      'Sunucuya baglanilamadi. Lutfen baglantinizi kontrol edin.',
    );
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

      // Unwrap accidentally stringified JSON payloads.
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
      return value.map((key, nestedValue) {
        return MapEntry(key, _normalizePayloadValue(nestedValue));
      });
    }

    if (value is List) {
      return value.map(_normalizePayloadValue).toList();
    }

    return value;
  }

  String _sanitizeText(String input) {
    final compactWhitespace = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Remove control characters that can break URI/body processing.
    return compactWhitespace.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '');
  }

  String _normalizeId(String raw, {required String key}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    dynamic candidate = trimmed;

    // Some call sites send IDs as deeply wrapped JSON strings.
    for (var i = 0; i < 3; i++) {
      if (candidate is String) {
        final text = candidate.trim();
        if (text.isEmpty) {
          return text;
        }

        final looksJson =
            (text.startsWith('"') && text.endsWith('"')) ||
            (text.startsWith('{') && text.endsWith('}')) ||
            (text.startsWith('[') && text.endsWith(']'));
        if (!looksJson) {
          candidate = text;
          break;
        }

        try {
          candidate = jsonDecode(text);
          continue;
        } catch (_) {
          candidate = text;
          break;
        }
      }

      if (candidate is Map<String, dynamic>) {
        final value = candidate[key];
        if (value != null) {
          return value.toString().trim();
        }
        break;
      }

      if (candidate is List) {
        for (final item in candidate) {
          if (item is Map<String, dynamic> && item[key] != null) {
            return item[key].toString().trim();
          }
        }
        break;
      }

      break;
    }

    final asString = candidate.toString().trim();
    final guidMatch = RegExp(
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    ).firstMatch(asString);
    if (guidMatch != null) {
      return guidMatch.group(0)!;
    }

    return asString;
  }

  String _extractGuid(String source) {
    final guidMatch = RegExp(
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    ).firstMatch(source);
    if (guidMatch == null) {
      throw ArgumentError('Invalid id format: $source');
    }
    return guidMatch.group(0)!;
  }

  dynamic _decodeJsonFlexible(String input) {
    var candidate = _sanitizeText(input);
    dynamic decoded = candidate;
    for (var i = 0; i < 3; i++) {
      if (decoded is! String) {
        break;
      }
      final text = decoded.trim();
      if (text.isEmpty) {
        return text;
      }
      final looksJson =
          (text.startsWith('"') && text.endsWith('"')) ||
          (text.startsWith('{') && text.endsWith('}')) ||
          (text.startsWith('[') && text.endsWith(']'));
      if (!looksJson) {
        return text;
      }
      decoded = jsonDecode(text);
    }
    return decoded;
  }

  List<dynamic> _decodeResponseList(String body) {
    try {
      final decoded = _decodeJsonFlexible(body);
      if (decoded is List<dynamic>) {
        return decoded;
      }
      if (decoded is List) {
        return decoded.toList();
      }
      if (decoded is Map<String, dynamic>) {
        final items = decoded['items'];
        if (items is List) {
          return items.toList();
        }
      }
      throw const FormatException('Kart listesi bekleniyor.');
    } catch (error) {
      throw AuthException('Kart verisi okunurken bir hata oluştu: $error');
    }
  }

  Map<String, dynamic> _decodeResponseMap(String body) {
    try {
      final decoded = _decodeJsonFlexible(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
      throw const FormatException('Kart detayi bekleniyor.');
    } catch (error) {
      throw AuthException('Kart verisi okunurken bir hata oluştu: $error');
    }
  }
}
