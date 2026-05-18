import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/calculate_cart_response.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/cart_item_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/product_model.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/cart_local_cache.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/services/customer_cart_service.dart';

part 'cart_state.dart';

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(CartInitial());
  static const String differentRestaurantErrorMessage =
      'Aynı anda farklı pastanelerden ürün ekleyemezsiniz. Lütfen önce sepetinizi temizleyin.';

  final CustomerCartService _cartService = CustomerCartService();
  final CartLocalCache _cartCache = CartLocalCache();
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
      await _cartCache.saveCart(customerUserId, _items);

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
          var merged = _items.map((item) {
            final calcItem = calcByProduct[item.product.id.toLowerCase()];
            if (calcItem != null) {
              return item.copyWith(
                originalLinePrice: calcItem.originalPrice,
                discountedLinePrice: calcItem.discountedPrice,
              );
            }
            return item;
          }).toList();
          // API satır eşleşmesi yoksa toplam indirimi satırlara orantılı dağıt (100→80 görünümü)
          if (calc.totalDiscount > 0 &&
              merged.every((item) => !item.hasDiscount)) {
            merged = _distributeLineDiscounts(merged, calc.totalDiscount);
          }
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
          final couponRejected = _selectedUserCouponId != null &&
              _selectedUserCouponId!.isNotEmpty &&
              calc.couponDiscountAmount <= 0 &&
              calc.couponRejectReason != null &&
              calc.couponRejectReason!.isNotEmpty;
          if (couponRejected) {
            _selectedUserCouponId = null;
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
            selectedUserCouponId: couponRejected ? null : _selectedUserCouponId,
            hasRestaurantDiscountSkippedForCoupon: calc.hasRestaurantDiscountSkippedForCoupon,
            couponRejectReason: couponRejected ? calc.couponRejectReason : null,
            deliveryFee: calc.deliveryFee,
            minimumOrderAmount: calc.minimumOrderAmount,
            meetsMinimumOrder: calc.meetsMinimumOrder,
            minimumOrderGap: calc.minimumOrderGap,
            isDeliverable: calc.isDeliverable,
            deliveryMessage: calc.deliveryMessage,
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
      if (_items.isNotEmpty) {
        emit(_buildLoadedState().copyWith(
          deliveryMessage: 'Bağlantı zayıf. Son bilinen sepet gösteriliyor.',
        ));
      } else {
        emit(CartError(_friendlyCartError(e)));
      }
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

  /// Sepet indirimini satır fiyatlarına orantılı yansıtır (%20 kupon → 100 TL ürün 80 TL).
  static List<CartItemModel> _distributeLineDiscounts(
    List<CartItemModel> items,
    double totalDiscount,
  ) {
    if (items.isEmpty || totalDiscount <= 0) return items;

    final lines = items.map((item) {
      final original = item.originalLinePrice;
      if (original != null && original > 0) return original;
      return item.product.price * item.quantity;
    }).toList();
    final totalOriginal = lines.fold<double>(0, (sum, v) => sum + v);
    if (totalOriginal <= 0) return items;

    var allocated = 0.0;
    final updated = <CartItemModel>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final lineOriginal = lines[i];
      final isLast = i == items.length - 1;
      final lineDiscount = isLast
          ? totalDiscount - allocated
          : double.parse(
              (totalDiscount * (lineOriginal / totalOriginal)).toStringAsFixed(2),
            );
      allocated += lineDiscount;
      updated.add(
        item.copyWith(
          originalLinePrice: lineOriginal,
          discountedLinePrice: (lineOriginal - lineDiscount).clamp(0.0, double.infinity),
        ),
      );
    }
    return updated;
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
