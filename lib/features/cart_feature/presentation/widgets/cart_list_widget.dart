import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/formatters.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_rating_summary.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_divider.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_svg_viewer.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/cart_item_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/product_model.dart'
    show ProductSaleUnit;
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/bloc/cart_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/widgets/product_image_widget.dart';

import '../../../../core/gen/assets.gen.dart';
import 'cart_actions.dart';

class CartListWidget extends StatelessWidget {
  const CartListWidget({super.key, required this.items});

  final List<CartItemModel> items;

  static String _quantityLabel(CartItemModel item) {
    if (item.product.saleUnit == ProductSaleUnit.perSlice) {
      return '${item.quantity} dilim';
    }
    return '${item.product.weight} kg';
  }

  @override
  Widget build(BuildContext context) {
    final appTypography = context.theme.appTypography;
    final appColors = context.theme.appColors;
    return ListView.separated(
      itemCount: items.length,
      itemBuilder: (final context, final index) {
        return Dismissible(
          key: Key(items[index].cartItemId ?? '${items[index].product.id}-$index'),
          background: Container(
            color: appColors.error,
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 20),
            child: AppSvgViewer(
              Assets.icons.trash,
              width: 28,
              height: 28,
              color: appColors.white,
            ),
          ),
          direction: DismissDirection.endToStart,
          onDismissed: (final direction) {
            final cartItemId = items[index].cartItemId;
            if (cartItemId != null && cartItemId.isNotEmpty) {
              context.read<CartCubit>().removeItem(cartItemId);
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Dimens.largePadding,
              vertical: Dimens.veryLargePadding,
            ),
            child: Row(
              spacing: Dimens.largePadding,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.shrink(),
                SizedBox(
                  height: 95,
                  width: 95,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Dimens.corners),
                    child: buildProductImage(
                      items[index].product.imageUrl,
                      95,
                      95,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    spacing: Dimens.largePadding,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            items[index].product.name,
                            style: appTypography.bodyLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                          AppRatingSummary(
                            rating: items[index].product.rate,
                            reviewCount: items[index].product.reviewCount,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              spacing: Dimens.largePadding,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _quantityLabel(items[index]),
                                  style: appTypography.labelMedium.copyWith(
                                    color: appColors.gray4,
                                  ),
                                ),
                                if (items[index].hasDiscount) ...[
                                  Text(
                                    formatPrice(items[index].lineOriginalPrice),
                                    style: appTypography.bodyMedium.copyWith(
                                      decoration: TextDecoration.lineThrough,
                                      color: appColors.gray4,
                                    ),
                                  ),
                                  Text(
                                    formatPrice(items[index].totalPrice),
                                    style: appTypography.bodyLarge.copyWith(
                                      color: appColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ] else
                                  Text(
                                    formatPrice(items[index].totalPrice),
                                    style: appTypography.bodyLarge,
                                  ),
                              ],
                            ),
                          ),
                          CartActions(item: items[index]),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (final context, final index) {
        return AppDivider();
      },
    );
  }
}
