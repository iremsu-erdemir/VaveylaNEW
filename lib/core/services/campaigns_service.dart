import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:http/http.dart' as http;

class CampaignModel {
  final String campaignId;
  final String name;
  final String? description;
  final int discountType;
  final double discountValue;
  final int targetType;
  final String? targetId;
  final String? targetCategoryName;
  final double? minCartAmount;
  final String? restaurantId;

  CampaignModel({
    required this.campaignId,
    required this.name,
    this.description,
    required this.discountType,
    required this.discountValue,
    required this.targetType,
    this.targetId,
    this.targetCategoryName,
    this.minCartAmount,
    this.restaurantId,
  });

  factory CampaignModel.fromJson(Map<String, dynamic> json) {
    return CampaignModel(
      campaignId: json['campaignId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      discountType: int.tryParse(json['discountType']?.toString() ?? '') ?? 0,
      discountValue: _parseDouble(json['discountValue']) ?? 0,
      targetType: int.tryParse(json['targetType']?.toString() ?? '') ?? 0,
      targetId: json['targetId']?.toString(),
      targetCategoryName: json['targetCategoryName']?.toString(),
      minCartAmount: _parseDouble(json['minCartAmount']),
      restaurantId: json['restaurantId']?.toString(),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String get discountLabel {
    if (discountType == 1) return '%$discountValue indirim';
    return '$discountValue ₺ indirim';
  }
}

class CampaignsService {
  CampaignsService({
    AuthService? authService,
    String? baseUrl,
    List<String>? baseUrls,
  }) : _baseUrls = baseUrl != null || (baseUrls != null && baseUrls.isNotEmpty)
      ? AuthService(baseUrl: baseUrl, baseUrls: baseUrls).baseUrls
      : (authService ?? AuthService()).baseUrls;

  final List<String> _baseUrls;

  Future<List<CampaignModel>> getActiveCampaigns({String? restaurantId}) async {
    var path = '/api/campaigns/active';
    if (restaurantId != null && restaurantId.isNotEmpty) {
      path += '?restaurantId=$restaurantId';
    }
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl$path'))
            .timeout(const Duration(seconds: 8));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          if (data is List) {
            return data
                .whereType<Map>()
                .map((e) => CampaignModel.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('CampaignsService: $e');
      }
    }
    return [];
  }
}
