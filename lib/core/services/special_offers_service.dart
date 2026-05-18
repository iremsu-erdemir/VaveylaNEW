import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:http/http.dart' as http;

class SpecialOfferItem {
  final String type;
  final String id;
  final String title;
  final String? description;
  final int discountType;
  final double discountValue;
  final double? minCartAmount;
  final double? maxDiscountAmount;
  final String? restaurantId;
  final String? restaurantName;

  SpecialOfferItem({
    required this.type,
    required this.id,
    required this.title,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.minCartAmount,
    this.maxDiscountAmount,
    this.restaurantId,
    this.restaurantName,
  });

  String get discountLabel {
    if (discountType == 1) return '%${discountValue.toInt()} indirim';
    return '${discountValue.toInt()} ₺ indirim';
  }

  bool get isCoupon => type == 'coupon';
  bool get isRestaurantDiscount => type == 'restaurant_discount';

  factory SpecialOfferItem.fromJson(Map<String, dynamic> json) {
    return SpecialOfferItem(
      type: json['type']?.toString() ?? 'coupon',
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      discountType: _parseInt(json['discountType']) ?? 1,
      discountValue: _parseDouble(json['discountValue']) ?? 0,
      minCartAmount: _parseDouble(json['minCartAmount']),
      maxDiscountAmount: _parseDouble(json['maxDiscountAmount']),
      restaurantId: json['restaurantId']?.toString(),
      restaurantName: json['restaurantName']?.toString(),
    );
  }

  static int? _parseInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '');
  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

class RestaurantWithDiscount {
  final String restaurantId;
  final String name;
  final String type;
  final String? photoPath;
  final double discountPercent;
  final String address;

  RestaurantWithDiscount({
    required this.restaurantId,
    required this.name,
    required this.type,
    this.photoPath,
    required this.discountPercent,
    required this.address,
  });

  static double? _parseDoubleRwd(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory RestaurantWithDiscount.fromJson(Map<String, dynamic> json) {
    return RestaurantWithDiscount(
      restaurantId: json['restaurantId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      photoPath: json['photoPath']?.toString(),
      discountPercent: RestaurantWithDiscount._parseDoubleRwd(json['discountPercent']) ?? 0,
      address: json['address']?.toString() ?? '',
    );
  }
}

class SpecialOffersService {
  SpecialOffersService({
    AuthService? authService,
  }) : _baseUrls = (authService ?? AuthService()).baseUrls;

  final List<String> _baseUrls;

  Future<List<SpecialOfferItem>> getSpecialOffers({String? customerUserId}) async {
    for (final baseUrl in _baseUrls) {
      try {
        final uri = customerUserId != null && customerUserId.isNotEmpty
            ? Uri.parse('$baseUrl/api/special-offers?customerUserId=$customerUserId')
            : Uri.parse('$baseUrl/api/special-offers');
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 8));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          if (data is Map && data['items'] is List) {
            return (data['items'] as List)
                .whereType<Map>()
                .map((e) => SpecialOfferItem.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('SpecialOffersService: $e');
      }
    }
    return [];
  }

  Future<List<RestaurantWithDiscount>> getRestaurantsWithDiscount(double percent) async {
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/api/special-offers/restaurants-with-discount?discountPercent=$percent'))
            .timeout(const Duration(seconds: 8));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          if (data is List) {
            return data
                .whereType<Map>()
                .map((e) => RestaurantWithDiscount.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('SpecialOffersService: $e');
      }
    }
    return [];
  }
}
