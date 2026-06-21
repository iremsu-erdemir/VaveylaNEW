import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/formatters.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/order_status_chip.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/skeleton_box.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/order_detail_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/services/customer_order_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/customer_order_detail_screen.dart';

class RefundRequestsScreen extends StatefulWidget {
  const RefundRequestsScreen({super.key});

  @override
  State<RefundRequestsScreen> createState() => _RefundRequestsScreenState();
}

class _RefundRequestsScreenState extends State<RefundRequestsScreen> {
  final CustomerOrderService _service = CustomerOrderService();
  List<RefundRequestModel> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _service.getRefundRequests(
        customerUserId: AppSession.userId,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      context.showErrorMessage(e);
    }
  }

  Color _statusColor(String status, dynamic colors) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'completed':
        return colors.success;
      case 'rejected':
        return colors.error;
      default:
        return colors.primary;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Bekliyor';
      case 'approved':
        return 'Onaylandı';
      case 'rejected':
        return 'Reddedildi';
      case 'completed':
        return 'Tamamlandı';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return AppScaffold(
      appBar: GeneralAppBar(title: 'İade Taleplerim'),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(Dimens.largePadding),
              children: const [
                SkeletonBox(height: 100, borderRadius: 16),
                SizedBox(height: 12),
                SkeletonBox(height: 100, borderRadius: 16),
              ],
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: Center(
                            child: Text(
                              'İade talebi bulunmuyor',
                              style: typography.bodyMedium.copyWith(
                                color: colors.gray4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(Dimens.largePadding),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => CustomerOrderDetailScreen(
                                  orderId: item.orderId,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(Dimens.largePadding),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colors.gray.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.restaurantName ?? 'Pastane',
                                        style: typography.bodyLarge.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    OrderStatusChip(
                                      label: _statusLabel(item.status),
                                      color: _statusColor(item.status, colors),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Sipariş #${item.orderNumber}',
                                  style: typography.bodySmall,
                                ),
                                Text(
                                  formatDate(item.createdAtUtc),
                                  style: typography.bodySmall.copyWith(
                                    color: colors.gray4,
                                  ),
                                ),
                                if (item.reasonNote != null) ...[
                                  const SizedBox(height: 8),
                                  Text(item.reasonNote!),
                                ],
                                if (item.restaurantResponse != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Yanıt: ${item.restaurantResponse}',
                                    style: typography.bodySmall.copyWith(
                                      color: colors.primary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
