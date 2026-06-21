import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/gen/assets.gen.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/formatters.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/data/models/courier_order_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/presentation/bloc/courier_location_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/presentation/bloc/courier_orders_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/presentation/bloc/courier_orders_tab_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/presentation/screens/courier_tracking_screen.dart';

bool _courierOrderAssignedToMe(CourierOrderModel order) {
  final mine = AppSession.userId.trim();
  final cid = order.assignedCourierUserId?.trim() ?? '';
  if (mine.isEmpty || cid.isEmpty) return false;
  return mine.toLowerCase() == cid.toLowerCase();
}

/// Siparişi veren müşteri: ad, telefon veya kullanıcı kimliği özeti.
String _courierOrderCustomerSummary(CourierOrderModel order) {
  final name = order.customerName?.trim() ?? '';
  final phone = order.customerPhone?.trim() ?? '';
  if (name.isNotEmpty && phone.isNotEmpty) {
    return '$name · $phone';
  }
  if (name.isNotEmpty) {
    return name;
  }
  if (phone.isNotEmpty) {
    return phone;
  }
  final uid = order.customerUserId?.trim() ?? '';
  if (uid.length >= 8) {
    return 'Hesap #${uid.substring(0, 8)}';
  }
  if (uid.isNotEmpty) {
    return 'Hesap #$uid';
  }
  return '';
}

class CourierOrdersScreen extends StatefulWidget {
  const CourierOrdersScreen({super.key});

  @override
  State<CourierOrdersScreen> createState() => _CourierOrdersScreenState();
}

class _CourierOrdersScreenState extends State<CourierOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && mounted) {
      try {
        context.read<CourierOrdersTabCubit>().selectTab(_tabController.index);
      } catch (_) {}
    }
  }

  void _syncToTabCubit() {
    if (!mounted) return;
    try {
      final tabIndex = context.read<CourierOrdersTabCubit>().state;
      if (_tabController.index != tabIndex) {
        _tabController.animateTo(tabIndex);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncToTabCubit());
    return BlocListener<CourierOrdersTabCubit, int>(
      listener: (_, tabIndex) => _syncToTabCubit(),
      child: AppScaffold(
        appBar: GeneralAppBar(
          title: 'Teslimat Siparişleri',
          showBackIcon: false,
          actions: [
            BlocBuilder<CourierLocationCubit, CourierLocationState>(
              buildWhen: (prev, curr) => prev.status != curr.status,
              builder: (context, locState) {
                if (locState.status != CourierLocationStatus.tracking) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  onPressed:
                      () => context.read<CourierLocationCubit>().stopTracking(),
                  icon: Icon(
                    Icons.location_disabled_rounded,
                    color: colors.error,
                    size: 28,
                  ),
                  tooltip: 'Canlı takibi durdur',
                );
              },
            ),
            IconButton(
              onPressed: () => context.read<CourierOrdersCubit>().loadOrders(),
              icon: Icon(Icons.refresh, color: colors.primary, size: 28),
              tooltip: 'Yenile',
            ),
            const SizedBox(width: Dimens.padding),
          ],
          height: AppBar().preferredSize.height + 56,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: BlocBuilder<CourierOrdersCubit, List<CourierOrderModel>>(
              builder: (context, orders) {
                final assigned = orders
                    .where(
                      (o) =>
                          o.status == CourierOrderStatus.assigned &&
                          !o.courierDeclined,
                    )
                    .length;
                final inTransit = orders
                    .where(
                      (o) =>
                          o.status == CourierOrderStatus.pickedUp ||
                          o.status == CourierOrderStatus.inTransit,
                    )
                    .length;
                final delivered = orders
                    .where((o) => o.status == CourierOrderStatus.delivered)
                    .length;
                final declined = orders.where((o) => o.courierDeclined).length;
                return TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  dividerColor: colors.gray,
                  labelColor: colors.primary,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  unselectedLabelColor: colors.black,
                  indicatorColor: colors.primary,
                  tabs: [
                    Tab(
                      child: _TabWithBadge(label: 'Bekleyen', count: assigned),
                    ),
                    Tab(
                      child: _TabWithBadge(label: 'Yolda', count: inTransit),
                    ),
                    Tab(
                      child: _TabWithBadge(label: 'Teslim', count: delivered),
                    ),
                    Tab(
                      child: _TabWithBadge(
                        label: 'Reddedilenler',
                        count: declined,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        body: BlocBuilder<CourierOrdersCubit, List<CourierOrderModel>>(
          builder: (context, orders) {
            return TabBarView(
              controller: _tabController,
              children: [
                _OrdersList(
                  orders:
                      orders
                          .where(
                            (o) =>
                                o.status == CourierOrderStatus.assigned &&
                                !o.courierDeclined,
                          )
                          .toList(),
                  status: CourierOrderStatus.assigned,
                  tabController: _tabController,
                ),
                _OrdersList(
                  orders:
                      orders
                          .where(
                            (o) =>
                                o.status == CourierOrderStatus.pickedUp ||
                                o.status == CourierOrderStatus.inTransit,
                          )
                          .toList(),
                  status: CourierOrderStatus.inTransit,
                  tabController: _tabController,
                ),
                _OrdersList(
                  orders:
                      orders
                          .where(
                            (o) => o.status == CourierOrderStatus.delivered,
                          )
                          .toList(),
                  status: CourierOrderStatus.delivered,
                  tabController: _tabController,
                ),
                _OrdersList(
                  orders: orders.where((o) => o.courierDeclined).toList(),
                  status: CourierOrderStatus.assigned,
                  tabController: _tabController,
                  isDeclinedTab: true,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TabWithBadge extends StatelessWidget {
  const _TabWithBadge({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: context.theme.appColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({
    required this.orders,
    required this.status,
    required this.tabController,
    this.isDeclinedTab = false,
  });

  final List<CourierOrderModel> orders;
  final CourierOrderStatus status;
  final TabController tabController;
  final bool isDeclinedTab;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delivery_dining_outlined, size: 64, color: colors.gray4),
            const SizedBox(height: Dimens.largePadding),
            Text(
              isDeclinedTab
                  ? 'Henüz reddedilen sipariş yok'
                  : 'Henüz sipariş yok',
              style: typography.bodyLarge.copyWith(color: colors.gray4),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(Dimens.largePadding),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: Dimens.largePadding),
      itemBuilder: (context, index) {
        final order = orders[index];
        final accent =
            order.courierDeclined ? colors.error : _statusColor(order.status);
        return Container(
          padding: const EdgeInsets.all(Dimens.largePadding),
          decoration: BoxDecoration(
            color: colors.white,
            borderRadius: BorderRadius.circular(Dimens.corners),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Dimens.corners),
                    child:
                        order.imagePath.isNotEmpty
                            ? Image.network(
                              order.imagePath,
                              width: 88,
                              height: 88,
                              fit: BoxFit.cover,
                            )
                            : Assets.images.logo.image(
                              width: 88,
                              height: 88,
                              fit: BoxFit.cover,
                            ),
                  ),
                  const SizedBox(width: Dimens.largePadding),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.items,
                                style: typography.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Dimens.padding,
                                vertical: Dimens.smallPadding,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                formatPrice(order.total),
                                style: typography.titleSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Dimens.padding),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: colors.gray4,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                order.customerAddress,
                                style: typography.bodySmall.copyWith(
                                  color: colors.gray4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Builder(
                          builder: (context) {
                            final customerLine = _courierOrderCustomerSummary(
                              order,
                            );
                            if (customerLine.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(
                                top: Dimens.smallPadding,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 16,
                                    color: colors.gray4,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Müşteri: $customerLine',
                                      style: typography.bodySmall.copyWith(
                                        color: colors.gray4,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        if (order.courierDeclined) ...[
                          const SizedBox(height: Dimens.padding),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(Dimens.padding),
                            decoration: BoxDecoration(
                              color: colors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(
                                Dimens.smallCorners,
                              ),
                              border: Border.all(
                                color: colors.error.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.block,
                                  size: 20,
                                  color: colors.error,
                                ),
                                const SizedBox(width: Dimens.smallPadding),
                                Expanded(
                                  child: Text(
                                    order.courierDeclineReason != null &&
                                            order.courierDeclineReason!
                                                .trim()
                                                .isNotEmpty
                                        ? 'Reddedildi: ${order.courierDeclineReason}'
                                        : 'Bu siparişi reddettiniz.',
                                    style: typography.bodySmall.copyWith(
                                      color: colors.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (order.status != CourierOrderStatus.delivered &&
                            !order.courierDeclined) ...[
                          const SizedBox(height: Dimens.padding),
                          Wrap(
                            spacing: Dimens.padding,
                            runSpacing: Dimens.padding,
                            children: _buildActionButtons(
                              context,
                              order,
                              order.status,
                              tabController,
                            ),
                          ),
                        ],
                        const SizedBox(height: Dimens.padding),
                        Row(
                          children: [
                            Text(
                              order.time,
                              style: typography.bodySmall.copyWith(
                                color: colors.gray4,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              order.courierDeclined
                                  ? 'Reddedildi'
                                  : _statusText(order.status),
                              style: typography.labelSmall.copyWith(
                                color:
                                    order.courierDeclined
                                        ? colors.error
                                        : accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (order.restaurantEarning > 0 ||
                            order.totalDiscount > 0) ...[
                          const SizedBox(height: Dimens.padding),
                          Container(
                            padding: const EdgeInsets.all(Dimens.padding),
                            decoration: BoxDecoration(
                              color: colors.gray.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                Dimens.smallCorners,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hakediş Özeti',
                                  style: typography.labelSmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colors.gray4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Müşteri Ödemesi:',
                                      style: typography.bodySmall,
                                    ),
                                    Text(
                                      formatPrice(order.customerPaidAmount),
                                      style: typography.bodySmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (order.totalDiscount > 0)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'İndirim:',
                                        style: typography.bodySmall,
                                      ),
                                      Text(
                                        formatPrice(order.totalDiscount),
                                        style: typography.bodySmall.copyWith(
                                          color: colors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Restoran Hakedişi:',
                                      style: typography.bodySmall,
                                    ),
                                    Text(
                                      formatPrice(order.restaurantEarning),
                                      style: typography.bodySmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: colors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildActionButtons(
    BuildContext context,
    CourierOrderModel order,
    CourierOrderStatus status,
    TabController tabController,
  ) {
    final colors = context.theme.appColors;
    final buttonStyle = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.largePadding,
        vertical: Dimens.padding,
      ),
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final cubit = context.read<CourierOrdersCubit>();

    if (order.courierDeclined) {
      return [];
    }

    if (status == CourierOrderStatus.assigned) {
      return [
        FilledButton(
          onPressed: () async {
            try {
              await cubit.markPickedUp(order.id);
              if (!context.mounted) return;
              tabController.animateTo(1);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sipariş #${order.id} kabul edildi')),
              );
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sipariş kabul edilemedi: $e')),
              );
            }
          },
          style: buttonStyle.copyWith(
            backgroundColor: WidgetStateProperty.all(colors.success),
          ),
          child: const Text('Siparişi Kabul Et'),
        ),
        FilledButton.icon(
          onPressed: () async {
            try {
              await cubit.markPickedUp(order.id);
              if (!context.mounted) return;
              tabController.animateTo(1);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder:
                      (_) => MultiBlocProvider(
                        providers: [
                          BlocProvider.value(value: cubit),
                          BlocProvider.value(
                            value: context.read<CourierLocationCubit>(),
                          ),
                        ],
                        child: CourierTrackingScreen(selectedOrder: order),
                      ),
                ),
              );
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sipariş kabul edilemedi: $e')),
              );
            }
          },
          icon: const Icon(Icons.map, size: 18),
          label: const Text('Haritada Git'),
          style: buttonStyle,
        ),
        if (!_courierOrderAssignedToMe(order))
          OutlinedButton(
            onPressed: () async {
              final reason = await _showCourierRejectReasonDialog(
                context,
                orderId: order.id,
                isPoolReject: true,
              );
              if (reason == null || !context.mounted) return;
              try {
                await cubit.rejectAssignment(order.id, reason);
                if (!context.mounted) return;
                tabController.animateTo(3);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sipariş reddedildi.')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Reddedilemedi: $e')));
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              side: BorderSide(color: colors.error.withValues(alpha: 0.6)),
              padding: const EdgeInsets.symmetric(
                horizontal: Dimens.largePadding,
                vertical: Dimens.padding,
              ),
              minimumSize: const Size(0, 36),
            ),
            child: const Text('Siparişi Reddet'),
          ),
        if (_courierOrderAssignedToMe(order)) ...[
          OutlinedButton(
            onPressed: () async {
              final reason = await _showCourierRejectReasonDialog(
                context,
                orderId: order.id,
                isPoolReject: false,
              );
              if (reason == null || !context.mounted) return;
              try {
                await cubit.rejectAssignment(order.id, reason);
                if (!context.mounted) return;
                tabController.animateTo(3);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Görev reddedildi.')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Reddedilemedi: $e')));
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              side: BorderSide(color: colors.error.withValues(alpha: 0.6)),
              padding: const EdgeInsets.symmetric(
                horizontal: Dimens.largePadding,
                vertical: Dimens.padding,
              ),
              minimumSize: const Size(0, 36),
            ),
            child: const Text('Görevi Reddet'),
          ),
        ],
      ];
    }
    if (status == CourierOrderStatus.pickedUp) {
      return [
        FilledButton(
          onPressed: () async {
            try {
              await cubit.markInTransit(order.id);
              if (!context.mounted) return;
              tabController.animateTo(1);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sipariş #${order.id} yola çıktı')),
              );
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Durum güncellenemedi: $e')),
              );
            }
          },
          style: buttonStyle,
          child: const Text('Yola Çıktım'),
        ),
        if (_courierOrderAssignedToMe(order))
          OutlinedButton(
            onPressed: () async {
              final reason = await _showCourierRejectReasonDialog(
                context,
                orderId: order.id,
                isPoolReject: false,
              );
              if (reason == null || !context.mounted) return;
              try {
                await cubit.rejectAssignment(order.id, reason);
                if (!context.mounted) return;
                tabController.animateTo(3);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Görev reddedildi.')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Reddedilemedi: $e')));
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              side: BorderSide(color: colors.error.withValues(alpha: 0.6)),
              padding: const EdgeInsets.symmetric(
                horizontal: Dimens.largePadding,
                vertical: Dimens.padding,
              ),
              minimumSize: const Size(0, 36),
            ),
            child: const Text('Görevi Reddet'),
          ),
      ];
    }
    if (status == CourierOrderStatus.inTransit) {
      return [
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder:
                    (_) => MultiBlocProvider(
                      providers: [
                        BlocProvider.value(value: cubit),
                        BlocProvider.value(
                          value: context.read<CourierLocationCubit>(),
                        ),
                      ],
                      child: CourierTrackingScreen(selectedOrder: order),
                    ),
              ),
            );
          },
          icon: const Icon(Icons.map, size: 18),
          label: const Text('Canlı Takip'),
          style: buttonStyle,
        ),
        FilledButton(
          onPressed: () async {
            try {
              await cubit.markDelivered(order.id);
              await cubit.loadOrders();
              if (!context.mounted) return;
              tabController.animateTo(2);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sipariş #${order.id} teslim edildi')),
              );
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Teslim durumu kaydedilemedi: $e')),
              );
            }
          },
          style: buttonStyle.copyWith(
            backgroundColor: WidgetStateProperty.all(colors.success),
          ),
          child: const Text('Teslim Ettim'),
        ),
      ];
    }
    return [];
  }

  Color _statusColor(CourierOrderStatus s) {
    switch (s) {
      case CourierOrderStatus.assigned:
        return const Color(0xFFFFA726);
      case CourierOrderStatus.pickedUp:
        return const Color(0xFF42A5F5);
      case CourierOrderStatus.inTransit:
        return const Color(0xFF42A5F5);
      case CourierOrderStatus.delivered:
        return const Color(0xFF66BB6A);
    }
  }

  String _statusText(CourierOrderStatus s) {
    switch (s) {
      case CourierOrderStatus.assigned:
        return 'Bekliyor';
      case CourierOrderStatus.pickedUp:
        return 'Alındı';
      case CourierOrderStatus.inTransit:
        return 'Yolda';
      case CourierOrderStatus.delivered:
        return 'Teslim Edildi';
    }
  }
}

Future<String?> _showCourierRejectReasonDialog(
  BuildContext context, {
  required String orderId,
  bool isPoolReject = false,
}) async {
  final controller = TextEditingController();
  final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
  try {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final colors = dialogContext.theme.appColors;
        final typography = dialogContext.theme.appTypography;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: Dimens.largePadding,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Dimens.extraLargePadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPoolReject ? 'Siparişi reddet' : 'Görevi reddet',
                  style: typography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: Dimens.smallPadding),
                Text(
                  isPoolReject
                      ? 'Havuzdaki sipariş #$shortId için nedeniniz pastane ve '
                          'müşteriye bildirim olarak gider (3–600 karakter).'
                      : 'Sipariş #$shortId için reddetme nedeniniz pastane ve '
                          'müşteriye bildirim olarak gider (3–600 karakter).',
                  style: typography.bodySmall.copyWith(color: colors.gray4),
                ),
                const SizedBox(height: Dimens.largePadding),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText:
                        'Örn: Araç arızası / Bölgeye gidemiyorum / Sağlık',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Dimens.corners),
                    ),
                  ),
                ),
                const SizedBox(height: Dimens.extraLargePadding),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(null),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: colors.gray.withValues(alpha: 0.6),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: Dimens.padding,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Dimens.corners),
                          ),
                        ),
                        child: const Text('Vazgeç'),
                      ),
                    ),
                    const SizedBox(width: Dimens.padding),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final text = controller.text.trim();
                          if (text.length < 3) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text('En az 3 karakter yazın.'),
                              ),
                            );
                            return;
                          }
                          if (text.length > 600) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text('En fazla 600 karakter.'),
                              ),
                            );
                            return;
                          }
                          Navigator.of(dialogContext).pop(text);
                        },
                        child: const Text('Reddet'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  } finally {
    controller.dispose();
  }
}
