import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart' show AuthException, AuthService;
import 'package:http/http.dart' as http;

class RestaurantCampaignService {
  RestaurantCampaignService({
    AuthService? authService,
    String? baseUrl,
    List<String>? baseUrls,
  }) : _baseUrls = baseUrl != null || (baseUrls != null && baseUrls.isNotEmpty)
      ? AuthService(baseUrl: baseUrl, baseUrls: baseUrls).baseUrls
      : (authService ?? AuthService()).baseUrls;

  final List<String> _baseUrls;

  Map<String, String> get _headers {
    final token = AppSession.token;
    if (token.isEmpty) return const {'Content-Type': 'application/json'};
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<dynamic>> getCampaigns() async {
    final response = await _get('/api/restaurant/campaigns');
    if (response is List) return response;
    return [];
  }

  Future<Map<String, dynamic>?> createCampaign(Map<String, dynamic> body) async {
    final response = await _post('/api/restaurant/campaigns', body);
    return response as Map<String, dynamic>?;
  }

  Future<void> updateCampaign(String id, Map<String, dynamic> body) async {
    await _put('/api/restaurant/campaigns/$id', body);
  }

  Future<void> deleteCampaign(String id) async {
    await _delete('/api/restaurant/campaigns/$id');
  }

  Future<dynamic> _get(String path) async {
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl$path'), headers: _headers)
            .timeout(const Duration(seconds: 8));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return jsonDecode(response.body);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('RestaurantCampaignService: $e');
      }
    }
    return null;
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    http.Response? lastResponse;
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl$path'),
              headers: _headers,
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 8));
        lastResponse = response;
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return jsonDecode(response.body);
        }
        throw AuthException(_extractMessage(response));
      } on AuthException {
        rethrow;
      } catch (e) {
        if (kDebugMode) debugPrint('RestaurantCampaignService POST: $e');
      }
    }
    if (lastResponse != null) {
      throw AuthException(_extractMessage(lastResponse));
    }
    throw AuthException('Sunucuya bağlanılamadı.');
  }

  Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http
            .put(
              Uri.parse('$baseUrl$path'),
              headers: _headers,
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response.body.isEmpty ? true : jsonDecode(response.body);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('RestaurantCampaignService PUT: $e');
      }
    }
    return null;
  }

  Future<void> _delete(String path) async {
    for (final baseUrl in _baseUrls) {
      try {
        await http
            .delete(Uri.parse('$baseUrl$path'), headers: _headers)
            .timeout(const Duration(seconds: 8));
        return;
      } catch (e) {
        if (kDebugMode) debugPrint('RestaurantCampaignService DELETE: $e');
      }
    }
    throw Exception('Sunucuya bağlanılamadı.');
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
