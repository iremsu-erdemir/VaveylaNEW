import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/models/customer_review_model.dart';
import 'package:http/http.dart' as http;

class CustomerReviewService {
  CustomerReviewService({
    AuthService? authService,
    String? baseUrl,
    List<String>? baseUrls,
  }) : _baseUrls =
           baseUrl != null || (baseUrls != null && baseUrls.isNotEmpty)
               ? AuthService(baseUrl: baseUrl, baseUrls: baseUrls).baseUrls
               : (authService ?? AuthService()).baseUrls;

  final List<String> _baseUrls;

  Future<PagedCustomerReviews> getReviews({
    required String targetType,
    required String targetId,
    String? restaurantId,
    int page = 1,
    int pageSize = 10,
  }) async {
    final restaurantParam = (restaurantId != null && restaurantId.isNotEmpty)
        ? '&restaurantId=$restaurantId'
        : '';
    final response = await _getWithFallback(
      path:
          '/api/customer/reviews?targetType=$targetType&targetId=$targetId$restaurantParam&page=$page&pageSize=$pageSize',
    );
    final data = _decodeJson(response);
    if (data is! Map<String, dynamic>) {
      return const PagedCustomerReviews(items: [], totalCount: 0, page: 1, pageSize: 10);
    }
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((x) => CustomerReviewModel.fromJson(x.cast<String, dynamic>()))
              .toList()
        : <CustomerReviewModel>[];
    return PagedCustomerReviews(
      items: items,
      totalCount: _parseInt(data['totalCount']),
      page: _parseInt(data['page'], fallback: page),
      pageSize: _parseInt(data['pageSize'], fallback: pageSize),
    );
  }

  Future<void> createReview({
    required String customerUserId,
    required String restaurantId,
    required String targetType,
    required String targetId,
    required int rating,
    required String comment,
    required String customerName,
  }) async {
    await _postWithFallback(
      path: '/api/customer/reviews?customerUserId=$customerUserId',
      body: {
        'restaurantId': restaurantId,
        'targetType': targetType,
        'targetId': targetId,
        'rating': rating,
        'comment': comment,
        'customerName': customerName,
      },
    );
  }

  Future<void> updateReview({
    required String customerUserId,
    required String reviewId,
    required int rating,
    required String comment,
  }) async {
    await _putWithFallback(
      path: '/api/customer/reviews/$reviewId?customerUserId=$customerUserId',
      body: {'rating': rating, 'comment': comment},
    );
  }

  Future<void> deleteReview({
    required String customerUserId,
    required String reviewId,
  }) async {
    await _deleteWithFallback(
      path: '/api/customer/reviews/$reviewId?customerUserId=$customerUserId',
    );
  }

  Future<void> reportReview({
    required String customerUserId,
    required String reviewId,
    required String reason,
  }) async {
    await _postWithFallback(
      path: '/api/customer/reviews/$reviewId/report?customerUserId=$customerUserId',
      body: {'reason': reason},
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
          debugPrint('CustomerReviewService GET hata ($baseUrl): $error');
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
          debugPrint('CustomerReviewService POST hata ($baseUrl): $error');
        }
      }
    }
    throw AuthException('Sunucuya bağlanılamadı.');
  }

  Future<http.Response> _putWithFallback({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    for (final baseUrl in _baseUrls) {
      try {
        return await http
            .put(
              Uri.parse('$baseUrl$path'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 8));
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('CustomerReviewService PUT hata ($baseUrl): $error');
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
          debugPrint('CustomerReviewService DELETE hata ($baseUrl): $error');
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

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class PagedCustomerReviews {
  const PagedCustomerReviews({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  final List<CustomerReviewModel> items;
  final int totalCount;
  final int page;
  final int pageSize;
}
