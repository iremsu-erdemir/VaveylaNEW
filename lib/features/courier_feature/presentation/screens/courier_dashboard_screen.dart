import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/gen/assets.gen.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/formatters.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_svg_viewer.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/bordered_container.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/notification_bell_button.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/shaded_container.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/data/models/courier_order_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/presentation/bloc/courier_nav_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/presentation/bloc/courier_orders_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/presentation/screens/courier_orders_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/presentation/screens/courier_tracking_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/presentation/screens/courier_chats_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/presentation/screens/courier_settings_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/presentation/screens/courier_earnings_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/presentation/bloc/courier_location_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/presentation/bloc/courier_orders_tab_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/data/services/courier_service.dart';
import 'package:google_fonts/google_fonts.dart';

class CourierDashboardScreen extends StatelessWidget {
  const CourierDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final courierUserId = AppSession.userId;
    final courierService = CourierService(authService: AuthService());
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CourierNavCubit()),
        BlocProvider(
          create:
              (_) =>
                  CourierOrdersCubit(courierService, courierUserId)
                    ..loadOrders()
                    ..startPolling(),
        ),
        BlocProvider(
          create:
              (_) => CourierLocationCubit(
                courierService: courierService,
                courierUserId: courierUserId,
              ),
        ),
        BlocProvider(create: (_) => CourierOrdersTabCubit()),
      ],
      child: const _CourierDashboardScreen(),
    );
  }
}

class _CourierDashboardScreen extends StatelessWidget {
  const _CourierDashboardScreen();

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    return BlocListener<CourierOrdersCubit, List<CourierOrderModel>>(
      listener: (context, orders) {
        final loc = context.read<CourierLocationCubit>();
        unawaited(
          loc.reconcileTrackingWithOrders(
            orders,
            preferredOrderId: loc.activeTrackingOrderId,
          ),
        );
      },
      child: BlocBuilder<CourierNavCubit, int>(
        builder: (context, selectedIndex) {
          final cubit = context.read<CourierNavCubit>();
          final List<Widget> screens = [
            const _DashboardTab(),
            const CourierOrdersScreen(),
            const CourierTrackingScreen(),
            const CourierChatsScreen(),
            const CourierSettingsScreen(),
          ];
          return AppScaffold(
            padding: EdgeInsets.zero,
            body: screens[selectedIndex],
            bottomNavigationBar: SafeArea(
              top: false,
              minimum: EdgeInsets.zero,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      spreadRadius: 3,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.only(top: 6, left: 8, right: 8, bottom: 4),
                child: NavigationBar(
                  height: 72,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: cubit.onItemTap,
                  destinations: [
                    NavigationDestination(
                      icon: AppSvgViewer(Assets.icons.home2),
                      selectedIcon: AppSvgViewer(
                        Assets.icons.home2,
                        color: colors.primary,
                      ),
                      label: 'Panel',
                    ),
                    NavigationDestination(
                      icon: AppSvgViewer(Assets.icons.receipt),
                      selectedIcon: AppSvgViewer(
                        Assets.icons.receipt,
                        color: colors.primary,
                      ),
                      label: 'Siparişler',
                    ),
                    NavigationDestination(
                      icon: AppSvgViewer(Assets.icons.map1),
                      selectedIcon: AppSvgViewer(
                        Assets.icons.map1,
                        color: colors.primary,
                      ),
                      label: 'Harita',
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      selectedIcon: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: colors.primary,
                      ),
                      label: 'Sohbet',
                    ),
                    NavigationDestination(
                      icon: AppSvgViewer(Assets.icons.setting2),
                      selectedIcon: AppSvgViewer(
                        Assets.icons.setting2,
                        color: colors.primary,
                      ),
                      label: 'Ayarlar',
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return BlocBuilder<CourierOrdersCubit, List<CourierOrderModel>>(
      builder: (context, orders) {
        final assigned =
            orders
                .where(
                  (o) =>
                      o.status == CourierOrderStatus.assigned &&
                      !o.courierDeclined,
                )
                .length;
        final inTransit =
            orders
                .where(
                  (o) =>
                      o.status == CourierOrderStatus.pickedUp ||
                      o.status == CourierOrderStatus.inTransit,
                )
                .length;
        final delivered =
            orders
                .where((o) => o.status == CourierOrderStatus.delivered)
                .length;
        final totalEarnings = orders
            .where((o) => o.status == CourierOrderStatus.delivered)
            .fold<int>(0, (sum, o) => sum + o.total);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(Dimens.largePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DashboardHeader(
                title: 'Kurye Paneli',
                subtitle: 'Hoş geldiniz! Bugünkü teslimatlarınız',
              ),
              const SizedBox(height: Dimens.largePadding),
              const _CampaignCarousel(),
              const SizedBox(height: Dimens.extraLargePadding),
              _StatsGrid(
                stats: [
                  _StatItem(
                    icon: Assets.icons.bagTimer,
                    label: 'Ürünü Bekleme',
                    value: '$assigned',
                    color: colors.warning,
                    onTap: () {
                      context.read<CourierOrdersTabCubit>().selectTab(0);
                      context.read<CourierNavCubit>().onItemTap(1);
                    },
                  ),
                  _StatItem(
                    icon: Assets.icons.routing2,
                    label: 'Yolda',
                    value: '$inTransit',
                    color: colors.primary,
                    onTap: () {
                      context.read<CourierOrdersTabCubit>().selectTab(1);
                      context.read<CourierNavCubit>().onItemTap(1);
                    },
                  ),
                  _StatItem(
                    icon: Assets.icons.bagTick,
                    label: 'Teslim',
                    value: '$delivered',
                    color: colors.success,
                    onTap: () {
                      context.read<CourierOrdersTabCubit>().selectTab(2);
                      context.read<CourierNavCubit>().onItemTap(1);
                    },
                  ),
                  _StatItem(
                    icon: Assets.icons.moneyTick,
                    label: 'Kazanç',
                    value: formatPrice(totalEarnings),
                    color: colors.secondary,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => BlocProvider.value(
                                value: context.read<CourierOrdersCubit>(),
                                child: const CourierEarningsScreen(),
                              ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: Dimens.extraLargePadding),
              _LiveStatusStrip(
                assigned: assigned,
                inTransit: inTransit,
                delivered: delivered,
              ),
              const SizedBox(height: Dimens.extraLargePadding),
              Text(
                'Hızlı İşlemler',
                style: typography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Dimens.largePadding),
              _QuickActionCard(
                icon: Assets.icons.receipt,
                title: 'Siparişleri Gör',
                subtitle: 'Atanmış teslimatları listele',
                onTap: () => context.read<CourierNavCubit>().onItemTap(1),
              ),
              const SizedBox(height: Dimens.largePadding),
              _QuickActionCard(
                icon: Assets.icons.map1,
                title: 'Canlı Takip',
                subtitle: 'Haritada teslimat konumunu takip et',
                onTap: () => context.read<CourierNavCubit>().onItemTap(2),
              ),
              const SizedBox(height: Dimens.largePadding),
              _QuickActionCard(
                icon: Assets.icons.moneyTick,
                title: 'Kazançlarım',
                subtitle: 'Teslim edilen siparişlerden kazançları gör',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder:
                          (_) => BlocProvider.value(
                            value: context.read<CourierOrdersCubit>(),
                            child: const CourierEarningsScreen(),
                          ),
                    ),
                  );
                },
              ),
              const SizedBox(height: Dimens.extraLargePadding),
            ],
          ),
        );
      },
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final List<_StatItem> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final childAspectRatio = width < 300 ? 1.2 : 1.4;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: Dimens.largePadding,
          crossAxisSpacing: Dimens.largePadding,
          childAspectRatio: childAspectRatio,
          children: stats.map((s) => _StatCard(item: s)).toList(),
        );
      },
    );
  }
}

class _StatItem {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final String icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});

  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.appTypography;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(Dimens.corners),
        child: Container(
          padding: const EdgeInsets.all(Dimens.largePadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimens.corners),
            gradient: LinearGradient(
              colors: [
                item.color.withValues(alpha: 0.16),
                item.color.withValues(alpha: 0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: item.color.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: item.color.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AppSvgViewer(item.icon, width: 22, color: item.color),
              ),
              const SizedBox(height: Dimens.padding),
              Text(
                item.value,
                style: typography.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: item.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Dimens.smallPadding),
              Text(
                item.label,
                style: typography.bodySmall.copyWith(
                  color: context.theme.appColors.gray4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return Container(
      padding: const EdgeInsets.all(Dimens.extraLargePadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            colors.primary.withValues(alpha: 0.18),
            colors.secondary.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.withValues(alpha: 0.2),
            ),
            child: Icon(Icons.delivery_dining, color: colors.primary),
          ),
          const SizedBox(width: Dimens.largePadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.lobsterTwo(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 26,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: typography.bodyMedium.copyWith(color: colors.gray4),
                ),
              ],
            ),
          ),
          const NotificationBellButton(),
        ],
      ),
    );
  }
}

class _CampaignCarousel extends StatelessWidget {
  const _CampaignCarousel();

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    return SizedBox(
      height: 140,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _CampaignCard(
            title: 'Hızlı Teslimat',
            subtitle: 'Ortalama teslimat 25 dk',
            color: colors.primary,
          ),
          const SizedBox(width: Dimens.largePadding),
          _CampaignCard(
            title: 'Canlı Takip',
            subtitle: 'Müşteri konumuna haritadan ulaş',
            color: colors.secondary,
          ),
          const SizedBox(width: Dimens.largePadding),
          _CampaignCard(
            title: 'Günlük Kazanç',
            subtitle: 'Teslim edilen siparişlerden kazanç',
            color: colors.success,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder:
                      (_) => BlocProvider.value(
                        value: context.read<CourierOrdersCubit>(),
                        child: const CourierEarningsScreen(),
                      ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.appTypography;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(Dimens.largePadding),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: typography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(subtitle, style: typography.bodySmall.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _LiveStatusStrip extends StatelessWidget {
  const _LiveStatusStrip({
    required this.assigned,
    required this.inTransit,
    required this.delivered,
  });

  final int assigned;
  final int inTransit;
  final int delivered;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return Container(
      padding: const EdgeInsets.all(Dimens.largePadding),
      decoration: BoxDecoration(
        color: colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.gray.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Teslimat Süreci',
            style: typography.labelMedium.copyWith(
              color: colors.gray4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Dimens.largePadding),
          Row(
            children: [
              Expanded(
                child: _StatusPill(
                  label: 'Ürünü Bekleme',
                  value: assigned,
                  color: colors.warning,
                  typography: typography,
                  onTap: () {
                    context.read<CourierOrdersTabCubit>().selectTab(0);
                    context.read<CourierNavCubit>().onItemTap(1);
                  },
                ),
              ),
              _FlowArrow(color: colors.gray4),
              Expanded(
                child: _StatusPill(
                  label: 'Yolda',
                  value: inTransit,
                  color: colors.primary,
                  typography: typography,
                  onTap: () {
                    context.read<CourierOrdersTabCubit>().selectTab(1);
                    context.read<CourierNavCubit>().onItemTap(1);
                  },
                ),
              ),
              _FlowArrow(color: colors.gray4),
              Expanded(
                child: _StatusPill(
                  label: 'Teslim',
                  value: delivered,
                  color: colors.success,
                  typography: typography,
                  onTap: () {
                    context.read<CourierOrdersTabCubit>().selectTab(2);
                    context.read<CourierNavCubit>().onItemTap(1);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowArrow extends StatelessWidget {
  const _FlowArrow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.smallPadding),
      child: Icon(Icons.arrow_forward, size: 18, color: color),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.value,
    required this.color,
    required this.typography,
    this.onTap,
  });

  final String label;
  final int value;
  final Color color;
  final dynamic typography;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimens.largePadding,
            vertical: Dimens.padding,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value',
                style: typography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                label,
                style: typography.labelSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return BorderedContainer(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Dimens.corners),
        child: Padding(
          padding: const EdgeInsets.all(Dimens.largePadding),
          child: Row(
            children: [
              ShadedContainer(
                width: 56,
                height: 56,
                borderRadius: Dimens.corners,
                child: Center(
                  child: AppSvgViewer(icon, width: 28, color: colors.primary),
                ),
              ),
              const SizedBox(width: Dimens.largePadding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: typography.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: typography.bodySmall.copyWith(color: colors.gray4),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AppSvgViewer(
                Assets.icons.arrowRight4,
                width: 20,
                color: colors.gray4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
