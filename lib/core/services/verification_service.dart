import 'dart:convert';

import 'package:flutter_sweet_shop_app_ui/core/services/api_http_client.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';

class VerificationService {
  VerificationService({AuthService? authService})
      : _auth = authService ?? AuthService();

  final AuthService _auth;
  final ApiHttpClient _http = ApiHttpClient();

  Map<String, String> get _headers {
    final token = AppSession.token;
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> sendEmailVerification(String userId) async {
    final response = await _http.post(
      Uri.parse(
        '${_auth.baseUrls.first}/api/auth/verify-email/send?userId=$userId',
      ),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_message(response));
    }
  }

  Future<void> verifyEmail(String userId, String code) async {
    final response = await _http.post(
      Uri.parse('${_auth.baseUrls.first}/api/auth/verify-email?userId=$userId'),
      headers: _headers,
      body: jsonEncode({'email': '', 'code': code}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_message(response));
    }
  }

  Future<void> sendSmsOtp(String userId, String phone) async {
    final response = await _http.post(
      Uri.parse('${_auth.baseUrls.first}/api/auth/verify-sms/send?userId=$userId'),
      headers: _headers,
      body: jsonEncode({'phone': phone}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_message(response));
    }
  }

  Future<void> verifySms(String userId, String phone, String code) async {
    final response = await _http.post(
      Uri.parse('${_auth.baseUrls.first}/api/auth/verify-sms?userId=$userId'),
      headers: _headers,
      body: jsonEncode({'phone': phone, 'code': code}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_message(response));
    }
  }

  String _message(dynamic response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {}
    return 'Doğrulama işlemi başarısız.';
  }
}
