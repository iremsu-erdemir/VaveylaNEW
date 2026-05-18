import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/profanity_validator.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/modern_order_card.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_button.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/customer_order_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/reviewable_order_item_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/services/customer_order_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/services/customer_review_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/customer_orders_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/customer_order_tracking_screen.dart';

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
                  onTap: () {},
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
        return status == CustomerOrderStatus.canceled;
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
            ? 'Yorumla'
            : status == CustomerOrderStatus.canceled
            ? 'İptal'
            : status == CustomerOrderStatus.inTransit
            ? 'Takip et'
            : 'Teslimat',
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
        onPressed: status == CustomerOrderStatus.completed
            ? () => _showOrderReviewSheet(context, order)
            : status == CustomerOrderStatus.canceled
            ? () {}
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BlocProvider.value(
                      value: context.read<CustomerOrdersCubit>(),
                      child: CustomerOrderTrackingScreen(orderId: order.id),
                    ),
                  ),
                );
              },
      ),
    );
  }

  Future<void> _showOrderReviewSheet(
    BuildContext context,
    CustomerOrderModel order,
  ) async {
    final reviewService = CustomerReviewService();
    final orderService = CustomerOrderService();
    final userId = AppSession.userId;
    if (userId.isEmpty || order.restaurantId.isEmpty) {
      if (!context.mounted) return;
      context.showErrorMessage('Değerlendirme için sipariş bilgisi eksik.');
      return;
    }

    List<ReviewableOrderItemModel> reviewableProducts = const [];
    try {
      reviewableProducts = await orderService.getReviewableProducts(
        customerUserId: userId,
        orderId: order.id,
      );
    } catch (e) {
      if (!context.mounted) return;
      context.showErrorMessage('Ürünler yüklenemedi: $e');
      return;
    }
    if (reviewableProducts.isEmpty) {
      if (!context.mounted) return;
      context.showErrorMessage('Bu siparişte yorumlanabilir ürün bulunamadı.');
      return;
    }

    final ratings = <String, int>{
      for (final product in reviewableProducts) product.id: 5,
    };
    final controllers = <String, TextEditingController>{
      for (final product in reviewableProducts) product.id: TextEditingController(),
    };

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: Dimens.largePadding,
            right: Dimens.largePadding,
            top: Dimens.largePadding,
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom + Dimens.largePadding,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.75,
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sipariş Ürünlerini Değerlendir',
                    style: context.theme.appTypography.titleMedium,
                  ),
                  const SizedBox(height: Dimens.padding),
                  Expanded(
                    child: ListView.separated(
                      itemCount: reviewableProducts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: Dimens.padding),
                      itemBuilder: (context, index) {
                        final product = reviewableProducts[index];
                        final currentRating = ratings[product.id] ?? 5;
                        return Container(
                          padding: const EdgeInsets.all(Dimens.padding),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: context.theme.appColors.gray.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: context.theme.appTypography.titleSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Row(
                                children: List.generate(5, (starIndex) {
                                  final star = starIndex + 1;
                                  return IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(
                                      star <= currentRating
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                    ),
                                    onPressed: () => setSheetState(
                                      () => ratings[product.id] = star,
                                    ),
                                  );
                                }),
                              ),
                              TextField(
                                controller: controllers[product.id],
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  hintText: 'Bu ürün için yorumunuz',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: Dimens.padding),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      title: 'Tum Yorumlari Gonder',
                      margin: EdgeInsets.zero,
                      onPressed: () async {
                        final hasEmptyComment = reviewableProducts.any((product) {
                          final comment = controllers[product.id]?.text.trim() ?? '';
                          return comment.isEmpty;
                        });
                        if (hasEmptyComment) {
                          if (!context.mounted) return;
                          context.showErrorMessage('Lutfen tum urunler icin yorum yazin.');
                          return;
                        }

                        for (final product in reviewableProducts) {
                          final comment = controllers[product.id]?.text.trim() ?? '';
                          final profanityError =
                              ProfanityValidator.validateOrNull(comment);
                          if (profanityError != null) {
                            if (!context.mounted) return;
                            context.showErrorMessage(profanityError);
                            return;
                          }
                        }

                        try {
                          for (final product in reviewableProducts) {
                            await reviewService.createReview(
                              customerUserId: userId,
                              restaurantId: order.restaurantId,
                              targetType: 'menu',
                              targetId: product.id,
                              rating: ratings[product.id] ?? 5,
                              comment: controllers[product.id]!.text.trim(),
                              customerName: AppSession.fullName,
                            );
                          }
                          if (!context.mounted) return;
                          Navigator.of(sheetContext).pop();
                          context.showSuccessMessage(
                            'Siparisteki tum urun yorumlari kaydedildi.',
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          context.showErrorMessage(error);
                        }
                      },
                    ),
                  ),
                ],
              ),
              );
            },
          ),
        );
      },
    );

    for (final controller in controllers.values) {
      controller.dispose();
    }
  }
}
