import 'package:flutter/material.dart';

import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/bordered_container.dart';

/// Admin geri bildirim cezasıyla uyumlu eşikler ([FeedbackAppService] ile aynı sayılar).
class PenaltyPointsSummaryCard extends StatelessWidget {
  const PenaltyPointsSummaryCard({super.key, required this.points});

  final int points;

  static const int _suspend3 = 50;
  static const int _suspend7 = 70;
  static const int _permanent = 100;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    final progress = (points / _permanent).clamp(0.0, 1.0);

    return BorderedContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel_outlined, color: colors.primary, size: 22),
              const SizedBox(width: Dimens.padding),
              Expanded(
                child: Text(
                  'Ceza puanı',
                  style: typography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$points',
                style: typography.headlineSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimens.padding),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: colors.gray,
              color: points >= _permanent
                  ? colors.error
                  : points >= _suspend7
                  ? colors.error.withValues(alpha: 0.85)
                  : points >= _suspend3
                  ? colors.secondary
                  : colors.primary,
            ),
          ),
          const SizedBox(height: Dimens.largePadding),
          Text(
            'Toplam puan yönetici uyarıları ve cezalarından oluşur. '
            '$_suspend3 puana ulaşınca en az 3 gün, $_suspend7 puanda 7 gün askı; '
            '$_permanent puanda kalıcı kısıtlama uygulanabilir.',
            style: typography.bodySmall.copyWith(
              color: colors.gray4,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
