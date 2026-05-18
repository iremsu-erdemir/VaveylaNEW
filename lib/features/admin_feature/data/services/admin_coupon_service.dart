import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:http/http.dart' as http;

class AdminCouponService {
  AdminCouponService({
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

  Future<List<PendingCouponDto>> getPendingCoupons() async {
    final response = await _getWithFallback(path: '/api/admin/coupons/pending');
    final data = _decodeJson(response);
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => PendingCouponDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> approveCoupon(String userCouponId) async {
    await _postWithFallback(
      path: '/api/admin/coupons/$userCouponId/approve',
      body: {},
    );
  }

  Future<List<CouponOption>> getCoupons() async {
    final response = await _getWithFallback(path: '/api/admin/coupons');
    final data = _decodeJson(response);
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => CouponOption.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<CustomerOption>> getCustomers() async {
    final response = await _getWithFallback(path: '/api/admin/coupons/customers');
    final data = _decodeJson(response);
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => CustomerOption.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> assignCouponToCustomer(String couponId, String customerUserId) async {
    await _postWithFallback(
      path: '/api/admin/coupons/assign-to-customer',
      body: {'couponId': couponId, 'customerUserId': customerUserId},
    );
  }

  /// Atanmış kuponları listele (Kullanıldı etiketi ile)
  Future<List<CouponAssignmentDto>> getCouponAssignments() async {
    final response = await _getWithFallback(path: '/api/admin/coupons/assignments');
    final data = _decodeJson(response);
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => CouponAssignmentDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<http.Response> _getWithFallback({required String path}) async {
    for (final baseUrl in _baseUrls) {
      try {
        return await http.get(Uri.parse('$baseUrl$path'), headers: _headers).timeout(const Duration(seconds: 8));
      } on Exception catch (e) {
        if (kDebugMode) debugPrint('AdminCouponService GET hata: $e');
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
              headers: _headers,
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 8));
      } on Exception catch (e) {
        if (kDebugMode) debugPrint('AdminCouponService POST hata: $e');
      }
    }
    throw AuthException('Sunucuya bağlanılamadı.');
  }

  dynamic _decodeJson(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    throw AuthException('İşlem başarısız.');
  }
}

class PendingCouponDto {
  final String userCouponId;
  final String userId;
  final String code;
  final String? userEmail;
  final DateTime createdAtUtc;

  PendingCouponDto({
    required this.userCouponId,
    required this.userId,
    required this.code,
    this.userEmail,
    required this.createdAtUtc,
  });

  factory PendingCouponDto.fromJson(Map<String, dynamic> json) {
    return PendingCouponDto(
      userCouponId: json['userCouponId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      userEmail: json['userEmail']?.toString(),
      createdAtUtc: DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class CouponOption {
  final String couponId;
  final String code;
  final String? description;
  final int discountType;
  final double discountValue;

  CouponOption({
    required this.couponId,
    required this.code,
    this.description,
    required this.discountType,
    required this.discountValue,
  });

  factory CouponOption.fromJson(Map<String, dynamic> json) {
    return CouponOption(
      couponId: json['couponId']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString(),
      discountType: int.tryParse(json['discountType']?.toString() ?? '') ?? 1,
      discountValue: (json['discountValue'] is num) ? (json['discountValue'] as num).toDouble() : 0,
    );
  }
}

class CouponAssignmentDto {
  final String userCouponId;
  final String userId;
  final String? userEmail;
  final String? userFullName;
  final String couponId;
  final String code;
  final int discountType;
  final double discountValue;
  final DateTime? expiresAtUtc;
  final String status;
  final bool isUsed;
  final DateTime? usedAtUtc;
  final String? orderId;
  final DateTime createdAtUtc;

  CouponAssignmentDto({
    required this.userCouponId,
    required this.userId,
    this.userEmail,
    this.userFullName,
    required this.couponId,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.expiresAtUtc,
    required this.status,
    required this.isUsed,
    this.usedAtUtc,
    this.orderId,
    required this.createdAtUtc,
  });

  factory CouponAssignmentDto.fromJson(Map<String, dynamic> json) {
    return CouponAssignmentDto(
      userCouponId: json['userCouponId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      userEmail: json['userEmail']?.toString(),
      userFullName: json['userFullName']?.toString(),
      couponId: json['couponId']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      discountType: int.tryParse(json['discountType']?.toString() ?? '') ?? 1,
      discountValue: (json['discountValue'] is num) ? (json['discountValue'] as num).toDouble() : 0,
      expiresAtUtc: DateTime.tryParse(json['expiresAtUtc']?.toString() ?? ''),
      status: json['status']?.toString() ?? 'unknown',
      isUsed: json['isUsed'] == true,
      usedAtUtc: DateTime.tryParse(json['usedAtUtc']?.toString() ?? ''),
      orderId: json['orderId']?.toString(),
      createdAtUtc: DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class CustomerOption {
  final String userId;
  final String fullName;
  final String email;

  CustomerOption({
    required this.userId,
    required this.fullName,
    required this.email,
  });

  factory CustomerOption.fromJson(Map<String, dynamic> json) {
    return CustomerOption(
      userId: json['userId']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }
}
