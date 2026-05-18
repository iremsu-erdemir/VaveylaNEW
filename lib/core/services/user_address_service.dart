import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/user_address.dart';
import '../utils/guid_utils.dart';
import 'app_session.dart';
import 'auth_service.dart';

class UserAddressService {
  UserAddressService({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  Map<String, String> get _headers {
    final token = AppSession.token;
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
    };
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<List<UserAddress>> getAddresses({required String userId}) async {
    final userGuid = _requireUserId(userId);
    final response = await _getWithFallback(
      path: '/api/users/$userGuid/addresses',
    );
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map(UserAddress.fromJson)
          .toList();
    }

    throw AuthException(_extractMessage(response));
  }

  static String? _safeString(String? value) {
    if (value == null || value.isEmpty) return value;
    return value
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F\u200B-\u200D\uFEFF]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<UserAddress> createAddress({
    required String userId,
    required String label,
    required String addressLine,
    String? addressDetail,
    bool isSelected = true,
  }) async {
    final userGuid = _requireUserId(userId);
    final safeLabel = _safeString(label);
    final safeLine = _safeString(addressLine);
    final safeDetail =
        addressDetail == null || addressDetail.trim().isEmpty
            ? null
            : _safeString(addressDetail);
    final response = await _requestWithFallback(
      method: 'POST',
      path: '/api/users/$userGuid/addresses',
      body: {
        'label': safeLabel,
        'addressLine': safeLine,
        'addressDetail': safeDetail,
        'isSelected': isSelected,
      },
      skipNormalization: true,
    );
    return _decodeAddress(response);
  }

  Future<UserAddress> updateAddress({
    required String userId,
    required String addressId,
    required String label,
    required String addressLine,
    String? addressDetail,
    required bool isSelected,
  }) async {
    final userGuid = _requireUserId(userId);
    final addressGuid = _requireAddressId(addressId);
    final safeLabel = _safeString(label);
    final safeLine = _safeString(addressLine);
    final safeDetail =
        addressDetail == null || addressDetail.trim().isEmpty
            ? null
            : _safeString(addressDetail);
    final response = await _requestWithFallback(
      method: 'PUT',
      path: '/api/users/$userGuid/addresses/$addressGuid',
      body: {
        'label': safeLabel,
        'addressLine': safeLine,
        'addressDetail': safeDetail,
        'isSelected': isSelected,
      },
      skipNormalization: true,
    );
    return _decodeAddress(response);
  }

  Future<void> deleteAddress({
    required String userId,
    required String addressId,
  }) async {
    final userGuid = _requireUserId(userId);
    final addressGuid = _requireAddressId(addressId);
    final response = await _requestWithFallback(
      method: 'DELETE',
      path: '/api/users/$userGuid/addresses/$addressGuid',
    );
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      return;
    }

    throw AuthException(_extractMessage(response));
  }

  String _requireUserId(String raw) {
    final id = tryExtractUuid(raw);
    if (id == null || !isValidUuid(id)) {
      throw AuthException('Geçersiz kullanıcı kimliği.');
    }
    return id;
  }

  String _requireAddressId(String raw) {
    final id = tryExtractUuid(raw);
    if (id == null || !isValidUuid(id)) {
      throw AuthException('Geçersiz adres kimliği.');
    }
    return id;
  }

  Future<http.Response> _getWithFallback({required String path}) async {
    for (final baseUrl in _authService.baseUrls) {
      try {
        final uri = _buildRequestUri(baseUrl: baseUrl, path: path);
        return await http
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 8));
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('UserAddressService GET hata ($baseUrl): $error');
        }
      }
    }
    throw AuthException(
      'Sunucuya baglanilamadi. Lutfen baglantinizi kontrol edin.',
    );
  }

  Future<http.Response> _requestWithFallback({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    bool skipNormalization = false,
  }) async {
    for (final baseUrl in _authService.baseUrls) {
      try {
        final uri = _buildRequestUri(baseUrl: baseUrl, path: path);
        final request = http.Request(method, uri);
        _headers.forEach((k, v) => request.headers[k] = v);
        if (body != null) {
          final requestBody =
              skipNormalization ? body : _normalizeRequestBody(body);
          request.bodyBytes = Uint8List.fromList(
            JsonUtf8Encoder().convert(requestBody),
          );
        }
        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 8),
        );
        final response = await http.Response.fromStream(streamedResponse);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }
        if (response.statusCode >= 400) {
          throw AuthException(_extractMessage(response));
        }
        if (kDebugMode) {
          debugPrint(
            'UserAddressService $method cevap hata ($baseUrl): ${response.statusCode} ${response.body}',
          );
        }
      } on AuthException {
        rethrow;
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('UserAddressService $method hata ($baseUrl): $error');
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
    return body.map(
      (key, value) => MapEntry(key, _normalizePayloadValue(value)),
    );
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
        (key, nestedValue) =>
            MapEntry(key, _normalizePayloadValue(nestedValue)),
      );
    }

    if (value is List) {
      return value.map(_normalizePayloadValue).toList();
    }

    return value;
  }

  String _sanitizeText(String input) {
    if (input.isEmpty) return input;
    var text = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    text = text.replaceAll(
      RegExp(r'[\u0000-\u001F\u007F\u200B-\u200D\uFEFF]'),
      '',
    );
    return text;
  }

  UserAddress _decodeAddress(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return UserAddress.fromJson(data);
    }

    throw AuthException(_extractMessage(response));
  }

  String _extractMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        if (data['message'] != null) {
          return data['message'].toString();
        }
        final errors = data['errors'];
        if (errors is Map<String, dynamic>) {
          for (final v in errors.values) {
            if (v is List && v.isNotEmpty) {
              return v.first.toString();
            }
          }
        }
      }
    } catch (_) {}
    if (response.body.isNotEmpty) {
      return response.body;
    }
    return 'Islem sirasinda bir hata olustu.';
  }
}
