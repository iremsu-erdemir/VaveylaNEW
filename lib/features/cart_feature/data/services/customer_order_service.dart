import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/customer_order_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/reviewable_order_item_model.dart';
import 'package:http/http.dart' as http;

class CustomerOrderService {
  CustomerOrderService({
    AuthService? authService,
    String? baseUrl,
    List<String>? baseUrls,
  }) : _baseUrls =
            baseUrl != null || (baseUrls != null && baseUrls.isNotEmpty)
                ? AuthService(baseUrl: baseUrl, baseUrls: baseUrls).baseUrls
                : (authService ?? AuthService()).baseUrls;

  final List<String> _baseUrls;

  Future<List<CustomerOrderModel>> getOrders({
    required String customerUserId,
  }) async {
    if (kDebugMode) {
      debugPrint('[API DEBUG] CustomerOrderService GET: customerUserId=$customerUserId');
    }
    final response = await _getWithFallback(
      path: '/api/customer/orders?customerUserId=$customerUserId',
    );
    if (kDebugMode) {
      debugPrint(
        '[API DEBUG] CustomerOrderService GET OK: ${response.statusCode} body=${response.body.length} chars',
      );
    }
    final data = _decodeJson(response);
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => CustomerOrderModel.fromJson(item.cast<String, dynamic>()))
          .toList();
    }
    if (data is Map<String, dynamic>) {
      final orders = data['orders'];
      if (orders is List) {
        return orders
            .whereType<Map>()
            .map(
              (item) => CustomerOrderModel.fromJson(item.cast<String, dynamic>()),
            )
            .toList();
      }
      final values = data[r'$values'];
      if (values is List) {
        return values
            .whereType<Map>()
            .map(
              (item) => CustomerOrderModel.fromJson(item.cast<String, dynamic>()),
            )
            .toList();
      }
    }
    if (kDebugMode) {
      debugPrint(
        '[API DEBUG] CustomerOrderService GET unexpected payload type: ${data.runtimeType}',
      );
    }
    return [];
  }

  Future<Map<String, dynamic>> createOrder({
    required String customerUserId,
    required String restaurantId,
    required String items,
    required int total,
    required String deliveryAddress,
    String? deliveryAddressDetail,
    double? customerLat,
    double? customerLng,
    String? customerName,
    String? customerPhone,
    String? userCouponId,
  }) async {
    final body = <String, dynamic>{
      'restaurantId': restaurantId,
      'items': items,
      'total': total,
      'deliveryAddress': deliveryAddress,
      'deliveryAddressDetail': deliveryAddressDetail,
      'customerLat': customerLat,
      'customerLng': customerLng,
      'customerName': customerName,
      'customerPhone': customerPhone,
    };
    if (userCouponId != null && userCouponId.isNotEmpty) {
      body['userCouponId'] = userCouponId;
    }
    final response = await _postWithFallback(
      path: '/api/customer/orders?customerUserId=$customerUserId',
      body: body,
    );
    if (kDebugMode) {
      debugPrint(
        '[API DEBUG] CustomerOrderService POST OK: ${response.statusCode} body=${response.body.length} chars',
      );
    }
    return _decodeJson(response) as Map<String, dynamic>;
  }

  Future<List<ReviewableOrderItemModel>> getPurchasedProducts({
    required String customerUserId,
  }) async {
    final response = await _getWithFallback(
      path:
          '/api/customer/purchased-products?customerUserId=$customerUserId',
    );
    final data = _decodeJson(response);
    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (item) =>
                ReviewableOrderItemModel.fromJson(item.cast<String, dynamic>()),
          )
          .toList();
    }
    return [];
  }

  Future<List<ReviewableOrderItemModel>> getReviewableProducts({
    required String customerUserId,
    required String orderId,
  }) async {
    final response = await _getWithFallback(
      path:
          '/api/customer/orders/$orderId/review-products?customerUserId=$customerUserId',
    );
    final data = _decodeJson(response);
    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (item) =>
                ReviewableOrderItemModel.fromJson(item.cast<String, dynamic>()),
          )
          .toList();
    }
    return [];
  }

  Future<http.Response> _postWithFallback({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    for (final baseUrl in _baseUrls) {
      try {
        if (kDebugMode) {
          debugPrint('[API DEBUG] CustomerOrderService POST: $baseUrl$path');
        }
        return await http
            .post(
              Uri.parse('$baseUrl$path'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 8));
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('CustomerOrderService POST hata ($baseUrl): $error');
        }
      }
    }
    throw AuthException('Sunucuya bağlanılamadı.');
  }

  Future<http.Response> _getWithFallback({required String path}) async {
    for (final baseUrl in _baseUrls) {
      try {
        if (kDebugMode) {
          debugPrint('[API DEBUG] CustomerOrderService GET: $baseUrl$path');
        }
        return await http
            .get(Uri.parse('$baseUrl$path'))
            .timeout(const Duration(seconds: 8));
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('CustomerOrderService GET hata ($baseUrl): $error');
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
    return response.body.isNotEmpty ? response.body : 'Sipariş oluşturulamadı.';
  }
}
