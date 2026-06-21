import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/formatters.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_divider.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/modern_order_card.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/bloc/cart_cubit.dart';

import '../../../../core/theme/dimens.dart';

class OrdersListForCheckout extends StatelessWidget {
  const OrdersListForCheckout({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) {
        if (state is! CartLoaded || state.items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(Dimens.largePadding),
            child: Text(
              'Sepetiniz boş',
              style: context.theme.appTypography.bodyMedium.copyWith(
                color: context.theme.appColors.gray4,
              ),
            ),
          );
        }
        return ListView.separated(
          itemCount: state.items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final item = state.items[index];
            return CompactOrderCard(
              productName: item.product.name,
              price: item.totalPrice.round(),
              imageUrl: item.product.imageUrl,
              quantity: item.quantity,
              onTap: () {},
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: Dimens.padding),
        );
      },
    );
  }
}
