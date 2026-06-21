import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/product_model.dart';

class CartItemModel {
  final String? cartItemId;
  final ProductModel product;
  int quantity;
  final double? originalLinePrice;
  final double? discountedLinePrice;

  CartItemModel({
    this.cartItemId,
    required this.product,
    required this.quantity,
    this.originalLinePrice,
    this.discountedLinePrice,
  });

  double get totalPrice =>
      discountedLinePrice ?? (product.price * quantity);

  double get lineOriginalPrice =>
      originalLinePrice ?? (product.price * quantity);

  bool get hasDiscount =>
      discountedLinePrice != null &&
      originalLinePrice != null &&
      (originalLinePrice! - discountedLinePrice!).abs() > 0.001;

  CartItemModel copyWith({
    String? cartItemId,
    ProductModel? product,
    int? quantity,
    double? originalLinePrice,
    double? discountedLinePrice,
  }) {
    return CartItemModel(
      cartItemId: cartItemId ?? this.cartItemId,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      originalLinePrice: originalLinePrice ?? this.originalLinePrice,
      discountedLinePrice: discountedLinePrice ?? this.discountedLinePrice,
    );
  }
}
