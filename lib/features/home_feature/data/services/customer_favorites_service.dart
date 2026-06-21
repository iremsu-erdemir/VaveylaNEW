import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/models/favorite_models.dart';
import 'package:http/http.dart' as http;

class CustomerFavoritesService {
  CustomerFavoritesService({
    AuthService? authService,
    String? baseUrl,
    List<String>? baseUrls,
  }) : _baseUrls =
           baseUrl != null || (baseUrls != null && baseUrls.isNotEmpty)
               ? AuthService(baseUrl: baseUrl, baseUrls: baseUrls).baseUrls
               : (authService ?? AuthService()).baseUrls;

  final List<String> _baseUrls;

  Future<CustomerFavoritesModel> getFavorites({
    required String customerUserId,
  }) async {
    final response = await _getWithFallback(
      path: '/api/customer/favorites?customerUserId=$customerUserId',
    );
    final data = _decodeJson(response);
    if (data is! Map<String, dynamic>) {
      return CustomerFavoritesModel(restaurants: const [], products: const []);
    }
    return CustomerFavoritesModel.fromJson(data);
  }

  Future<void> addRestaurantFavorite({
    required String customerUserId,
    required String restaurantId,
  }) {
    return _addFavorite(
      customerUserId: customerUserId,
      type: 'restaurant',
      targetId: restaurantId,
    );
  }

  Future<void> removeRestaurantFavorite({
    required String customerUserId,
    required String restaurantId,
  }) {
    return _removeFavorite(
      customerUserId: customerUserId,
      type: 'restaurant',
      targetId: restaurantId,
    );
  }

  Future<void> addProductFavorite({
    required String customerUserId,
    required String productId,
  }) {
    return _addFavorite(
      customerUserId: customerUserId,
      type: 'product',
      targetId: productId,
    );
  }

  Future<void> removeProductFavorite({
    required String customerUserId,
    required String productId,
  }) {
    return _removeFavorite(
      customerUserId: customerUserId,
      type: 'product',
      targetId: productId,
    );
  }

  Future<void> _addFavorite({
    required String customerUserId,
    required String type,
    required String targetId,
  }) async {
    await _postWithFallback(
      path: '/api/customer/favorites?customerUserId=$customerUserId',
      body: {'type': type, 'targetId': targetId},
    );
  }

  Future<void> _removeFavorite({
    required String customerUserId,
    required String type,
    required String targetId,
  }) async {
    await _deleteWithFallback(
      path:
          '/api/customer/favorites?customerUserId=$customerUserId&type=$type&targetId=$targetId',
    );
  }

  Future<http.Response> _getWithFallback({required String path}) async {
    for (final baseUrl in _baseUrls) {
      try {
        return await http
            .get(Uri.parse('$baseUrl$path'))
            .timeout(const Duration(seconds: 8));
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('CustomerFavoritesService GET hata ($baseUrl): $error');
        }
      }
    }
    throw AuthException('Sunucuya bağlanılamadı.');
  }

  Future<http.Response> _postWithFallback({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    for (final baseUrl in _baseUrls) {
      try {
        return await http
            .post(
              Uri.parse('$baseUrl$path'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 8));
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('CustomerFavoritesService POST hata ($baseUrl): $error');
        }
      }
    }
    throw AuthException('Sunucuya bağlanılamadı.');
  }

  Future<http.Response> _deleteWithFallback({required String path}) async {
    for (final baseUrl in _baseUrls) {
      try {
        return await http
            .delete(Uri.parse('$baseUrl$path'))
            .timeout(const Duration(seconds: 8));
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('CustomerFavoritesService DELETE hata ($baseUrl): $error');
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
    throw AuthException(_extractMessage(response));
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
