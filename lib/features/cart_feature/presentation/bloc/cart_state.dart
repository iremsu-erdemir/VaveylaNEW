part of 'cart_cubit.dart';

@immutable
abstract class CartState {}

class CartInitial extends CartState {}

class CartLoaded extends CartState {
  final List<CartItemModel> items;
  final double totalAmount;
  final double totalDiscount;
  final double finalPrice;
  final int totalItems;
  final bool hasRestaurantDiscount;
  final double restaurantDiscountAmount;
  final bool canUseCoupon;
  final double couponDiscountAmount;
  final String? selectedUserCouponId;
  final bool hasRestaurantDiscountSkippedForCoupon;

  CartLoaded({
    required this.items,
    required this.totalAmount,
    this.totalDiscount = 0,
    double? finalPrice,
    required this.totalItems,
    this.hasRestaurantDiscount = false,
    this.restaurantDiscountAmount = 0,
    this.canUseCoupon = true,
    this.couponDiscountAmount = 0,
    this.selectedUserCouponId,
    this.hasRestaurantDiscountSkippedForCoupon = false,
  }) : finalPrice = finalPrice ?? totalAmount;

  double get totalSavings => totalDiscount;

  CartLoaded copyWith({
    List<CartItemModel>? items,
    double? totalAmount,
    double? totalDiscount,
    double? finalPrice,
    int? totalItems,
    bool? hasRestaurantDiscount,
    double? restaurantDiscountAmount,
    bool? canUseCoupon,
    double? couponDiscountAmount,
    String? selectedUserCouponId,
    bool? hasRestaurantDiscountSkippedForCoupon,
  }) {
    return CartLoaded(
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      totalDiscount: totalDiscount ?? this.totalDiscount,
      finalPrice: finalPrice ?? this.finalPrice,
      totalItems: totalItems ?? this.totalItems,
      hasRestaurantDiscount: hasRestaurantDiscount ?? this.hasRestaurantDiscount,
      restaurantDiscountAmount: restaurantDiscountAmount ?? this.restaurantDiscountAmount,
      canUseCoupon: canUseCoupon ?? this.canUseCoupon,
      couponDiscountAmount: couponDiscountAmount ?? this.couponDiscountAmount,
      selectedUserCouponId: selectedUserCouponId ?? this.selectedUserCouponId,
      hasRestaurantDiscountSkippedForCoupon: hasRestaurantDiscountSkippedForCoupon ?? this.hasRestaurantDiscountSkippedForCoupon,
    );
  }
}

class CartError extends CartState {
  final String message;

  CartError(this.message);
}
