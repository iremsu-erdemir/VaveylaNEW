import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/gen/assets.gen.dart';
import 'package:intl/intl.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/formatters.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_svg_viewer.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/shaded_container.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/models/menu_item_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/models/order_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/presentation/bloc/restaurant_menu_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/presentation/bloc/restaurant_orders_cubit.dart';

class RestaurantOwnerReportsScreen extends StatelessWidget {
  const RestaurantOwnerReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return AppScaffold(
      appBar: GeneralAppBar(title: 'Raporlar'),
      body: BlocBuilder<RestaurantOrdersCubit, List<RestaurantOrderModel>>(
        builder: (context, orders) {
          return BlocBuilder<RestaurantMenuCubit, List<MenuItemModel>>(
            builder: (context, menuItems) {
              final completed = orders
                  .where((o) => o.status == RestaurantOrderStatus.completed)
                  .toList();
              final totalRevenue =
                  completed.fold<int>(0, (sum, o) => sum + o.total);
              final avgOrderValue =
                  completed.isEmpty ? 0 : totalRevenue ~/ completed.length;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(Dimens.largePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ReportsHeader(
                      totalRevenue: totalRevenue,
                      completedCount: completed.length,
                      avgOrderValue: avgOrderValue,
                    ),
                    const SizedBox(height: Dimens.extraLargePadding),
                    Text(
                      'Satış Özeti',
                      style: typography.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Dimens.largePadding),
                    _ReportQuickGrid(
                      items: [
                        _ReportStat(
                          icon: Assets.icons.moneyTick,
                          label: 'Toplam Gelir',
                          value: formatPrice(totalRevenue),
                          color: colors.success,
                        ),
                        _ReportStat(
                          icon: Assets.icons.receipt,
                          label: 'Tamamlanan',
                          value: '${completed.length}',
                          color: colors.primary,
                        ),
                        _ReportStat(
                          icon: Assets.icons.dollarCircle,
                          label: 'Ortalama',
                          value: formatPrice(avgOrderValue),
                          color: colors.secondary,
                        ),
                        _ReportStat(
                          icon: Assets.icons.menu,
                          label: 'Toplam Ürün',
                          value: '${menuItems.length}',
                          color: colors.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: Dimens.extraLargePadding),
                    Text(
                      'Menü Özeti',
                      style: typography.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Dimens.largePadding),
                    _ReportCard(
                      icon: Assets.icons.bagTick,
                      label: 'Aktif Ürün',
                      value: '${menuItems.where((m) => m.isAvailable).length}',
                      color: colors.success,
                    ),
                    const SizedBox(height: Dimens.largePadding),
                    _DailyTrendCard(orders: completed),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final String icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.appTypography;
    return ShadedContainer(
      padding: const EdgeInsets.all(Dimens.largePadding),
      child: Row(
        children: [
          AppSvgViewer(icon, width: 32, color: color),
          const SizedBox(width: Dimens.largePadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: typography.bodyMedium.copyWith(
                    color: context.theme.appColors.gray4,
                  ),
                ),
                Text(
                  value,
                  style: typography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader({
    required this.totalRevenue,
    required this.completedCount,
    required this.avgOrderValue,
  });

  final int totalRevenue;
  final int completedCount;
  final int avgOrderValue;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return Container(
      padding: const EdgeInsets.all(Dimens.largePadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            colors.primary.withValues(alpha: 0.18),
            colors.secondary.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.analytics, color: colors.primary),
          ),
          const SizedBox(width: Dimens.largePadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Toplam gelir ${formatPrice(totalRevenue)}',
                  style: typography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completedCount sipariş · Ortalama ${formatPrice(avgOrderValue)}',
                  style: typography.bodySmall.copyWith(color: colors.gray4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportStat {
  const _ReportStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final String icon;
  final String label;
  final String value;
  final Color color;
}

class _ReportQuickGrid extends StatelessWidget {
  const _ReportQuickGrid({required this.items});

  final List<_ReportStat> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final childAspectRatio = width < 330 ? 1.4 : 1.6;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: Dimens.largePadding,
          crossAxisSpacing: Dimens.largePadding,
          childAspectRatio: childAspectRatio,
          children: items
              .map((item) => _ReportQuickCard(stat: item))
              .toList(),
        );
      },
    );
  }
}

class _ReportQuickCard extends StatelessWidget {
  const _ReportQuickCard({required this.stat});

  final _ReportStat stat;

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.appTypography;
    return Container(
      padding: const EdgeInsets.all(Dimens.largePadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: stat.color.withValues(alpha: 0.08),
        border: Border.all(color: stat.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppSvgViewer(stat.icon, width: 22, color: stat.color),
          const SizedBox(height: Dimens.padding),
          Text(
            stat.value,
            style: typography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: stat.color,
            ),
          ),
          Text(
            stat.label,
            style: typography.bodySmall.copyWith(
              color: stat.color.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyTrendCard extends StatelessWidget {
  const _DailyTrendCard({required this.orders});

  final List<RestaurantOrderModel> orders;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    final buckets = _lastSevenDayBuckets(orders);
    final maxCount = buckets
        .map((b) => b.count)
        .fold<int>(0, (m, c) => c > m ? c : m);
    final scaleMax = maxCount < 1 ? 1 : maxCount;
    const chartHeight = 100.0;
    const chartStackHeight = 158.0;

    return Container(
      padding: const EdgeInsets.all(Dimens.largePadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colors.white,
        border: Border.all(color: colors.gray.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Günlük Trend',
            style: typography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Dimens.largePadding),
          SizedBox(
            height: chartStackHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: buckets.map((b) {
                final barH = b.count == 0
                    ? 6.0
                    : 14.0 + (b.count / scaleMax) * (chartHeight - 14);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (b.count > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${b.count}',
                              style: typography.labelSmall.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        Container(
                          height: barH,
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(
                              alpha: b.count == 0 ? 0.12 : 0.38,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          b.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: typography.labelSmall.copyWith(
                            color: colors.gray4,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: Dimens.smallPadding),
          Text(
            'Son 7 gün — tamamlanan sipariş sayısı (oluşturulma tarihine göre)',
            style: typography.bodySmall.copyWith(color: colors.gray4),
          ),
        ],
      ),
    );
  }

  /// API [RestaurantOrderModel.date] formatı: `dd.MM.yyyy` (yerel saat).
  List<_TrendDayBucket> _lastSevenDayBuckets(
    List<RestaurantOrderModel> completedOrders,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));
    final counts = List<int>.filled(7, 0);
    final dateFmt = DateFormat('dd.MM.yyyy', 'tr_TR');
    final labelFmt = DateFormat('d MMM', 'tr_TR');

    for (final o in completedOrders) {
      final raw = o.date.trim();
      if (raw.isEmpty) continue;
      try {
        final parsed = dateFmt.parse(raw);
        final day = DateTime(parsed.year, parsed.month, parsed.day);
        if (day.isBefore(start) || day.isAfter(today)) continue;
        final index = day.difference(start).inDays;
        if (index >= 0 && index < 7) {
          counts[index]++;
        }
      } catch (_) {
        continue;
      }
    }

    return List.generate(7, (i) {
      final d = start.add(Duration(days: i));
      return _TrendDayBucket(
        label: labelFmt.format(d),
        count: counts[i],
      );
    });
  }
}

class _TrendDayBucket {
  const _TrendDayBucket({required this.label, required this.count});

  final String label;
  final int count;
}
