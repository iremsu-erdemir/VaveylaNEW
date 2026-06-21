import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/formatters.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_rating_summary.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_title_widget.dart';
import '../../../../core/widgets/general_app_bar.dart';
import '../../../cart_feature/data/models/product_model.dart';
import '../../../cart_feature/presentation/bloc/cart_cubit.dart';
import '../../../restaurant_owner_feature/widgets/product_image_widget.dart';
import '../../data/data_source/local/sample_data.dart';
import '../../data/services/products_service.dart';
import '../bloc/categories_cubit.dart';
import 'category_products_screen.dart';
import 'product_details_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CategoriesCubit(ProductsService())..loadProducts(),
      child: const _CategoriesScreenBody(),
    );
  }
}

class _CategoriesScreenBody extends StatelessWidget {
  static const _closedRestaurantMessage =
      'Bu pastane şu anda hizmet verememektedir.';

  const _CategoriesScreenBody();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: GeneralAppBar(title: 'Kategoriler'),
      padding: EdgeInsets.zero,
      body: BlocBuilder<CategoriesCubit, CategoriesState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final categoryEntries = state.productsByCategory.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));
          if (categoryEntries.isEmpty) {
            return const Center(child: Text('Kategori bulunamadı.'));
          }
          return ListView.separated(
            itemCount: categoryEntries.length,
            shrinkWrap: true,
            itemBuilder: (final context, final catIndex) {
              final categoryTitle = categoryEntries[catIndex].key;
              final products = categoryEntries[catIndex].value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTitleWidget(
                    thumbnailPath:
                        imagesOfCategories[catIndex % imagesOfCategories.length],
                    title: categoryTitle,
                    onPressed: () {
                      appPush(
                        context,
                        CategoryProductsScreen(categoryName: categoryTitle),
                      );
                    },
                  ),
                  SizedBox(
                    height: 264,
                    child: ListView.builder(
                      itemCount: products.length,
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      itemBuilder: (final context, final index) {
                        final product = products[index];
                        final isRestaurantOpen = product.restaurantIsOpen;
                        return Padding(
                          padding: const EdgeInsets.only(
                            left: Dimens.largePadding,
                            top: Dimens.smallPadding,
                            bottom: Dimens.smallPadding,
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
                            borderRadius: BorderRadius.circular(
                              Dimens.largePadding,
                            ),
                            child: Stack(
                              children: [
                                Container(
                                  width: 138,
                                  height: 243,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).scaffoldBackgroundColor,
                                    borderRadius: BorderRadius.circular(
                                      Dimens.largePadding,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.theme.appColors.black
                                            .withValues(alpha: 0.1),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    spacing: Dimens.padding,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        height: 110,
                                        width: 138,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            Dimens.corners,
                                          ),
                                          child: _buildProductImage(
                                            context,
                                            product.imageUrl,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 32,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: Dimens.smallPadding,
                                          ),
                                          child: Center(
                                            child: Text(
                                              product.name,
                                              style: context
                                                  .theme
                                                  .appTypography
                                                  .labelMedium
                                                  .copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: AppRatingSummary(
                                          rating: product.rate,
                                          reviewCount: product.reviewCount,
                                        ),
                                      ),
                                      Text(
                                        formatPrice(product.price),
                                        style: context.theme.appTypography
                                            .labelLarge
                                            .copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      SizedBox(
                                        width: 100,
                                        height: 32,
                                        child: AppButton(
                                          title: 'Sepete ekle',
                                          onPressed: () {
                                            _addToCart(context, product);
                                          },
                                          margin: EdgeInsets.zero,
                                          padding:
                                              WidgetStateProperty.all<EdgeInsets>(
                                            EdgeInsets.symmetric(
                                              horizontal: Dimens.padding,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isRestaurantOpen)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            Dimens.largePadding,
                                          ),
                                          color: Colors.grey.withValues(alpha: 0.35),
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: Dimens.smallPadding,
                                  right: Dimens.smallPadding,
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
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            separatorBuilder: (final context, final index) {
              return SizedBox(height: Dimens.largePadding);
            },
          );
        },
      ),
    );
  }

  Widget _buildProductImage(BuildContext context, String imageUrl) {
    if (imageUrl.startsWith('http') || imageUrl.startsWith('blob:')) {
      return Image.network(
        imageUrl,
        width: 138,
        height: 110,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholderImage(),
      );
    }
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        width: 138,
        height: 110,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholderImage(),
      );
    }
    return buildProductImage(imageUrl, 138, 110);
  }

  Widget _placeholderImage() {
    return Container(
      width: 138,
      height: 110,
      color: Colors.grey.shade300,
      child: const Icon(Icons.image_not_supported, size: 32),
    );
  }

  Future<void> _addToCart(final BuildContext context, ProductModel product) async {
    if (!product.restaurantIsOpen) {
      context.showErrorMessage(_closedRestaurantMessage);
      return;
    }
    final cartCubit = context.read<CartCubit>();
    final errorMessage = await cartCubit.addItem(product);
    if (!context.mounted) return;
    if (errorMessage == null) {
      context.showSuccessMessage('${product.name} sepete eklendi!');
      return;
    }
    context.showErrorMessage(errorMessage);
  }
}
