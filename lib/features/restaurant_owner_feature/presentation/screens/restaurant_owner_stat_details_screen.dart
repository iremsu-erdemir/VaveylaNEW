import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/formatters.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/modern_order_card.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/models/menu_item_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/models/order_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/presentation/bloc/restaurant_menu_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/presentation/bloc/restaurant_orders_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/widgets/product_image_widget.dart';

enum StatDetailType { pendingOrders, todayOrders, totalRevenue, menuItems }

class RestaurantOwnerStatDetailsScreen extends StatelessWidget {
  const RestaurantOwnerStatDetailsScreen({super.key, required this.type});

  final StatDetailType type;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: GeneralAppBar(title: _titleFor(type)),
      body:
          type == StatDetailType.menuItems
              ? BlocBuilder<RestaurantMenuCubit, List<MenuItemModel>>(
                builder: (context, menuItems) {
                  if (menuItems.isEmpty) {
                    return _EmptyState(message: 'Henüz ürün yok');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(Dimens.largePadding),
                    itemCount: menuItems.length,
                    separatorBuilder:
                        (_, __) => const SizedBox(height: Dimens.largePadding),
                    itemBuilder: (context, index) {
                      final item = menuItems[index];
                      return _MenuItemCard(item: item);
                    },
                  );
                },
              )
              : BlocBuilder<RestaurantOrdersCubit, List<RestaurantOrderModel>>(
                builder: (context, orders) {
                  final filtered = _filterOrders(type, orders);
                  if (filtered.isEmpty) {
                    return _EmptyState(message: 'Henüz sipariş yok');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(Dimens.largePadding),
                    itemCount: filtered.length,
                    separatorBuilder:
                        (_, __) => const SizedBox(height: Dimens.largePadding),
                    itemBuilder: (context, index) {
                      final order = filtered[index];
                      return _OrderCard(order: order);
                    },
                  );
                },
              ),
    );
  }

  static String _titleFor(StatDetailType type) {
    switch (type) {
      case StatDetailType.pendingOrders:
        return 'Bekleyen Siparişler';
      case StatDetailType.todayOrders:
        return 'Siparişler';
      case StatDetailType.totalRevenue:
        return 'Toplam Gelir';
      case StatDetailType.menuItems:
        return 'Menü Ürünleri';
    }
  }

  static List<RestaurantOrderModel> _filterOrders(
    StatDetailType type,
    List<RestaurantOrderModel> orders,
  ) {
    switch (type) {
      case StatDetailType.pendingOrders:
        return orders
            .where((o) => o.status == RestaurantOrderStatus.pending)
            .toList();
      case StatDetailType.totalRevenue:
        return orders
            .where((o) => o.status == RestaurantOrderStatus.completed)
            .toList();
      case StatDetailType.todayOrders:
      case StatDetailType.menuItems:
        return orders;
    }
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final RestaurantOrderModel order;

  @override
  Widget build(BuildContext context) {
    return ModernOrderCard(
      productName: order.items,
      price: order.total,
      imageUrl:
          order.imagePath.isNotEmpty
              ? order.imagePath
              : 'assets/images/logo.png', // Fallback to logo asset
      dateTime: _formatDateTime(),
      status: _statusText(order.status),
      statusColor: _statusColor(order.status),
      statusOnBottomRight: true,
      dateTimeTopSpacing: 10,
      onTap: () {
        // Handle order card tap if needed
      },
    );
  }

  String _formatDateTime() {
    // Combine date and time in the required format
    if (order.date.isNotEmpty && order.time.isNotEmpty) {
      return '${order.date} • ${order.time}';
    } else if (order.time.isNotEmpty) {
      return order.time;
    } else if (order.date.isNotEmpty) {
      return order.date;
    }
    return '';
  }

  Color _statusColor(RestaurantOrderStatus status) {
    switch (status) {
      case RestaurantOrderStatus.pending:
        return const Color(0xFFFFA726);
      case RestaurantOrderStatus.preparing:
        return const Color(0xFF42A5F5);
      case RestaurantOrderStatus.completed:
        return const Color(0xFF66BB6A);
      case RestaurantOrderStatus.rejected:
        return const Color(0xFFEF5350);
    }
  }

  String _statusText(RestaurantOrderStatus status) {
    switch (status) {
      case RestaurantOrderStatus.pending:
        return 'Bekliyor';
      case RestaurantOrderStatus.preparing:
        return 'Hazırlanıyor';
      case RestaurantOrderStatus.completed:
        return 'Tamamlandı';
      case RestaurantOrderStatus.rejected:
        return 'Reddedildi';
    }
  }
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({required this.item});

  final MenuItemModel item;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    final accent = item.isAvailable ? colors.success : colors.error;
    return Container(
      padding: const EdgeInsets.all(Dimens.largePadding),
      decoration: BoxDecoration(
        color: colors.white,
        borderRadius: BorderRadius.circular(Dimens.corners),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Dimens.corners),
            child: buildProductImage(item.imagePath, 76, 76),
          ),
          const SizedBox(width: Dimens.largePadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: typography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: item.isAvailable ? colors.black : colors.gray4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Dimens.smallPadding),
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
                    formatPrice(item.price),
                    style: typography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimens.padding,
              vertical: Dimens.smallPadding,
            ),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item.isAvailable ? 'Aktif' : 'Pasif',
              style: typography.labelSmall.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: colors.gray4),
          const SizedBox(height: Dimens.largePadding),
          Text(
            message,
            style: typography.bodyLarge.copyWith(color: colors.gray4),
          ),
        ],
      ),
    );
  }
}
