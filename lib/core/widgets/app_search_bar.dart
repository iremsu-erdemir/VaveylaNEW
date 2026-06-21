import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/shaded_container.dart';

import '../gen/assets.gen.dart';
import '../theme/dimens.dart';
import 'app_svg_viewer.dart';

class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    this.controller,
    this.onChanged,
    this.hintText,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String? hintText;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    return ShadedContainer(
      height: 50,
      child: Padding(
        padding: const EdgeInsets.only(top: Dimens.smallPadding),
        child: TextFormField(
          controller: controller,
          onChanged: onChanged,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            hintText: hintText ?? 'Kek, pasta, peynirli kek ara',
            hintStyle: TextStyle(color: colors.gray2, fontSize: 13),
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimens.mediumPadding,
              ),
              child: AppSvgViewer(Assets.icons.searchNormal1),
            ),
          ),
        ),
      ),
    );
  }
}
