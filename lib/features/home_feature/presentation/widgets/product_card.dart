import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/formatters.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_rating_summary.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/product_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/widgets/product_image_widget.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});

  final ProductModel product;

  static const double _cardRadius = 16;
  static const double _imageHeight = 120;
  static const double _titleFontSize = 15;

  Widget _buildProductImage(BuildContext context) {
    final imageUrl = product.imageUrl;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(_cardRadius),
      topRight: const Radius.circular(_cardRadius),
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: _imageHeight,
        width: double.infinity,
        child: Builder(
          builder: (_) {
            if (imageUrl.isEmpty) {
              return Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
              );
            }
            if (imageUrl.startsWith('assets/')) {
              return Image.asset(
                imageUrl,
                fit: BoxFit.cover,
              );
            }
            if (imageUrl.startsWith('blob:') || imageUrl.startsWith('http')) {
              return Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: context.theme.appColors.gray2,
                  child: const Icon(Icons.image_not_supported),
                ),
              );
            }

            // Fallback for custom/local paths.
            return buildProductImage(imageUrl, 400, _imageHeight);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final restaurantName = product.restaurantName?.trim();
    final resolvedRestaurantName =
        (restaurantName == null || restaurantName.isEmpty)
            ? 'Pastane'
            : restaurantName;

    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(_cardRadius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProductImage(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: context.theme.appTypography.titleSmall.copyWith(
                      fontSize: _titleFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.visible,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AppRatingSummary(
                        rating: product.rate,
                        reviewCount: product.reviewCount,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatPrice(product.price),
                            style: context.theme.appTypography.labelLarge
                                .copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                          ),
                          Text(
                            product.saleUnit == ProductSaleUnit.perSlice
                                ? '/ dilim'
                                : '/ kg',
                            style: context.theme.appTypography.labelSmall
                                .copyWith(
                                  color: context.theme.appColors.gray4,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    resolvedRestaurantName,
                    style: context.theme.appTypography.bodySmall.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.theme.appColors.gray4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

