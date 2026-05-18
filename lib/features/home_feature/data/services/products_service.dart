import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart'
    show AuthException, AuthService;
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/product_model.dart';
import 'package:http/http.dart' as http;

class ProductsService {
  ProductsService({
    AuthService? authService,
    String? baseUrl,
    List<String>? baseUrls,
  }) : _baseUrls =
            baseUrl != null || (baseUrls != null && baseUrls.isNotEmpty)
                ? AuthService(baseUrl: baseUrl, baseUrls: baseUrls).baseUrls
                : (authService ?? AuthService()).baseUrls;

  final List<String> _baseUrls;

  static bool _platformLogged = false;
  void _logPlatformOnce() {
    if (kDebugMode && !_platformLogged) {
      _platformLogged = true;
      debugPrint('[API DEBUG] Platform: ${defaultTargetPlatform.name}');
      debugPrint('[API DEBUG] Base URLs: $_baseUrls');
      debugPrint('[API DEBUG] Android emulator için: 10.0.2.2:5142 kullanın, localhost çalışmaz');
    }
  }

  Future<List<ProductModel>> getProducts({
    String? type,
    String? category,
    String? restaurantId,
  }) async {
    final query = <String>[];
    if (type != null && type.isNotEmpty) query.add('type=$type');
    if (category != null && category.isNotEmpty) {
      query.add('category=${Uri.encodeComponent(category)}');
    }
    if (restaurantId != null && restaurantId.isNotEmpty) {
      query.add('restaurantId=${Uri.encodeComponent(restaurantId)}');
    }
    final qs = query.isEmpty ? '' : '?${query.join('&')}';
    _logPlatformOnce();
    final response = await _getWithFallback(path: '/api/products$qs');
    final data = _decodeJson(response);
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((m) => ProductModel.fromApiJson(m))
          .toList();
    }
    return [];
  }

  Future<List<ProductModel>> getFeatured() => getProducts(type: 'featured');
  Future<List<ProductModel>> getNew() => getProducts(type: 'new');
  Future<List<ProductModel>> getPopular() => getProducts(type: 'popular');

  Future<http.Response> _getWithFallback({required String path}) async {
    for (final baseUrl in _baseUrls) {
      final url = '$baseUrl$path';
      if (kDebugMode) {
        debugPrint('[API DEBUG] ProductsService GET: $url');
      }
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 25));
        if (kDebugMode) {
          debugPrint('[API DEBUG] ProductsService GET OK: $url => ${response.statusCode}');
        }
        return response;
      } on Exception catch (error, stack) {
        if (kDebugMode) {
          debugPrint('[API DEBUG] ProductsService GET HATA: $url');
          debugPrint('[API DEBUG] Hata: $error');
          debugPrint('[API DEBUG] Stack: $stack');
        }
      }
    }
    throw AuthException('Sunucuya bağlanılamadı.');
  }

  dynamic _decodeJson(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    throw AuthException('Ürünler yüklenemedi.');
  }
}
