import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:http/http.dart' as http;

class AdminRestaurantDiscountService {
  AdminRestaurantDiscountService({
    AuthService? authService,
  }) : _baseUrls = (authService ?? AuthService()).baseUrls;

  final List<String> _baseUrls;

  Map<String, String> get _headers {
    final token = AppSession.token;
    if (token.isEmpty) return const {'Content-Type': 'application/json'};
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<RestaurantDiscountDto>> getApprovedDiscounts() async {
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http
            .get(
              Uri.parse('$baseUrl/api/admin/restaurants/approved-discounts'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          if (data is List) {
            return data
                .whereType<Map>()
                .map((e) => RestaurantDiscountDto.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('AdminRestaurantDiscountService: $e');
      }
    }
    return [];
  }

  Future<List<PendingRestaurantDiscountDto>> getPendingDiscounts() async {
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http
            .get(
              Uri.parse('$baseUrl/api/admin/restaurants/pending-discounts'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          if (data is List) {
            return data
                .whereType<Map>()
                .map((e) => PendingRestaurantDiscountDto.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('AdminRestaurantDiscountService: $e');
      }
    }
    return [];
  }

  /// [restaurantDiscountPercent] opsiyonel - yanlış kaydedilen değeri düzeltmek için (örn. 10 yerine 25)
  Future<void> approveDiscount(String restaurantId, {double? restaurantDiscountPercent}) async {
    final body = restaurantDiscountPercent != null && restaurantDiscountPercent > 0 && restaurantDiscountPercent <= 100
        ? jsonEncode({'restaurantDiscountPercent': restaurantDiscountPercent})
        : '{}';
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl/api/admin/restaurants/$restaurantId/approve-discount'),
              headers: _headers,
              body: body,
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode >= 200 && response.statusCode < 300) return;
      } catch (e) {
        if (kDebugMode) debugPrint('AdminRestaurantDiscountService: $e');
      }
    }
    throw AuthException('İşlem başarısız.');
  }

  /// Onaylı veya onay bekleyen restoranın indirim yüzdesini güncelle (yanlış kaydedilen değeri düzeltmek için)
  Future<void> updateDiscountPercent(String restaurantId, double percent) async {
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http
            .put(
              Uri.parse('$baseUrl/api/admin/restaurants/$restaurantId/discount'),
              headers: _headers,
              body: jsonEncode({'restaurantDiscountPercent': percent}),
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode >= 200 && response.statusCode < 300) return;
      } catch (e) {
        if (kDebugMode) debugPrint('AdminRestaurantDiscountService: $e');
      }
    }
    throw AuthException('İşlem başarısız.');
  }

  Future<void> rejectDiscount(String restaurantId) async {
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl/api/admin/restaurants/$restaurantId/reject-discount'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode >= 200 && response.statusCode < 300) return;
      } catch (e) {
        if (kDebugMode) debugPrint('AdminRestaurantDiscountService: $e');
      }
    }
    throw AuthException('İşlem başarısız.');
  }
}

class PendingRestaurantDiscountDto {
  final String restaurantId;
  final String name;
  final double restaurantDiscountPercent;

  PendingRestaurantDiscountDto({
    required this.restaurantId,
    required this.name,
    required this.restaurantDiscountPercent,
  });

  factory PendingRestaurantDiscountDto.fromJson(Map<String, dynamic> json) {
    return PendingRestaurantDiscountDto(
      restaurantId: json['restaurantId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      restaurantDiscountPercent: _parseDouble(json['restaurantDiscountPercent']) ?? 0,
    );
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

class RestaurantDiscountDto {
  final String restaurantId;
  final String name;
  final double restaurantDiscountPercent;
  final bool restaurantDiscountIsActive;

  RestaurantDiscountDto({
    required this.restaurantId,
    required this.name,
    required this.restaurantDiscountPercent,
    this.restaurantDiscountIsActive = true,
  });

  factory RestaurantDiscountDto.fromJson(Map<String, dynamic> json) {
    return RestaurantDiscountDto(
      restaurantId: json['restaurantId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      restaurantDiscountPercent: PendingRestaurantDiscountDto._parseDouble(json['restaurantDiscountPercent']) ?? 0,
      restaurantDiscountIsActive: json['restaurantDiscountIsActive'] != false,
    );
  }
}
