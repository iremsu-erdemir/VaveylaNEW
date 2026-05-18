import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/image_moderation_service.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/models/courier_account_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/models/menu_item_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/models/owner_chat_models.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/models/order_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/models/product_stats_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/presentation/bloc/restaurant_settings_cubit.dart';

class RestaurantOwnerService {
  RestaurantOwnerService({
    required this.authService,
    String? baseUrl,
    List<String>? baseUrls,
  }) : _baseUrls =
           baseUrl != null || (baseUrls != null && baseUrls.isNotEmpty)
               ? AuthService(baseUrl: baseUrl, baseUrls: baseUrls).baseUrls
               : authService.baseUrls;

  final AuthService authService;
  final List<String> _baseUrls;
  late final ImageModerationService _imageModerationService =
      ImageModerationService(authService: AuthService(baseUrls: _baseUrls));

  Future<List<MenuItemModel>> getMenu({required String ownerUserId}) async {
    final response = await _getWithFallback(
      path: '/api/owner/menu?ownerUserId=$ownerUserId',
    );
    final data = _decodeJson(response);
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => MenuItemModel.fromJson(item.cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  Future<MenuItemModel> createMenuItem({
    required String ownerUserId,
    required String name,
    required int price,
    required String imagePath,
    String? categoryName,
    bool isAvailable = true,
    bool isFeatured = false,
    int saleUnit = 0,
  }) async {
    final response = await _postWithFallback(
      path: '/api/owner/menu?ownerUserId=$ownerUserId',
      body: {
        'name': name,
        'price': price,
        'imagePath': imagePath,
        'categoryName': categoryName,
        'isAvailable': isAvailable,
        'isFeatured': isFeatured,
        'saleUnit': saleUnit == 1 ? 1 : 0,
      },
    );
    final data = _decodeJson(response) as Map<String, dynamic>;
    return MenuItemModel.fromJson(data);
  }

  Future<MenuItemModel> updateMenuItem({
    required String ownerUserId,
    required String id,
    String? name,
    int? price,
    String? imagePath,
    String? categoryName,
    bool? isAvailable,
    bool? isFeatured,
    int? saleUnit,
  }) async {
    final response = await _putWithFallback(
      path: '/api/owner/menu/$id?ownerUserId=$ownerUserId',
      body: {
        'name': name,
        'price': price,
        'imagePath': imagePath,
        'categoryName': categoryName,
        'isAvailable': isAvailable,
        'isFeatured': isFeatured,
        if (saleUnit != null) 'saleUnit': saleUnit == 1 ? 1 : 0,
      },
    );
    final data = _decodeJson(response) as Map<String, dynamic>;
    return MenuItemModel.fromJson(data);
  }

  Future<void> deleteMenuItem({
    required String ownerUserId,
    required String id,
  }) async {
    await _deleteWithFallback(
      path: '/api/owner/menu/$id?ownerUserId=$ownerUserId',
    );
  }

  Future<List<RestaurantOrderModel>> getOrders({
    required String ownerUserId,
  }) async {
    final response = await _getWithFallback(
      path: '/api/owner/orders?ownerUserId=$ownerUserId',
    );
    final data = _decodeJson(response);
    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (item) =>
                RestaurantOrderModel.fromJson(item.cast<String, dynamic>()),
          )
          .toList();
    }
    return [];
  }

  Future<ProductStats> getTopProducts({
    required String restaurantId,
    String? period,
  }) async {
    final query =
        (period == null || period.trim().isEmpty || period == 'all')
            ? ''
            : '?period=${Uri.encodeQueryComponent(period.trim())}';

    final response = await _getWithFallback(
      path: '/api/restaurant/$restaurantId/top-products$query',
    );

    final data = _decodeJson(response) as Map<String, dynamic>;
    return ProductStats.fromJson(data);
  }

  Future<RestaurantOrderModel> createOrder({
    required String ownerUserId,
    required String items,
    required int total,
    String? imagePath,
    int? preparationMinutes,
    String? status,
    DateTime? createdAt,
  }) async {
    final response = await _postWithFallback(
      path: '/api/owner/orders?ownerUserId=$ownerUserId',
      body: {
        'items': items,
        'total': total,
        'imagePath': imagePath,
        'preparationMinutes': preparationMinutes,
        'status': status,
        'createdAtUtc': createdAt?.toUtc().toIso8601String(),
      },
    );
    final data = _decodeJson(response) as Map<String, dynamic>;
    return RestaurantOrderModel.fromJson(data);
  }

  Future<List<CourierAccountModel>> getCourierAccounts({
    required String ownerUserId,
  }) async {
    final response = await _getWithFallback(
      path: '/api/owner/couriers?ownerUserId=$ownerUserId',
    );
    final data = _decodeJson(response);
    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (item) =>
                CourierAccountModel.fromJson(item.cast<String, dynamic>()),
          )
          .toList();
    }
    return [];
  }

  Future<RestaurantOrderModel> assignCourierToOrder({
    required String ownerUserId,
    required String orderId,
    required String courierUserId,
  }) async {
    final response = await _putWithFallback(
      path:
          '/api/owner/orders/$orderId/assign-courier?ownerUserId=$ownerUserId',
      body: {'courierUserId': courierUserId},
    );
    final data = _decodeJson(response) as Map<String, dynamic>;
    return RestaurantOrderModel.fromJson(data);
  }

  Future<RestaurantOrderModel> updateOrderStatus({
    required String ownerUserId,
    required String id,
    required RestaurantOrderStatus status,
    String? rejectionReason,
  }) async {
    final body = <String, dynamic>{
      'status': status.name,
      if (rejectionReason != null && rejectionReason.trim().isNotEmpty)
        'rejectionReason': rejectionReason.trim(),
    };

    final response = await _putWithFallback(
      path: '/api/owner/orders/$id/status?ownerUserId=$ownerUserId',
      body: body,
    );
    final data = _decodeJson(response) as Map<String, dynamic>;
    return RestaurantOrderModel.fromJson(data);
  }

  Future<RestaurantSettingsState> getSettings({
    required String ownerUserId,
  }) async {
    final response = await _getWithFallback(
      path: '/api/owner/settings?ownerUserId=$ownerUserId',
    );
    final data = _decodeJson(response) as Map<String, dynamic>;
    return RestaurantSettingsState.fromJson(data);
  }

  Future<RestaurantSettingsState> updateSettings({
    required String ownerUserId,
    String? restaurantName,
    String? restaurantType,
    String? address,
    double? latitude,
    double? longitude,
    String? phone,
    String? workingHours,
    bool? orderNotifications,
    bool? isOpen,
    String? restaurantPhotoPath,
    double? restaurantDiscountPercent,
  }) async {
    final body = <String, dynamic>{
      'restaurantName': restaurantName,
      'restaurantType': restaurantType,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'workingHours': workingHours,
      'orderNotifications': orderNotifications,
      'isOpen': isOpen,
      'restaurantPhotoPath': restaurantPhotoPath,
    };
    if (restaurantDiscountPercent != null) {
      body['restaurantDiscountPercent'] = restaurantDiscountPercent;
    }
    final response = await _putWithFallback(
      path: '/api/owner/settings?ownerUserId=$ownerUserId',
      body: body,
    );
    final data = _decodeJson(response) as Map<String, dynamic>;
    return RestaurantSettingsState.fromJson(data);
  }

  /// Sadece indirim yüzdesini günceller - doğrudan veritabanına kaydeder.
  Future<RestaurantSettingsState> updateDiscountPercent({
    required String ownerUserId,
    required double? restaurantDiscountPercent,
  }) async {
    final body = <String, dynamic>{
      'restaurantDiscountPercent': restaurantDiscountPercent,
    };
    if (kDebugMode) {
      debugPrint(
        '[API DEBUG] updateDiscountPercent: ownerUserId=$ownerUserId percent=$restaurantDiscountPercent body=$body',
      );
    }
    final response = await _putWithFallback(
      path: '/api/owner/settings/discount?ownerUserId=$ownerUserId',
      body: body,
    );
    if (kDebugMode) {
      debugPrint(
        '[API DEBUG] updateDiscountPercent response: ${response.statusCode} body=${response.body}',
      );
    }
    final data = _decodeJson(response) as Map<String, dynamic>;
    if (kDebugMode) {
      debugPrint(
        '[API DEBUG] updateDiscountPercent parsed: restaurantDiscountPercent=${data['restaurantDiscountPercent']} restaurantDiscountApproved=${data['restaurantDiscountApproved']}',
      );
    }
    return RestaurantSettingsState.fromJson(data);
  }

  /// Onaylı restoran indirimini pasifleştir veya tekrar aktifleştir.
  Future<RestaurantSettingsState> toggleDiscountActive({
    required String ownerUserId,
    required bool isActive,
  }) async {
    final response = await _putWithFallback(
      path: '/api/owner/settings/discount/toggle?ownerUserId=$ownerUserId',
      body: {'isActive': isActive},
    );
    final data = _decodeJson(response) as Map<String, dynamic>;
    return RestaurantSettingsState.fromJson(data);
  }

  Future<void> updateReviewReply({
    required String ownerUserId,
    required String reviewId,
    required String ownerReply,
  }) async {
    await _putWithFallback(
      path: '/api/owner/reviews/$reviewId/reply?ownerUserId=$ownerUserId',
      body: {'ownerReply': ownerReply},
    );
  }

  Future<List<OwnerChatConversationModel>> getChatConversations({
    required String ownerUserId,
  }) async {
    final response = await _getWithFallback(
      path: '/api/owner/chats/conversations?ownerUserId=$ownerUserId',
    );
    final data = _decodeJson(response);
    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (item) => OwnerChatConversationModel.fromJson(
              item.cast<String, dynamic>(),
            ),
          )
          .toList();
    }
    return [];
  }

  Future<void> deleteChatConversation({
    required String ownerUserId,
    required String customerUserId,
  }) async {
    await _deleteWithFallback(
      path:
          '/api/owner/chats/conversations/$customerUserId?ownerUserId=$ownerUserId',
    );
  }

  Future<List<OwnerChatMessageModel>> getChatMessages({
    required String ownerUserId,
    required String customerUserId,
    int limit = 200,
  }) async {
    final response = await _getWithFallback(
      path:
          '/api/owner/chats/messages?ownerUserId=$ownerUserId&customerUserId=$customerUserId&limit=$limit',
    );
    final data = _decodeJson(response);
    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (item) =>
                OwnerChatMessageModel.fromJson(item.cast<String, dynamic>()),
          )
          .toList();
    }
    return [];
  }

  Future<OwnerChatMessageModel> sendOwnerMessage({
    required String ownerUserId,
    required String customerUserId,
    required String message,
  }) async {
    final response = await _postWithFallback(
      path: '/api/owner/chats/messages?ownerUserId=$ownerUserId',
      body: {'customerUserId': customerUserId, 'message': message},
    );
    final data = _decodeJson(response) as Map<String, dynamic>;
    return OwnerChatMessageModel.fromJson(data);
  }

  Future<void> deleteOwnerMessage({
    required String ownerUserId,
    required String messageId,
  }) async {
    await _deleteWithFallback(
      path: '/api/owner/chats/messages/$messageId?ownerUserId=$ownerUserId',
    );
  }

  Future<String> uploadMenuImage({
    required String ownerUserId,
    required String filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final response = await _multipartWithFallback(
      path: '/api/owner/uploads/menu?ownerUserId=$ownerUserId',
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
    );
    final data = _decodeJson(response) as Map<String, dynamic>;
    return data['url']?.toString() ?? '';
  }

  Future<String> uploadRestaurantPhoto({
    required String ownerUserId,
    required String filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    await _imageModerationService.ensureImageIsAllowed(
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
    );
    final response = await _multipartWithFallback(
      path: '/api/owner/uploads/restaurant-photo?ownerUserId=$ownerUserId',
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
    );
    final data = _decodeJson(response) as Map<String, dynamic>;
    return data['url']?.toString() ?? '';
  }

  Future<http.Response> _getWithFallback({required String path}) async {
    for (final baseUrl in _baseUrls) {
      try {
        return await http
            .get(Uri.parse('$baseUrl$path'))
            .timeout(const Duration(seconds: 8));
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('OwnerService GET hata ($baseUrl): $error');
        }
      }
    }
    throw AuthException(
      'Sunucuya bağlanılamadı. Lütfen bağlantınızı kontrol edin.',
    );
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
          debugPrint('OwnerService POST hata ($baseUrl): $error');
        }
      }
    }
    throw AuthException(
      'Sunucuya bağlanılamadı. Lütfen bağlantınızı kontrol edin.',
    );
  }

  Future<http.Response> _putWithFallback({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    for (final baseUrl in _baseUrls) {
      final url = '$baseUrl$path';
      if (kDebugMode) debugPrint('[API DEBUG] Owner PUT: $url body=$body');
      try {
        final res = await http
            .put(
              Uri.parse(url),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 8));
        if (kDebugMode)
          debugPrint('[API DEBUG] Owner PUT OK: ${res.statusCode}');
        return res;
      } on Exception catch (error, stack) {
        if (kDebugMode) {
          debugPrint('[API DEBUG] Owner PUT HATA: $url | $error');
          debugPrint('[API DEBUG] Stack: $stack');
        }
      }
    }
    throw AuthException(
      'Sunucuya bağlanılamadı. Lütfen bağlantınızı kontrol edin.',
    );
  }

  Future<http.Response> _deleteWithFallback({required String path}) async {
    for (final baseUrl in _baseUrls) {
      try {
        return await http
            .delete(Uri.parse('$baseUrl$path'))
            .timeout(const Duration(seconds: 8));
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('OwnerService DELETE hata ($baseUrl): $error');
        }
      }
    }
    throw AuthException(
      'Sunucuya bağlanılamadı. Lütfen bağlantınızı kontrol edin.',
    );
  }

  Future<http.Response> _multipartWithFallback({
    required String path,
    required String filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    for (final baseUrl in _baseUrls) {
      try {
        final uri = Uri.parse('$baseUrl$path');
        final request = http.MultipartRequest('POST', uri);
        if (kIsWeb) {
          final bytes = fileBytes ?? await XFile(filePath).readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: fileName ?? 'upload.jpg',
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath('file', filePath),
          );
        }
        final response = await request.send();
        final body = await response.stream.bytesToString();
        final wrapped = http.Response(body, response.statusCode);
        if (wrapped.statusCode >= 200 && wrapped.statusCode < 300) {
          return wrapped;
        }
        if (kDebugMode) {
          debugPrint(
            'OwnerService UPLOAD cevap hata ($baseUrl): ${wrapped.statusCode} ${wrapped.body}',
          );
        }
      } on Exception catch (error) {
        if (kDebugMode) {
          debugPrint('OwnerService UPLOAD hata ($baseUrl): $error');
        }
      }
    }
    throw AuthException(
      'Sunucuya bağlanılamadı. Lütfen bağlantınızı kontrol edin.',
    );
  }

  dynamic _decodeJson(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      if (response.body.isEmpty) {
        return null;
      }
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

    if (response.body.isNotEmpty) {
      return response.body;
    }
    return 'İşlem sırasında bir hata oluştu.';
  }
}
