import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/models/home_marketing_banner_model.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:http/http.dart' as http;

/// Herkese açık — ana sayfa kaydırıcı.
class HomeMarketingBannersService {
  HomeMarketingBannersService({AuthService? authService})
      : _baseUrls = (authService ?? AuthService()).baseUrls;

  final List<String> _baseUrls;

  Future<List<HomeMarketingBannerModel>> fetchActive() async {
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/api/home/marketing-banners'))
            .timeout(const Duration(seconds: 12));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          if (data is List) {
            return data
                .whereType<Map>()
                .map(
                  (e) => HomeMarketingBannerModel.fromPublicJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .where((b) => b.imageUrl.trim().isNotEmpty)
                .toList();
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('HomeMarketingBannersService: $e');
      }
    }
    return [];
  }
}
