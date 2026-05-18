import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_logout.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/sized_context.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_confirm_dialog.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_icon_buttons.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/notification_bell_button.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_search_bar.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/panel_info_button.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/location_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/products_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/splash_screen.dart';

import '../../../../core/gen/assets.gen.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    String locationSubtitle(LocationState state) {
      if (state.status == LocationStatus.loading) {
        return 'Konum aliniyor...';
      }
      final city = state.city?.trim();
      final country = state.country?.trim();
      if (city != null &&
          city.isNotEmpty &&
          country != null &&
          country.isNotEmpty) {
        return '$city, $country';
      }
      if (country != null && country.isNotEmpty) {
        return country;
      }
      if (city != null && city.isNotEmpty) {
        return city;
      }
      if (state.latitude != null && state.longitude != null) {
        return '${state.latitude!.toStringAsFixed(4)}, '
            '${state.longitude!.toStringAsFixed(4)}';
      }
      return 'Konum bilinmiyor';
    }

    return Column(
      children: [
        AppBar(
          backgroundColor: colors.primary,
          actions: [
            const PanelInfoButton(iconColor: Colors.white),
            AppIconButton(
              iconPath: Assets.icons.logout,
              onPressed: () async {
                final shouldLogout = await AppConfirmDialog.show(
                  context,
                  title: 'Çıkış Yap',
                  message: 'Çıkış yapmak istediğinize emin misiniz?',
                  cancelText: 'Vazgeç',
                  confirmText: 'Çıkış',
                  isDestructive: true,
                );
                if (shouldLogout == true && context.mounted) {
                  await performAuthLogout();
                  if (!context.mounted) return;
                  await appPushReplacement(context, const SplashScreen());
                }
              },
            ),
            const NotificationBellButton(),
          ],
          title: Row(
            spacing: Dimens.padding,
            children: [
              AppIconButton(iconPath: Assets.icons.location),
              Column(
                spacing: Dimens.padding,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Konum',
                    style: typography.titleSmall.copyWith(
                      color: colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  BlocBuilder<LocationCubit, LocationState>(
                    builder: (context, state) {
                      return Text(
                        locationSubtitle(state),
                        style: typography.titleSmall.copyWith(
                          color: colors.white,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          leadingWidth: 85,
          titleSpacing: Dimens.padding,
          actionsPadding: EdgeInsets.symmetric(horizontal: Dimens.largePadding),
        ),
        Stack(
          children: [
            Container(
              height: 50,
              width: context.widthPx,
              decoration: BoxDecoration(
                color: context.theme.appColors.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(Dimens.extraLargePadding),
                  bottomRight: Radius.circular(Dimens.extraLargePadding),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: 25,
                left: Dimens.largePadding,
                right: Dimens.largePadding,
              ),
              child: AppSearchBar(
                readOnly: true,
                onTap: () => appPush(context, const ProductsScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(AppBar().preferredSize.height + 80);
}
