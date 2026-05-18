import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/auth_response.dart';
import '../utils/app_feedback.dart';

class AuthService {
  AuthService({String? baseUrl, List<String>? baseUrls})
    : _baseUrls = _resolveBaseUrls(baseUrl, baseUrls);

  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
  final List<String> _baseUrls;
  List<String> get baseUrls => _baseUrls;

  /// Kayıt/giriş hangi tabanda başarılı olduysa sonraki auth istekleri önce oraya gider.
  /// Aksi halde kayıt yedek IP'ye yazılıp giriş birincil (boş) veritabanına düşebilir.
  static String? _pinnedAuthBaseUrl;

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _postWithFallback(
      path: '/api/auth/login',
      body: {'email': email, 'password': password},
      pinHostOn2xx: true,
    );
    return _handleAuthResponse(response);
  }

  Future<AuthResponse> register({
    required String fullName,
    required String email,
    required String password,
    required int roleId,
    required bool isPrivacyPolicyAccepted,
    required bool isTermsOfServiceAccepted,
  }) async {
    final response = await _postWithFallback(
      path: '/api/auth/register',
      body: {
        'fullName': fullName,
        'email': email,
        'password': password,
        'roleId': roleId,
        'isPrivacyPolicyAccepted': isPrivacyPolicyAccepted,
        'isTermsOfServiceAccepted': isTermsOfServiceAccepted,
      },
      pinHostOn2xx: true,
    );
    return _handleAuthResponse(response);
  }

  Future<String> requestPasswordResetCode({required String email}) async {
    final response = await _postWithFallback(
      path: '/api/auth/forgot-password/request-code',
      body: {'email': email},
    );
    return _handleMessageResponse(response, fallbackMessage: 'Kod gönderildi.');
  }

  Future<String> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    final response = await _postWithFallback(
      path: '/api/auth/forgot-password/verify-code',
      body: {'email': email, 'code': code},
    );
    return _handleMessageResponse(
      response,
      fallbackMessage: 'Doğrulama başarılı.',
    );
  }

  Future<String> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await _postWithFallback(
      path: '/api/auth/forgot-password/reset-password',
      body: {'email': email, 'code': code, 'newPassword': newPassword},
    );
    return _handleMessageResponse(
      response,
      fallbackMessage: 'Şifre başarıyla güncellendi.',
    );
  }

  Future<http.Response> _postWithFallback({
    required String path,
    required Map<String, dynamic> body,
    bool pinHostOn2xx = false,
  }) async {
    final ordered = <String>[
      if (_pinnedAuthBaseUrl != null &&
          _baseUrls.contains(_pinnedAuthBaseUrl))
        _pinnedAuthBaseUrl!,
      ..._baseUrls.where((u) => u != _pinnedAuthBaseUrl),
    ];

    for (final baseUrl in ordered) {
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl$path'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 8));
        if (pinHostOn2xx &&
            response.statusCode >= 200 &&
            response.statusCode < 300) {
          _pinnedAuthBaseUrl = baseUrl;
        }
        return response;
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('AuthService bağlantı hatası ($baseUrl): $error');
        }
      }
    }
    if (kDebugMode) {
      debugPrint(
        'AuthService: API çalışmıyor olabilir. Ayrı terminalde çalıştırın: '
        'cd backend\\Vaveyla.Api ; dotnet run --launch-profile http',
      );
    }
    throw AuthException(
      'Sunucuya bağlanılamadı. Lütfen bağlantınızı kontrol edin.',
    );
  }

  AuthResponse _handleAuthResponse(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return AuthResponse.fromJson(data);
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

    if (response.body.isNotEmpty) {
      return response.body;
    }
    return 'İşlem sırasında bir hata oluştu.';
  }

  String _handleMessageResponse(
    http.Response response, {
    required String fallbackMessage,
  }) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      try {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> &&
            data['message'] != null &&
            data['message'].toString().trim().isNotEmpty) {
          return data['message'].toString();
        }
      } catch (_) {}
      return fallbackMessage;
    }

    throw AuthException(_extractMessage(response));
  }

  static List<String> _resolveBaseUrls(
    String? baseUrl,
    List<String>? baseUrls,
  ) {
    final urls = <String>[];
    if (baseUrl != null && baseUrl.trim().isNotEmpty) {
      urls.add(baseUrl.trim());
      return urls;
    }
    if (baseUrls != null && baseUrls.isNotEmpty) {
      urls.addAll(baseUrls.where((url) => url.trim().isNotEmpty));
      if (urls.isNotEmpty) {
        return urls;
      }
    }
    if (_envBaseUrl.trim().isNotEmpty) {
      urls.add(_envBaseUrl.trim());
      return urls;
    }
    if (kIsWeb) {
      // 127.0.0.1 önce: Windows'ta localhost bazen IPv6/çözümleme gecikmesi yapabiliyor.
      urls.addAll(['http://127.0.0.1:5142', 'http://localhost:5142']);
      return urls;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        urls.addAll(['http://10.0.2.2:5142', 'http://192.168.1.102:5142']);
        return urls;
      case TargetPlatform.iOS:
        urls.addAll(['http://127.0.0.1:5142', 'http://192.168.1.102:5142']);
        return urls;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        urls.addAll(['http://localhost:5142', 'http://127.0.0.1:5142']);
        return urls;
      case TargetPlatform.fuchsia:
        urls.addAll(['http://localhost:5142', 'http://127.0.0.1:5142']);
        return urls;
    }
  }
}

class AuthException implements Exception {
  AuthException(String message) : message = localizeFeedbackMessage(message);

  final String message;

  @override
  String toString() => message;
}
