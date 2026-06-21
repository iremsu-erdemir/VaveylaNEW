import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/coupon_feature/data/models/user_coupon_model.dart';
import 'package:http/http.dart' as http;

class CouponService {
  CouponService({
    AuthService? authService,
    String? baseUrl,
    List<String>? baseUrls,
  }) : _baseUrls =
           baseUrl != null || (baseUrls != null && baseUrls.isNotEmpty)
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

  Future<ApplyCouponResult> applyCode({
    required String customerUserId,
    required String code,
  }) async {
    final response = await _postWithFallback(
      path: '/api/coupons/apply-code?customerUserId=$customerUserId',
      body: {'code': code.trim().toUpperCase()},
    );
    if (response.statusCode == 404) {
      throw AuthException('Geçersiz veya süresi dolmuş kupon kodu.');
    }
    final data = _decodeJson(response);
    if (data is! Map<String, dynamic>) {
      throw AuthException('Geçersiz yanıt.');
    }
    final message = data['message']?.toString() ?? '';
    final userCouponId = data['userCouponId']?.toString();
    final couponCode = data['code']?.toString() ?? '';
    return ApplyCouponResult(
      success: true,
      userCouponId: userCouponId ?? '',
      code: couponCode,
      message: message,
    );
  }

  Future<List<UserCouponModel>> getMyCoupons({
    required String customerUserId,
  }) async {
    if (customerUserId.isEmpty) return [];
    final response = await _getWithFallback(
      path: '/api/coupons/my?customerUserId=$customerUserId',
    );
    final data = _decodeJson(response);
    if (data is! List) return [];
    if (kDebugMode) debugPrint('[API DEBUG] CouponService getMyCoupons: ${data.length} kupon');
    return data
        .whereType<Map>()
        .map((e) => UserCouponModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<http.Response> _getWithFallback({required String path}) async {
    for (final baseUrl in _baseUrls) {
      try {
        if (kDebugMode) debugPrint('[API DEBUG] CouponService GET: $baseUrl$path');
        final res = await http
            .get(Uri.parse('$baseUrl$path'), headers: _headers)
            .timeout(const Duration(seconds: 8));
        if (kDebugMode) debugPrint('[API DEBUG] CouponService GET OK: ${res.statusCode}');
        return res;
      } on Exception catch (e) {
        if (kDebugMode) debugPrint('CouponService GET hata ($baseUrl): $e');
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
        if (kDebugMode) debugPrint('CouponService POST hata ($baseUrl): $e');
      }
    }
    throw AuthException('Sunucuya bağlanılamadı.');
  }

  dynamic _decodeJson(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
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
    return 'Kupon işlemi başarısız.';
  }
}

class ApplyCouponResult {
  final bool success;
  final String userCouponId;
  final String code;
  final String message;

  ApplyCouponResult({
    required this.success,
    required this.userCouponId,
    required this.code,
    required this.message,
  });
}
