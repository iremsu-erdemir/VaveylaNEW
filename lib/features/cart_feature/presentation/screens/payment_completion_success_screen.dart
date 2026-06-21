import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_button.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/bloc/cart_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/home_screen.dart';

class PaymentCompletionSuccessScreen extends StatelessWidget {
  const PaymentCompletionSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appColors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return AppScaffold(
      safeAreaBottom: false,
      body: Stack(
        children: [
          Positioned(
            top: -70,
            right: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: appColors.success.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -70,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: appColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimens.extraLargePadding),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimens.extraLargePadding,
                  vertical: 34,
                ),
                decoration: BoxDecoration(
                  color: appColors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: appColors.gray.withValues(alpha: 0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: appColors.black.withValues(alpha: 0.06),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: appColors.success.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            color: appColors.success.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 46,
                            color: appColors.success,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Dimens.largePadding),
                    Text(
                      context.tr('payment_success_title'),
                      style: typography.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Dimens.padding),
                    Text(
                      context.tr('payment_success_message'),
                      style: typography.bodyMedium.copyWith(color: appColors.gray4),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: appColors.white,
          boxShadow: [
            BoxShadow(
              color: appColors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(
              left: Dimens.largePadding,
              right: Dimens.largePadding,
              bottom: Dimens.largePadding,
              top: Dimens.padding,
            ),
            child: AppButton(
              onPressed: () {
                context.read<CartCubit>().clearCart();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const HomeScreen(initialTabIndex: 2),
                  ),
                  (_) => false,
                );
              },
              title: context.tr('done'),
              textStyle: typography.bodyLarge.copyWith(color: appColors.white),
              borderRadius: Dimens.corners,
              margin: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}
