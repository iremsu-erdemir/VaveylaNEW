import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_sweet_shop_app_ui/core/gen/assets.gen.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/formatters.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_svg_viewer.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/data/models/courier_order_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/presentation/bloc/courier_orders_cubit.dart';

class CourierEarningsScreen extends StatelessWidget {
  const CourierEarningsScreen({super.key});

  static DateTime? _parseOrderDate(CourierOrderModel order) {
    if (order.date.isEmpty) return null;
    try {
      final parts = order.date.split('.');
      if (parts.length != 3) return null;
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day == null || month == null || year == null) return null;
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  static bool _isToday(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  static bool _isThisWeek(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final end = start.add(const Duration(days: 7));
    return !d.isBefore(start) && d.isBefore(end);
  }

  static bool _isThisMonth(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const GeneralAppBar(title: 'Kazançlarım'),
      body: BlocBuilder<CourierOrdersCubit, List<CourierOrderModel>>(
        builder: (context, orders) {
          final delivered = orders
              .where((o) => o.status == CourierOrderStatus.delivered)
              .toList();

          final todayOrders =
              delivered.where((o) => _isToday(_parseOrderDate(o))).toList();
          final weekOrders =
              delivered.where((o) => _isThisWeek(_parseOrderDate(o))).toList();
          final monthOrders =
              delivered.where((o) => _isThisMonth(_parseOrderDate(o))).toList();

          final totalEarnings =
              delivered.fold<int>(0, (sum, o) => sum + o.total);
          final todayEarnings =
              todayOrders.fold<int>(0, (sum, o) => sum + o.total);
          final weekEarnings =
              weekOrders.fold<int>(0, (sum, o) => sum + o.total);
          final monthEarnings =
              monthOrders.fold<int>(0, (sum, o) => sum + o.total);

          if (delivered.isEmpty) {
            return _EmptyEarnings();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(Dimens.largePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TotalEarningsCard(amount: totalEarnings),
                const SizedBox(height: Dimens.extraLargePadding),
                _PeriodSummary(
                  today: todayEarnings,
                  week: weekEarnings,
                  month: monthEarnings,
                ),
                const SizedBox(height: Dimens.extraLargePadding),
                Text(
                  'Teslim Edilen Siparişler',
                  style: context.theme.appTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Dimens.largePadding),
                ...delivered.map((o) => Padding(
                      padding: const EdgeInsets.only(bottom: Dimens.largePadding),
                      child: _EarningsOrderCard(order: o),
                    )),
                const SizedBox(height: Dimens.extraLargePadding),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TotalEarningsCard extends StatelessWidget {
  const _TotalEarningsCard({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimens.extraLargePadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            colors.success.withValues(alpha: 0.25),
            colors.success.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: colors.success.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: colors.success.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AppSvgViewer(
                  Assets.icons.moneyTick,
                  width: 28,
                  color: colors.success,
                ),
              ),
              const SizedBox(width: Dimens.largePadding),
              Text(
                'Toplam Kazanç',
                style: typography.titleMedium.copyWith(
                  color: colors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimens.largePadding),
          Text(
            formatPrice(amount),
            style: typography.headlineMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSummary extends StatelessWidget {
  const _PeriodSummary({
    required this.today,
    required this.week,
    required this.month,
  });

  final int today;
  final int week;
  final int month;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return Row(
      children: [
        Expanded(
          child: _PeriodChip(
            label: 'Bugün',
            value: formatPrice(today),
            color: colors.primary,
            typography: typography,
          ),
        ),
        const SizedBox(width: Dimens.largePadding),
        Expanded(
          child: _PeriodChip(
            label: 'Bu Hafta',
            value: formatPrice(week),
            color: colors.secondary,
            typography: typography,
          ),
        ),
        const SizedBox(width: Dimens.largePadding),
        Expanded(
          child: _PeriodChip(
            label: 'Bu Ay',
            value: formatPrice(month),
            color: colors.success,
            typography: typography,
          ),
        ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.value,
    required this.color,
    required this.typography,
  });

  final String label;
  final String value;
  final Color color;
  final dynamic typography;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimens.largePadding),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Dimens.corners),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: typography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Dimens.smallPadding),
          Text(
            value,
            style: typography.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _EarningsOrderCard extends StatelessWidget {
  const _EarningsOrderCard({required this.order});

  final CourierOrderModel order;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return Container(
      padding: const EdgeInsets.all(Dimens.largePadding),
      decoration: BoxDecoration(
        color: colors.white,
        borderRadius: BorderRadius.circular(Dimens.corners),
        border: Border.all(color: colors.success.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: colors.success.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Dimens.corners),
            child: order.imagePath.isNotEmpty
                ? Image.network(
                    order.imagePath,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  )
                : Assets.images.logo.image(
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: Dimens.largePadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.items,
                  style: typography.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.date} • ${order.time}',
                  style: typography.bodySmall.copyWith(color: colors.gray4),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimens.largePadding,
              vertical: Dimens.padding,
            ),
            decoration: BoxDecoration(
              color: colors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              formatPrice(order.total),
              style: typography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyEarnings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Dimens.extraLargePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(Dimens.extraLargePadding),
              decoration: BoxDecoration(
                color: colors.gray.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 64,
                color: colors.gray4,
              ),
            ),
            const SizedBox(height: Dimens.extraLargePadding),
            Text(
              'Henüz kazanç yok',
              style: typography.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Dimens.padding),
            Text(
              'Teslim ettiğiniz siparişler burada görünecek',
              style: typography.bodyMedium.copyWith(color: colors.gray4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
