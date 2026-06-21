import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';

import '../gen/assets.gen.dart';
import '../theme/dimens.dart';
import '../theme/theme.dart';
import 'app_bordered_icon_button.dart';
import 'panel_info_button.dart';

class GeneralAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GeneralAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackIcon = true,
    this.bottom,
    this.height,
    this.onLeadingPressed,
    this.includeInfoButton = true,
  });

  final String title;
  final List<Widget>? actions;
  final bool showBackIcon;
  final PreferredSizeWidget? bottom;
  final double? height;
  final bool includeInfoButton;

  /// Örn. sekme kökünde [Navigator.pop] işe yaramazsa Ana Sayfa’ya dönmek için.
  final VoidCallback? onLeadingPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    final appBarActions = <Widget>[
      if (actions != null) ...actions!,
      if (includeInfoButton) const PanelInfoButton(),
    ];

    return AppBar(
      centerTitle: true,
      actions: appBarActions.isEmpty ? null : appBarActions,
      title: Text(
        title,
        style: typography.titleMedium.copyWith(
          fontWeight: FontWeight.w700,
          color: colors.primary,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.primary.withValues(alpha: 0.12),
              colors.secondary.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      leading:
          showBackIcon
              ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimens.largePadding,
                ),
                child: AppBorderedIconButton(
                  iconPath: Assets.icons.arrowLeft,
                  color: colors.primary,
                  onPressed: () {
                    if (onLeadingPressed != null) {
                      onLeadingPressed!();
                    } else {
                      appPop(context);
                    }
                  },
                ),
              )
              : null,
      leadingWidth: 90.0,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize {
    final toolbar = height ?? (AppBar().preferredSize.height + 16.0);
    final bottomH = bottom?.preferredSize.height ?? 0.0;
    return Size.fromHeight(toolbar + bottomH);
  }
}
