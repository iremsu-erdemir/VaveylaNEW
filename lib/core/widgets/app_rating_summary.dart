import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';

class AppRatingSummary extends StatelessWidget {
  const AppRatingSummary({
    super.key,
    required this.rating,
    required this.reviewCount,
    this.textColor,
  });

  final double rating;
  final int reviewCount;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final resolvedTextColor = textColor ?? context.theme.appColors.gray4;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '⭐',
          style: TextStyle(
            color: context.theme.appColors.primary,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${rating.toStringAsFixed(1)} ($reviewCount yorum)',
          style: TextStyle(color: resolvedTextColor, fontSize: 12),
        ),
      ],
    );
  }
}
