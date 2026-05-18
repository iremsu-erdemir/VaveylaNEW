import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/cart_feature/data/models/cart_item_model.dart';

class CartLocalCache {
  static const _keyPrefix = 'cart_cache_v1_';

  Future<void> saveCart(String userId, List<CartItemModel> items) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final payload = items
        .map(
          (i) => {
            'productId': i.product.id,
            'restaurantId': i.product.restaurantId,
            'name': i.product.name,
            'imageUrl': i.product.imageUrl,
            'unitPrice': i.product.price,
            'weightKg': i.product.weight,
            'quantity': i.quantity,
            'saleUnit': i.product.saleUnit.index,
          },
        )
        .toList();
    await prefs.setString('$_keyPrefix$userId', jsonEncode(payload));
  }

  Future<List<Map<String, dynamic>>> loadCart(String userId) async {
    if (userId.isEmpty) return [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$userId');
    if (raw == null || raw.isEmpty) return [];
    final data = jsonDecode(raw);
    if (data is! List) return [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> clear(String userId) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$userId');
  }
}
