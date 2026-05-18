import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:http/http.dart' as http;

class AdminService {
  AdminService({
    AuthService? authService,
    String? baseUrl,
    List<String>? baseUrls,
  }) : _baseUrls = baseUrl != null || (baseUrls != null && baseUrls.isNotEmpty)
      ? AuthService(baseUrl: baseUrl, baseUrls: baseUrls).baseUrls
      : (authService ?? AuthService()).baseUrls;

  final List<String> _baseUrls;

  Future<List<dynamic>> getCampaigns() async {
    final response = await _get('/api/admin/campaigns');
    if (response is List) return response;
    return [];
  }

  Future<Map<String, dynamic>?> createCampaign(Map<String, dynamic> body) async {
    final response = await _post('/api/admin/campaigns', body);
    return response as Map<String, dynamic>?;
  }

  Future<void> approveCampaign(String id) async {
    await _put('/api/admin/campaigns/$id/approve', {});
  }

  Future<void> rejectCampaign(String id) async {
    await _put('/api/admin/campaigns/$id/reject', {});
  }

  Future<void> deactivateCampaign(String id) async {
    await _put('/api/admin/campaigns/$id/deactivate', {});
  }

  Future<List<dynamic>> getRestaurants() async {
    final response = await _get('/api/admin/restaurants');
    if (response is List) return response;
    return [];
  }

  Future<void> toggleRestaurantStatus(String id) async {
    await _put('/api/admin/restaurants/$id/toggle-status', {});
  }

  Future<void> setRestaurantCommission(String id, double rate) async {
    await _put(
      '/api/admin/restaurants/$id/set-commission',
      {'commissionRate': rate},
    );
  }

  Future<List<dynamic>> getOrders({int? skip, int? take}) async {
    var path = '/api/admin/orders';
    if (skip != null || take != null) {
      path += '?';
      if (skip != null) path += 'skip=$skip';
      if (take != null) path += '${skip != null ? '&' : ''}take=$take';
    }
    final response = await _get(path);
    if (response is List) return response;
    return [];
  }

  Future<Map<String, dynamic>?> getOrderDetail(String id) async {
    final response = await _get('/api/admin/orders/$id');
    return response as Map<String, dynamic>?;
  }

  Map<String, String> get _headers {
    final token = AppSession.token;
    if (token.isEmpty) return const {'Content-Type': 'application/json'};
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
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
        if (kDebugMode) debugPrint('AdminService GET: $e');
      }
    }
    return null;
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl$path'),
              headers: _headers,
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return jsonDecode(response.body);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('AdminService POST: $e');
      }
    }
    return null;
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
        if (kDebugMode) debugPrint('AdminService PUT: $e');
      }
    }
    return null;
  }
}
