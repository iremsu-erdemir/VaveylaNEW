import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/home_products_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/restaurant_products_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/widgets/product_image_widget.dart';

class RestaurantsList extends StatelessWidget {
  const RestaurantsList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeProductsCubit, HomeProductsState>(
      builder: (context, state) {
        final allProducts = [
          ...state.allProducts,
        ];
        final byRestaurant = <String, (String name, String type, String? photoPath, bool isOpen)>{};
        for (final product in allProducts) {
          final restaurantId = product.restaurantId;
          if (restaurantId == null || restaurantId.isEmpty) continue;
          byRestaurant[restaurantId] = (
            product.restaurantName ?? 'Pastane',
            product.restaurantType ?? 'Kategori',
            product.restaurantPhotoPath,
            product.restaurantIsOpen,
          );
        }
        final restaurants = byRestaurant.entries.toList();
        if (restaurants.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Dimens.largePadding),
            itemCount: restaurants.length,
            separatorBuilder: (_, __) => const SizedBox(width: Dimens.padding),
            itemBuilder: (context, index) {
              final item = restaurants[index];
              final restaurantId = item.key;
              final (name, type, photoPath, isOpen) = item.value;
              return InkWell(
                onTap: () {
                  if (!isOpen) {
                    context.showErrorMessage(
                      'Bu pastane şu anda hizmet verememektedir.',
                    );
                    return;
                  }
                  appPush(
                    context,
                    RestaurantProductsScreen(
                      restaurantId: restaurantId,
                      restaurantName: name,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(Dimens.corners),
                child: SizedBox(
                  width: 216,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Dimens.corners),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: buildProductImage(photoPath ?? '', 216, 150),
                        ),
                        if (!isOpen)
                          Positioned.fill(
                            child: Container(
                              color: Colors.grey.withValues(alpha: 0.45),
                            ),
                          ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.08),
                                  Colors.black.withValues(alpha: 0.55),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: Dimens.padding,
                          right: Dimens.padding,
                          child: Visibility(
                            visible: !isOpen,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Dimens.smallPadding,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(Dimens.smallCorners),
                              ),
                              child: Text(
                                'Kapalı',
                                style: context.theme.appTypography.labelSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: Dimens.padding,
                          right: Dimens.padding,
                          bottom: Dimens.padding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: context.theme.appTypography.titleSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                type,
                                style: context.theme.appTypography.bodySmall.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Ürünleri gör',
                                style: context.theme.appTypography.labelSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
