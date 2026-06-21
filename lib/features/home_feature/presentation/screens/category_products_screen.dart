import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/general_app_bar.dart';
import '../../data/services/products_service.dart';
import '../bloc/category_products_cubit.dart';
import 'product_details_screen.dart';
import '../widgets/product_card.dart';

class CategoryProductsScreen extends StatelessWidget {
  static const _closedRestaurantMessage =
      'Bu pastane şu anda hizmet verememektedir.';

  const CategoryProductsScreen({super.key, required this.categoryName});

  final String categoryName;

  @override
  Widget build(BuildContext context) {
    final appColors = context.theme.appColors;
    return BlocProvider(
      create:
          (_) =>
              CategoryProductsCubit(ProductsService())
                ..loadProducts(categoryName),
      child: AppScaffold(
        appBar: GeneralAppBar(title: categoryName),
        body: BlocBuilder<CategoryProductsCubit, CategoryProductsState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            final products = state.products;
            if (products.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: appColors.gray4,
                    ),
                    const SizedBox(height: Dimens.largePadding),
                    Text(
                      'Bu kategoride henüz ürün yok',
                      style: context.theme.appTypography.bodyLarge.copyWith(
                        color: appColors.gray4,
                      ),
                    ),
                  ],
                ),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(Dimens.largePadding),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: Dimens.largePadding,
                crossAxisSpacing: Dimens.largePadding,
                childAspectRatio: 0.65,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                final isRestaurantOpen = product.restaurantIsOpen;
                return InkWell(
                  onTap: () {
                    if (!isRestaurantOpen) {
                      context.showErrorMessage(_closedRestaurantMessage);
                      return;
                    }
                    appPush(context, ProductDetailsScreen(product: product));
                  },
                  borderRadius: BorderRadius.circular(Dimens.corners),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ProductCard(product: product),
                      if (!isRestaurantOpen)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                color: Colors.grey.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: Dimens.padding,
                        right: Dimens.padding,
                        child: Visibility(
                          visible: !isRestaurantOpen,
                          child: Container(
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
                              style: context.theme.appTypography.labelSmall
                                  .copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
