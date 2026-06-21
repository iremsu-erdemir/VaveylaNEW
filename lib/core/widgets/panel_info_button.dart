import 'package:flutter/material.dart';

import '../constants/help_documentation_constants.dart';
import '../theme/theme.dart';
import '../utils/app_navigator.dart';
import 'help_documentation_screen.dart';

class PanelInfoButton extends StatelessWidget {
  const PanelInfoButton({super.key, this.iconColor});

  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final resolvedIconColor = iconColor ?? colors.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () => appPush(context, const HelpDocumentationScreen()),
        borderRadius: BorderRadius.circular(100),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: resolvedIconColor.withValues(alpha: 0.7),
              width: 1.4,
            ),
            color: resolvedIconColor.withValues(alpha: 0.08),
          ),
          alignment: Alignment.center,
          child: Text(
            'i',
            style: context.theme.appTypography.titleMedium.copyWith(
              color: resolvedIconColor,
              fontWeight: FontWeight.w700,
            ),
            semanticsLabel: HelpDocumentationConstants.title,
          ),
        ),
      ),
    );
  }
}
