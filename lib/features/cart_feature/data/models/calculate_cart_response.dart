class CalculateCartResponse {
  final List<CalculateCartItemResponse> items;
  final double totalPrice;
  final double totalDiscount;
  final double finalPrice;
  final double customerPaidAmount;
  final double restaurantEarning;
  final double platformEarning;
  final bool hasRestaurantDiscount;
  final double restaurantDiscountAmount;
  final bool canUseCoupon;
  final double couponDiscountAmount;
  final String? appliedUserCouponId;
  final bool hasRestaurantDiscountSkippedForCoupon;

  CalculateCartResponse({
    required this.items,
    required this.totalPrice,
    required this.totalDiscount,
    required this.finalPrice,
    required this.customerPaidAmount,
    required this.restaurantEarning,
    required this.platformEarning,
    this.hasRestaurantDiscount = false,
    this.restaurantDiscountAmount = 0,
    this.canUseCoupon = true,
    this.couponDiscountAmount = 0,
    this.appliedUserCouponId,
    this.hasRestaurantDiscountSkippedForCoupon = false,
  });

  factory CalculateCartResponse.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'];
    final items = itemsList is List
        ? itemsList
            .whereType<Map>()
            .map(
              (e) => CalculateCartItemResponse.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList()
        : <CalculateCartItemResponse>[];

    return CalculateCartResponse(
      items: items,
      totalPrice: CalculateCartResponse._parseDouble(json['totalPrice']) ?? 0,
      totalDiscount: CalculateCartResponse._parseDouble(json['totalDiscount']) ?? 0,
      finalPrice: CalculateCartResponse._parseDouble(json['finalPrice']) ?? 0,
      customerPaidAmount: CalculateCartResponse._parseDouble(json['customerPaidAmount']) ?? 0,
      restaurantEarning: CalculateCartResponse._parseDouble(json['restaurantEarning']) ?? 0,
      platformEarning: CalculateCartResponse._parseDouble(json['platformEarning']) ?? 0,
      hasRestaurantDiscount: json['hasRestaurantDiscount'] == true,
      restaurantDiscountAmount: CalculateCartResponse._parseDouble(json['restaurantDiscountAmount']) ?? 0,
      canUseCoupon: json['canUseCoupon'] != false,
      couponDiscountAmount: CalculateCartResponse._parseDouble(json['couponDiscountAmount']) ?? 0,
      appliedUserCouponId: json['appliedUserCouponId']?.toString(),
      hasRestaurantDiscountSkippedForCoupon: json['hasRestaurantDiscountSkippedForCoupon'] == true,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class CalculateCartItemResponse {
  final String productId;
  final String productName;
  final int quantity;
  final double originalPrice;
  final double discountedPrice;
  final double itemDiscount;

  CalculateCartItemResponse({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.originalPrice,
    required this.discountedPrice,
    required this.itemDiscount,
  });

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  factory CalculateCartItemResponse.fromJson(Map<String, dynamic> json) {
    return CalculateCartItemResponse(
      productId: json['productId']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      quantity: int.tryParse(json['quantity']?.toString() ?? '') ?? 0,
      originalPrice: _parseDouble(json['originalPrice']) ?? 0,
      discountedPrice: _parseDouble(json['discountedPrice']) ?? 0,
      itemDiscount: _parseDouble(json['itemDiscount']) ?? 0,
    );
  }
}
