import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_rating_summary.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_title_widget.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/home_products_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/products_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/widgets/product_image_widget.dart';

import '../../../../core/theme/dimens.dart';
import '../screens/product_details_screen.dart';

class ProductsList extends StatelessWidget {
  static const _closedRestaurantMessage =
      'Bu pastane şu anda hizmet verememektedir.';

  const ProductsList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeProductsCubit, HomeProductsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final sections = [
          ('Öne Çıkanlar', 'featured', state.featured),
          ('Yeni Ürünler', 'new', state.newProducts),
          ('Popüler', 'popular', state.popular),
        ];
        return ListView.builder(
          itemCount: sections.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, sectionIndex) {
            final (title, type, products) = sections[sectionIndex];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTitleWidget(
                  title: title,
                  onPressed: () {
                    appPush(
                      context,
                      ProductsScreen(
                        initialType: type,
                        title: title,
                      ),
                    );
                  },
                ),
                SizedBox(
                  height: 100,
                  child: products.isEmpty
                      ? Center(
                          child: Text(
                            'Bu bölümde ürün yok',
                            style: context.theme.appTypography.bodySmall,
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: products.length,
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            final isRestaurantOpen = product.restaurantIsOpen;
                            return Padding(
                              padding: const EdgeInsets.only(
                                left: Dimens.largePadding,
                              ),
                              child: InkWell(
                                onTap: () {
                                  if (!isRestaurantOpen) {
                                    context.showErrorMessage(_closedRestaurantMessage);
                                    return;
                                  }
                                  appPush(
                                    context,
                                    ProductDetailsScreen(product: product),
                                  );
                                },
                                borderRadius: BorderRadius.circular(24),
                                child: SizedBox(
                                  height: 100,
                                  width: 196,
                                  child: Stack(
                                    alignment: Alignment.bottomCenter,
                                    children: [
                                      SizedBox(
                                        height: 100,
                                        width: 196,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(24),
                                          child: _buildProductImage(
                                            context,
                                            product.imageUrl,
                                          ),
                                        ),
                                      ),
                                      if (!isRestaurantOpen)
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(24),
                                              color: Colors.grey.withValues(alpha: 0.35),
                                            ),
                                          ),
                                        ),
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            constraints: const BoxConstraints(
                                              minWidth: 92,
                                              maxWidth: 132,
                                            ),
                                            height: 24,
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: Dimens.largePadding,
                                              vertical: Dimens.padding,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(
                                                Dimens.smallCorners,
                                              ),
                                              color: context
                                                  .theme.scaffoldBackgroundColor,
                                            ),
                                            child: Center(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: AppRatingSummary(
                                                  rating: product.rate,
                                                  reviewCount: product.reviewCount,
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (!isRestaurantOpen)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                left: Dimens.largePadding,
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: Dimens.smallPadding,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.7),
                                                borderRadius: BorderRadius.circular(
                                                  Dimens.smallCorners,
                                                ),
                                              ),
                                              child: Text(
                                                'Kapalı',
                                                style: context
                                                    .theme
                                                    .appTypography
                                                    .labelSmall
                                                    .copyWith(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                          Container(
                                            width: 196,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  context.theme.appColors.black
                                                      .withValues(alpha: 0.4),
                                                  context.theme.appColors.black
                                                      .withValues(alpha: 0.7),
                                                  context.theme.appColors.black
                                                      .withValues(alpha: 0.8),
                                                ],
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                product.name,
                                                style: context
                                                    .theme
                                                    .appTypography
                                                    .titleSmall
                                                    .copyWith(
                                                      color: context
                                                          .theme.appColors.white,
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildProductImage(BuildContext context, String imageUrl) {
    if (imageUrl.startsWith('http') || imageUrl.startsWith('blob:')) {
      return Image.network(
        imageUrl,
        width: 196,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholderImage(),
      );
    }
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        width: 196,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholderImage(),
      );
    }
    return buildProductImage(imageUrl, 196, 100);
  }

  Widget _placeholderImage() {
    return Container(
      width: 196,
      height: 100,
      color: Colors.grey.shade300,
      child: const Icon(Icons.image_not_supported, size: 48),
    );
  }
}
