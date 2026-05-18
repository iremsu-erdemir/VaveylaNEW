import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/colors.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';

/// Admin paneli listelerinde restoran sahibi sipariş kartları ile uyumlu yüzey.
class AdminListCard extends StatelessWidget {
  const AdminListCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.only(bottom: Dimens.largePadding),
    this.padding = const EdgeInsets.all(Dimens.largePadding),
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  static BoxDecoration decoration(AppColors colors) {
    return BoxDecoration(
      color: colors.white,
      borderRadius: BorderRadius.circular(Dimens.corners),
      border: Border.all(color: colors.gray.withValues(alpha: 0.2)),
      boxShadow: [
        BoxShadow(
          color: colors.black.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    return Container(
      margin: margin,
      padding: padding,
      decoration: decoration(colors),
      child: child,
    );
  }
}
