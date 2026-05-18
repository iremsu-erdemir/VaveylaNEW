import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/formatters.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_button.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/bloc/cart_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/screens/proceed_to_checkout_screen.dart';

import '../../../../core/gen/assets.gen.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/widgets/app_svg_viewer.dart';
import '../../../coupon_feature/presentation/screens/coupon_select_screen.dart';
import '../widgets/cart_list_widget.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appTypography = context.theme.appTypography;
    final appColors = context.theme.appColors;
    return AppScaffold(
      padding: EdgeInsets.zero,
      appBar: GeneralAppBar(title: 'Sepetim', showBackIcon: false),
      body: BlocBuilder<CartCubit, CartState>(
        builder: (context, state) {
          if (state is CartInitial) {
            return Center(child: CircularProgressIndicator());
          } else if (state is CartError) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: Dimens.largePadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 56,
                      color: appColors.gray4,
                    ),
                    SizedBox(height: Dimens.largePadding),
                    Text(
                      'Sepet yüklenemedi',
                      style: appTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: Dimens.padding),
                    Text(
                      state.message,
                      style: appTypography.bodyMedium.copyWith(
                        color: appColors.gray4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: Dimens.extraLargePadding),
                    TextButton(
                      onPressed: () => context.read<CartCubit>().loadCart(),
                      child: const Text('Tekrar dene'),
                    ),
                  ],
                ),
              ),
            );
          } else if (state is CartLoaded) {
            if (state.items.isEmpty) {
              return Center(
                child: Column(
                  spacing: Dimens.largePadding,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppSvgViewer(
                      Assets.icons.shoppingCart,
                      width: 50,
                      color: appColors.gray4,
                    ),
                    Text(
                      'Sepetiniz boş',
                      style: appTypography.bodyLarge.copyWith(
                        color: appColors.gray4,
                      ),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => context.read<CartCubit>().loadCart(),
                    child: CartListWidget(items: state.items),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Dimens.largePadding,
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () async {
                          final result = await Navigator.of(
                            context,
                          ).push<String?>(
                            MaterialPageRoute(
                              builder:
                                  (_) => CouponSelectScreen(
                                    selectedUserCouponId:
                                        state.selectedUserCouponId,
                                  ),
                            ),
                          );
                          if (result != null && context.mounted) {
                            context.read<CartCubit>().selectCoupon(
                              result.isEmpty ? null : result,
                            );
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: Dimens.padding,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.local_offer_outlined,
                                    size: 20,
                                    color: appColors.primary,
                                  ),
                                  SizedBox(width: Dimens.padding),
                                  Text(
                                    'Kupon Seç',
                                    style: appTypography.bodyMedium.copyWith(
                                      color: appColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              if (state.couponDiscountAmount > 0)
                                Icon(
                                  Icons.check_circle,
                                  color: appColors.success,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (state.hasRestaurantDiscountSkippedForCoupon)
                        Padding(
                          padding: EdgeInsets.only(bottom: Dimens.padding),
                          child: Container(
                            padding: EdgeInsets.all(Dimens.padding),
                            decoration: BoxDecoration(
                              color: appColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(
                                Dimens.smallCorners,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: appColors.primary,
                                ),
                                SizedBox(width: Dimens.padding),
                                Expanded(
                                  child: Text(
                                    'Kupon seçtiniz. Restoran indirimi uygulanmayacak, sadece kupon indiriminden yararlanacaksınız.',
                                    style: appTypography.bodySmall.copyWith(
                                      color: appColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (!state.hasRestaurantDiscountSkippedForCoupon &&
                          state.restaurantDiscountAmount > 0)
                        ...[
                          SizedBox(height: Dimens.smallPadding),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Restoran indirimi:',
                                style: appTypography.bodyMedium,
                              ),
                              Text(
                                '-${formatPrice(state.restaurantDiscountAmount)}',
                                style: appTypography.bodyMedium.copyWith(
                                  color: appColors.success,
                                ),
                              ),
                            ],
                          ),
                        ],
                      if (state.couponDiscountAmount > 0) ...[
                        SizedBox(height: Dimens.smallPadding),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Kupon indirimi:',
                              style: appTypography.bodyMedium,
                            ),
                            Text(
                              '-${formatPrice(state.couponDiscountAmount)}',
                              style: appTypography.bodyMedium.copyWith(
                                color: appColors.success,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (state.totalDiscount > 0) ...[
                        SizedBox(height: Dimens.largePadding),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Kazancınız:',
                              style: appTypography.bodyMedium.copyWith(
                                color: appColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${formatPrice(state.totalDiscount)} indirim',
                              style: appTypography.bodyMedium.copyWith(
                                color: appColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: Dimens.largePadding),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Toplam:', style: appTypography.bodyLarge),
                          Text(
                            formatPrice(state.finalPrice),
                            style: appTypography.bodyLarge.copyWith(
                              color: appColors.primary,
                            ),
                          ),
                        ],
                      ),
                      AppButton(
                        title: 'Ödemeye Geç',
                        onPressed: () {
                          appPush(
                            context,
                            ProceedToCheckoutScreen(
                              cartSummary: CartSummaryForCheckout(
                                totalAmount: state.totalAmount,
                                finalPrice: state.finalPrice,
                                totalDiscount: state.totalDiscount,
                                couponDiscountAmount: state.couponDiscountAmount,
                                restaurantDiscountAmount:
                                    state.restaurantDiscountAmount,
                                canUseCoupon: state.canUseCoupon,
                                selectedUserCouponId: state.selectedUserCouponId,
                              ),
                            ),
                          );
                        },
                        textStyle: appTypography.bodyLarge,
                        borderRadius: Dimens.corners,
                        margin: EdgeInsets.symmetric(
                          vertical: Dimens.largePadding,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return SizedBox.shrink();
        },
      ),
    );
  }
}
