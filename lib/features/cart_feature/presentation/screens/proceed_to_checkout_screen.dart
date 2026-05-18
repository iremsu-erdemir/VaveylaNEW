import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/formatters.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_divider.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_svg_viewer.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/bordered_container.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/user_address_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/bloc/cart_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/screens/change_address_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/screens/payment_methods_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/coupon_feature/presentation/screens/coupon_select_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/widgets/orders_list_for_checkout.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/widgets/payment_details_item.dart';

import '../../../../core/gen/assets.gen.dart';
import '../../../../core/widgets/app_button.dart';

/// Bir önceki ekrandan (sepet) gelen toplam tutarlar.
class CartSummaryForCheckout {
  const CartSummaryForCheckout({
    required this.totalAmount,
    required this.finalPrice,
    required this.totalDiscount,
    this.couponDiscountAmount = 0,
    this.restaurantDiscountAmount = 0,
    this.canUseCoupon = true,
    this.selectedUserCouponId,
  });

  final double totalAmount;
  final double finalPrice;
  final double totalDiscount;
  final double couponDiscountAmount;
  final double restaurantDiscountAmount;
  final bool canUseCoupon;
  final String? selectedUserCouponId;
}

class ProceedToCheckoutScreen extends StatefulWidget {
  const ProceedToCheckoutScreen({
    super.key,
    this.cartSummary,
  });

  /// Önceki ekrandan (sepet) gelen toplam sepet tutarı.
  /// Sağlanırsa bu değerler gösterilir; yoksa CartCubit'ten alınır.
  final CartSummaryForCheckout? cartSummary;

  @override
  State<ProceedToCheckoutScreen> createState() =>
      _ProceedToCheckoutScreenState();
}

class _ProceedToCheckoutScreenState extends State<ProceedToCheckoutScreen> {
  String _deliveryAddress = 'Saraçlar Cd. Merkez, Edirne';

  @override
  void initState() {
    super.initState();
    _loadAddress();
    context.read<CartCubit>().loadCart();
  }

  Future<void> _loadAddress() async {
    try {
      final addresses = await UserAddressService().getAddresses(
        userId: AppSession.userId,
      );
      final selected = addresses.where((a) => a.isSelected).firstOrNull;
      if (selected != null && mounted) {
        setState(() {
          _deliveryAddress = selected.addressLine;
        });
      }
    } catch (_) {}
  }

  Future<void> _changeAddress() async {
    final newAddress = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ChangeAddressScreen()),
    );

    if (newAddress != null && newAddress.trim().isNotEmpty && mounted) {
      setState(() {
        _deliveryAddress = newAddress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTypography = context.theme.appTypography;
    final appColors = context.theme.appColors;
    return AppScaffold(
      appBar: GeneralAppBar(title: 'Ödemeye Geç'),
      body: SingleChildScrollView(
        child: Column(
          spacing: Dimens.largePadding,
          children: [
            SizedBox.shrink(),
            BorderedContainer(
              padding: EdgeInsets.symmetric(horizontal: Dimens.largePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: Dimens.largePadding,
                    ),
                    child: Text(
                      'Ödeme detayları',
                      style: appTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AppDivider(),
                  BlocBuilder<CartCubit, CartState>(
                    builder: (context, cartState) {
                      // CartLoaded varsa onu kullan; yoksa önceki ekrandan gelen tutarları göster
                      final CartSummaryForCheckout? summary = widget.cartSummary;
                      final bool usePassedSummary = cartState is! CartLoaded &&
                          summary != null;

                      if (cartState is! CartLoaded && summary == null) {
                        return Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: Dimens.largePadding,
                          ),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final loadedState = cartState is CartLoaded
                          ? cartState
                          : null;
                      final s = summary;
                      final originalAmount = (usePassedSummary && s != null
                              ? s.totalAmount
                              : loadedState!.totalAmount)
                          .round();
                      const deliveryFee = 10;
                      final discount = (usePassedSummary && s != null
                              ? s.totalDiscount
                              : loadedState!.totalDiscount)
                          .round();
                      final productSubtotal = (usePassedSummary && s != null
                              ? s.finalPrice
                              : loadedState!.finalPrice)
                          .round();
                      final total = productSubtotal + deliveryFee;

                      final couponDiscount = usePassedSummary && s != null
                          ? s.couponDiscountAmount
                          : loadedState!.couponDiscountAmount;
                      final restaurantDiscount = usePassedSummary && s != null
                          ? s.restaurantDiscountAmount
                          : loadedState!.restaurantDiscountAmount;
                      final selectedCouponId = usePassedSummary && s != null
                          ? s.selectedUserCouponId
                          : loadedState!.selectedUserCouponId;
                      final canUseCoupon = usePassedSummary && s != null
                          ? s.canUseCoupon
                          : loadedState!.canUseCoupon;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                            selectedCouponId,
                                      ),
                                ),
                              );
                              if (result != null && context.mounted) {
                                context.read<CartCubit>().selectCoupon(
                                  result.isEmpty ? null : result,
                                );
                              }
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: Dimens.padding,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                        couponDiscount > 0
                                            ? 'Kupon uygulandı'
                                            : restaurantDiscount > 0
                                            ? 'Restoran indirimi uygulanıyor'
                                            : 'Kupon veya restoran indirimi',
                                        style: appTypography.bodyMedium
                                            .copyWith(color: appColors.primary),
                                      ),
                                    ],
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: appColors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AppDivider(),
                          PaymentDetailsItem(
                            title: 'Ürün tutarı',
                            subtitle: formatPrice(originalAmount),
                          ),
                          if (discount > 0) ...[
                            PaymentDetailsItem(
                              title: couponDiscount > 0
                                  ? 'Kupon indirimi'
                                  : 'Restoran indirimi',
                              subtitle: '-${formatPrice(discount)}',
                            ),
                          ],
                          PaymentDetailsItem(
                            title: 'Teslimat',
                            subtitle: formatPrice(deliveryFee),
                          ),
                          Text(
                            ' - - - - - - - -' * 10,
                            overflow: TextOverflow.clip,
                            maxLines: 1,
                            style: TextStyle(color: appColors.gray2),
                          ),
                          PaymentDetailsItem(
                            title: 'Toplam tutar',
                            subtitle: formatPrice(total),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            BorderedContainer(
              padding: EdgeInsets.symmetric(horizontal: Dimens.largePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: Dimens.padding),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Teslimat adresi',
                          style: appTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        BorderedContainer(
                          borderColor: appColors.primary,
                          borderRadius: Dimens.smallCorners,
                          child: InkWell(
                            onTap: _changeAddress,
                            borderRadius: BorderRadius.circular(
                              Dimens.smallCorners,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(Dimens.padding),
                              child: Text(
                                'Adresi değiştir',
                                style: TextStyle(color: appColors.primary),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: Dimens.largePadding),
                  AppDivider(),
                  ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      vertical: Dimens.smallPadding,
                    ),
                    leading: AppSvgViewer(
                      Assets.icons.location,
                      color: appColors.primary,
                    ),
                    title: Text(
                      _deliveryAddress,
                      style: appTypography.titleSmall.copyWith(
                        color: appColors.gray4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimens.padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sipariş listesi',
                    style: appTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: Dimens.largePadding),
                  AppDivider(),
                  OrdersListForCheckout(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          left: Dimens.largePadding,
          right: Dimens.largePadding,
          bottom: Dimens.padding,
        ),
        child: AppButton(
          onPressed: () {
            appPush(
              context,
              PaymentMethodsScreen(deliveryAddress: _deliveryAddress),
            );
          },
          title: 'Ödemeye Devam Et',
          textStyle: appTypography.bodyLarge,
          borderRadius: Dimens.corners,
          margin: EdgeInsets.symmetric(vertical: Dimens.largePadding),
        ),
      ),
    );
  }
}
