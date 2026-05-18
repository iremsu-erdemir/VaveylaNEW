import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/calculate_cart_response.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/cart_item_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/product_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/services/customer_cart_service.dart';

part 'cart_state.dart';

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(CartInitial());
  static const String differentRestaurantErrorMessage =
      'Aynı anda farklı pastanelerden ürün ekleyemezsiniz. Lütfen önce sepetinizi temizleyin.';

  final CustomerCartService _cartService = CustomerCartService();
  final List<CartItemModel> _items = [];
  String? _selectedUserCouponId;
  Future<void>? _loadCartMutex;

  String get _customerUserId => AppSession.userId;

  String? get selectedUserCouponId => _selectedUserCouponId;

  void selectCoupon(String? userCouponId) {
    _selectedUserCouponId = userCouponId;
    loadCart();
  }

  Future<void> loadCart() async {
    final previous = _loadCartMutex;
    final done = Completer<void>();
    _loadCartMutex = done.future;
    try {
      if (previous != null) await previous;
      await _loadCartBody();
    } finally {
      done.complete();
    }
  }

  Future<void> _loadCartBody() async {
    final customerUserId = _customerUserId;
    if (customerUserId.isEmpty) {
      _items.clear();
      emit(_buildLoadedState());
      return;
    }
    try {
      final items = await _cartService.getCart(customerUserId: customerUserId);
      _items
        ..clear()
        ..addAll(items);

      try {
        final calc = await _cartService.calculateCart(
          customerUserId: customerUserId,
          userCouponId: _selectedUserCouponId,
        );
        // Restoran indirimi ve kupon hesaplaması: totals varsa kullan (items boş/uyuşmaz olsa bile)
        if (kDebugMode && calc != null) {
          debugPrint('[RESTAURANT_DISCOUNT DEBUG] CartCubit calc: hasRestaurantDiscount=${calc.hasRestaurantDiscount} '
              'restaurantDiscountAmount=${calc.restaurantDiscountAmount} totalPrice=${calc.totalPrice} '
              'finalPrice=${calc.finalPrice} totalDiscount=${calc.totalDiscount} useCalc=${calc.totalPrice > 0}');
        }
        if (calc != null && calc.totalPrice > 0) {
          final calcByProduct = <String, CalculateCartItemResponse>{};
          for (final c in calc.items) {
            final id = c.productId.toLowerCase();
            if (id.isNotEmpty) calcByProduct[id] = c;
          }
          final merged = _items.map((item) {
            final calcItem = calcByProduct[item.product.id.toLowerCase()];
            if (calcItem != null) {
              return item.copyWith(
                originalLinePrice: calcItem.originalPrice,
                discountedLinePrice: calcItem.discountedPrice,
              );
            }
            return item;
          }).toList();
          _items
            ..clear()
            ..addAll(merged);
          if (kDebugMode) {
            debugPrint('[RESTAURANT_DISCOUNT DEBUG] CartCubit emit CartLoaded: '
                'hasRestaurantDiscount=${calc.hasRestaurantDiscount} '
                'restaurantDiscountAmount=${calc.restaurantDiscountAmount} '
                'hasRestaurantDiscountSkippedForCoupon=${calc.hasRestaurantDiscountSkippedForCoupon} '
                'finalPrice=${calc.finalPrice}');
          }
          emit(CartLoaded(
            items: List.from(_items),
            totalAmount: calc.totalPrice,
            totalDiscount: calc.totalDiscount,
            finalPrice: calc.finalPrice,
            totalItems: _items.fold(0, (s, i) => s + i.quantity),
            hasRestaurantDiscount: calc.hasRestaurantDiscount,
            restaurantDiscountAmount: calc.restaurantDiscountAmount,
            canUseCoupon: calc.canUseCoupon,
            couponDiscountAmount: calc.couponDiscountAmount,
            selectedUserCouponId: _selectedUserCouponId,
            hasRestaurantDiscountSkippedForCoupon: calc.hasRestaurantDiscountSkippedForCoupon,
          ));
          return;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[RESTAURANT_DISCOUNT DEBUG] CartCubit calculateCart failed - $e');
        }
      }

      if (kDebugMode) {
        debugPrint('[RESTAURANT_DISCOUNT DEBUG] CartCubit fallback: _buildLoadedState (calc null/empty)');
      }
      emit(_buildLoadedState());
    } catch (e) {
      emit(CartError(_friendlyCartError(e)));
    }
  }

  Future<String?> addItem(ProductModel product) async {
    final customerUserId = _customerUserId;
    if (customerUserId.isEmpty) {
      const message = 'Sepete eklemek için giriş yapın.';
      emit(CartError(message));
      return message;
    }

    if (_hasItemsFromDifferentRestaurant(product)) {
      emit(CartError(differentRestaurantErrorMessage));
      return differentRestaurantErrorMessage;
    }

    try {
      final isSlice = product.saleUnit == ProductSaleUnit.perSlice;
      final quantity = isSlice
          ? product.weight.round().clamp(1, 99999)
          : 1;
      final weightKg = isSlice ? 1.0 : product.weight;
      await _cartService.addItem(
        customerUserId: customerUserId,
        productId: product.id,
        quantity: quantity,
        weightKg: weightKg,
      );
      await loadCart();
      return null;
    } catch (e) {
      final message = _friendlyCartError(e);
      emit(CartError(message));
      return message;
    }
  }

  Future<void> removeItem(String cartItemId) async {
    final customerUserId = _customerUserId;
    if (customerUserId.isEmpty) return;
    try {
      await _cartService.removeItem(
        customerUserId: customerUserId,
        cartItemId: cartItemId,
      );
      await loadCart();
    } catch (e) {
      emit(CartError(_friendlyCartError(e)));
    }
  }

  Future<void> updateQuantity(String cartItemId, int quantity) async {
    if (quantity <= 0) {
      await removeItem(cartItemId);
      return;
    }
    final customerUserId = _customerUserId;
    if (customerUserId.isEmpty) return;
    try {
      await _cartService.updateItemQuantity(
        customerUserId: customerUserId,
        cartItemId: cartItemId,
        quantity: quantity,
      );
      await loadCart();
    } catch (e) {
      emit(CartError(e.toString()));
    }
  }

  Future<void> incrementQuantity(String cartItemId) async {
    final index = _items.indexWhere((item) => item.cartItemId == cartItemId);
    if (index >= 0) {
      await updateQuantity(
        cartItemId,
        _items[index].quantity + 1,
      );
    }
  }

  Future<void> decrementQuantity(String cartItemId) async {
    final index = _items.indexWhere((item) => item.cartItemId == cartItemId);
    if (index >= 0) {
      final newQuantity = _items[index].quantity - 1;
      if (newQuantity <= 0) {
        await removeItem(cartItemId);
      } else {
        await updateQuantity(cartItemId, newQuantity);
      }
    }
  }

  Future<void> clearCart() async {
    final customerUserId = _customerUserId;
    if (customerUserId.isEmpty) {
      _items.clear();
      emit(_buildLoadedState());
      return;
    }
    try {
      await _cartService.clearCart(customerUserId: customerUserId);
      _items.clear();
      emit(_buildLoadedState());
    } catch (e) {
      emit(CartError(_friendlyCartError(e)));
    }
  }

  CartLoaded _buildLoadedState() {
    final totalAmount = _items.fold(0.0, (sum, item) => sum + item.totalPrice);
    final totalItems = _items.fold(0, (sum, item) => sum + item.quantity);

    return CartLoaded(
      items: List.from(_items),
      totalAmount: totalAmount,
      totalDiscount: 0,
      finalPrice: totalAmount,
      totalItems: totalItems,
      selectedUserCouponId: _selectedUserCouponId,
    );
  }

  bool isProductInCart(String productId) {
    return _items.any((item) => item.product.id == productId);
  }

  bool _hasItemsFromDifferentRestaurant(ProductModel product) {
    final targetRestaurantId = product.restaurantId?.trim();
    if (targetRestaurantId == null || targetRestaurantId.isEmpty) {
      return false;
    }

    for (final item in _items) {
      final cartRestaurantId = item.product.restaurantId?.trim();
      if (cartRestaurantId == null || cartRestaurantId.isEmpty) {
        continue;
      }
      if (cartRestaurantId.toLowerCase() != targetRestaurantId.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  /// Uzun SQL / stack trace metinlerini kullanıcıya göstermeyiz.
  static String _friendlyCartError(Object error) {
    var s = error.toString().trim();
    if (s.startsWith('Exception: ')) {
      s = s.substring(11).trim();
    }
    final lower = s.toLowerCase();
    if (lower.contains('invalid column name') && lower.contains('saleunit')) {
      return 'Veritabanı güncel değil (SaleUnit kolonu yok). Sunucuda migration uygulayın: dotnet ef database update';
    }
    if (lower.contains('sqlexception') ||
        lower.contains('microsoft.data.sqlclient')) {
      return 'Sunucu veya veritabanı hatası. Bağlantıyı kontrol edip tekrar deneyin.';
    }
    if (s.length > 200) {
      return 'Bir hata oluştu. Tekrar deneyin veya daha sonra deneyin.';
    }
    return s;
  }
}
