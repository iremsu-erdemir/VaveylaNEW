import 'dart:convert';

import 'package:flutter_sweet_shop_app_ui/core/services/api_http_client.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';

class AccountDeletionService {
  AccountDeletionService({AuthService? authService})
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

  Future<Map<String, dynamic>> getStatus(String userId) async {
    final response = await _http.get(
      Uri.parse('${_auth.baseUrls.first}/api/users/$userId/account-deletion'),
      headers: _headers,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiHttpClient.decodeJsonMap(response) ?? {};
    }
    throw AuthException(_message(response));
  }

  Future<void> scheduleDeletion({
    required String userId,
    required String password,
    required bool confirmDataPolicy,
  }) async {
    final response = await _http.post(
      Uri.parse('${_auth.baseUrls.first}/api/users/$userId/account-deletion'),
      headers: _headers,
      body: jsonEncode({
        'password': password,
        'confirmDataPolicy': confirmDataPolicy,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_message(response));
    }
  }

  Future<void> cancelDeletion(String userId) async {
    final response = await _http.delete(
      Uri.parse('${_auth.baseUrls.first}/api/users/$userId/account-deletion'),
      headers: _headers,
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
    return 'İşlem başarısız';
  }
}
