import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/models/home_marketing_banner_model.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:http/http.dart' as http;

class AdminMarketingBannersService {
  AdminMarketingBannersService({AuthService? authService})
      : _baseUrls = (authService ?? AuthService()).baseUrls;

  final List<String> _baseUrls;

  Map<String, String> get _headers {
    final token = AppSession.token;
    if (token.isEmpty) return const {'Content-Type': 'application/json'};
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<HomeMarketingBannerModel>> listAll() async {
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http
            .get(
              Uri.parse('$baseUrl/api/admin/marketing-banners'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 12));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          if (data is List) {
            return data
                .whereType<Map>()
                .map(
                  (e) => HomeMarketingBannerModel.fromAdminJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList();
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('AdminMarketingBannersService list: $e');
      }
    }
    return [];
  }

  Future<HomeMarketingBannerModel?> create(HomeMarketingBannerModel draft) async {
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl/api/admin/marketing-banners'),
              headers: _headers,
              body: jsonEncode(draft.toUpsertBody()),
            )
            .timeout(const Duration(seconds: 12));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          if (data is Map) {
            return HomeMarketingBannerModel.fromAdminJson(
              Map<String, dynamic>.from(data),
            );
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('AdminMarketingBannersService create: $e');
      }
    }
    return null;
  }

  Future<HomeMarketingBannerModel?> update(
    String id,
    HomeMarketingBannerModel draft,
  ) async {
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http
            .put(
              Uri.parse('$baseUrl/api/admin/marketing-banners/$id'),
              headers: _headers,
              body: jsonEncode(draft.toUpsertBody()),
            )
            .timeout(const Duration(seconds: 12));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          if (data is Map) {
            return HomeMarketingBannerModel.fromAdminJson(
              Map<String, dynamic>.from(data),
            );
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('AdminMarketingBannersService update: $e');
      }
    }
    return null;
  }

  Future<bool> delete(String id) async {
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http
            .delete(
              Uri.parse('$baseUrl/api/admin/marketing-banners/$id'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 12));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('AdminMarketingBannersService delete: $e');
      }
    }
    return false;
  }
}
