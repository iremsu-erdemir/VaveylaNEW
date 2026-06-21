import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/modern_order_card.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_button.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/customer_order_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/services/customer_order_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/customer_orders_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/customer_order_detail_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/customer_order_tracking_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/bloc/cart_cubit.dart';

import '../../../../core/theme/dimens.dart';

enum OrderType { active, completed, canceled }

class OrdersListWidget extends StatelessWidget {
  const OrdersListWidget({super.key, required this.orderType});

  final OrderType orderType;

  @override
  Widget build(BuildContext context) {
    final appColors = context.theme.appColors;
    return BlocBuilder<CustomerOrdersCubit, CustomerOrdersState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.error != null && state.error!.trim().isNotEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimens.largePadding),
              child: Text(
                'Siparişler yüklenemedi: ${state.error}',
                textAlign: TextAlign.center,
                style: context.theme.appTypography.bodyMedium.copyWith(
                  color: appColors.error,
                ),
              ),
            ),
          );
        }

        final filteredOrders = state.orders
            .where((order) => _matchesTab(order.status, orderType))
            .toList();

        if (filteredOrders.isEmpty) {
          return Center(
            child: Text(
              'Sipariş bulunamadı',
              style: context.theme.appTypography.bodyMedium.copyWith(
                color: appColors.gray4,
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => context.read<CustomerOrdersCubit>().loadOrders(),
          child: ListView.separated(
            itemCount: filteredOrders.length,
            itemBuilder: (final context, final index) {
              final order = filteredOrders[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimens.largePadding,
                ),
                child: ModernOrderCard(
                  productName: order.items,
                  price: order.total,
                  imageUrl: order.imagePath,
                  quantity: 1,
                  dateTime: '${order.date} • ${order.time}',
                  status: _statusText(order.status),
                  statusColor: _statusColor(order.status, appColors),
                  actionButton: _buildActionButton(
                    context,
                    order,
                    appColors,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CustomerOrderDetailScreen(
                          orderId: order.id,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            separatorBuilder: (final context, final index) {
              return const SizedBox(height: Dimens.largePadding);
            },
          ),
        );
      },
    );
  }

  bool _matchesTab(CustomerOrderStatus status, OrderType tab) {
    switch (tab) {
      case OrderType.active:
        return status == CustomerOrderStatus.pending ||
            status == CustomerOrderStatus.preparing ||
            status == CustomerOrderStatus.awaitingCourier ||
            status == CustomerOrderStatus.assigned ||
            status == CustomerOrderStatus.inTransit;
      case OrderType.completed:
        return status == CustomerOrderStatus.completed;
      case OrderType.canceled:
        return status == CustomerOrderStatus.canceled ||
            status == CustomerOrderStatus.refundRequested;
    }
  }

  String _statusText(CustomerOrderStatus status) {
    switch (status) {
      case CustomerOrderStatus.pending:
        return 'Bekliyor';
      case CustomerOrderStatus.preparing:
        return 'Hazırlanıyor';
      case CustomerOrderStatus.awaitingCourier:
        return 'Kurye atanması bekleniyor';
      case CustomerOrderStatus.assigned:
        return 'Kurye atandı';
      case CustomerOrderStatus.inTransit:
        return 'Yolda';
      case CustomerOrderStatus.completed:
        return 'Siparis teslim edildi';
      case CustomerOrderStatus.canceled:
        return 'İptal edildi';
      case CustomerOrderStatus.refundRequested:
        return 'İade talebi';
    }
  }

  Color _statusColor(CustomerOrderStatus status, dynamic appColors) {
    switch (status) {
      case CustomerOrderStatus.pending:
      case CustomerOrderStatus.preparing:
      case CustomerOrderStatus.awaitingCourier:
      case CustomerOrderStatus.assigned:
      case CustomerOrderStatus.inTransit:
        return appColors.primary;
      case CustomerOrderStatus.completed:
        return appColors.success;
      case CustomerOrderStatus.canceled:
      case CustomerOrderStatus.refundRequested:
        return appColors.error;
    }
  }

  Widget? _buildActionButton(
    BuildContext context,
    CustomerOrderModel order,
    dynamic appColors,
  ) {
    final status = order.status;
    return SizedBox(
      width: 96,
      height: 32,
      child: AppButton(
        title: status == CustomerOrderStatus.completed
            ? 'Tekrarla'
            : status == CustomerOrderStatus.canceled ||
                status == CustomerOrderStatus.refundRequested
            ? 'Detay'
            : status == CustomerOrderStatus.inTransit
            ? 'Takip et'
            : 'Detay',
        color: status == CustomerOrderStatus.completed
            ? appColors.successLight
            : status == CustomerOrderStatus.canceled
            ? appColors.error
            : appColors.primary,
        textStyle: context.theme.appTypography.labelMedium.copyWith(
          color: status == CustomerOrderStatus.completed
              ? appColors.success
              : appColors.white,
          fontWeight: FontWeight.w600,
        ),
        borderRadius: 12,
        margin: EdgeInsets.zero,
        padding: WidgetStateProperty.all<EdgeInsets>(
          const EdgeInsets.symmetric(horizontal: Dimens.padding),
        ),
        onPressed: () {
          if (status == CustomerOrderStatus.completed) {
            _reorder(context, order);
            return;
          }
          if (status == CustomerOrderStatus.inTransit ||
              status == CustomerOrderStatus.assigned ||
              status == CustomerOrderStatus.preparing) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider.value(
                  value: context.read<CustomerOrdersCubit>(),
                  child: CustomerOrderTrackingScreen(orderId: order.id),
                ),
              ),
            );
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CustomerOrderDetailScreen(orderId: order.id),
            ),
          );
        },
      ),
    );
  }

  Future<void> _reorder(BuildContext context, CustomerOrderModel order) async {
    try {
      final result = await CustomerOrderService().reorder(
        customerUserId: AppSession.userId,
        orderId: order.id,
      );
      if (!context.mounted) return;
      context.read<CartCubit>().loadCart();
      final unavailable =
          (result['unavailableProducts'] as List?)?.cast<String>() ?? [];
      var msg = 'Ürünler sepete eklendi.';
      if (unavailable.isNotEmpty) {
        msg += ' Stokta yok: ${unavailable.join(', ')}';
      }
      context.showSuccessMessage(msg);
    } catch (e) {
      if (context.mounted) context.showErrorMessage(e);
    }
  }

}
