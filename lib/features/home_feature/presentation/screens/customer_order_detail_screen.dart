import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart' show AppFeedbackExtension;
import 'package:flutter_sweet_shop_app_ui/core/utils/formatters.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_button.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/order_status_chip.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/skeleton_box.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/order_detail_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/services/customer_order_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/bloc/cart_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/customer_order_invoice_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/feedback_screen.dart';

class CustomerOrderDetailScreen extends StatefulWidget {
  const CustomerOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<CustomerOrderDetailScreen> createState() =>
      _CustomerOrderDetailScreenState();
}

class _CustomerOrderDetailScreenState extends State<CustomerOrderDetailScreen> {
  final CustomerOrderService _service = CustomerOrderService();
  OrderDetailModel? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _service.getOrderDetail(
        customerUserId: AppSession.userId,
        orderId: widget.orderId,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _statusColor(String status, dynamic appColors) {
    switch (status) {
      case 'completed':
        return appColors.success;
      case 'canceled':
      case 'refundRequested':
        return appColors.error;
      case 'inTransit':
      case 'assigned':
        return appColors.primary;
      default:
        return appColors.warning ?? appColors.primary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Bekliyor';
      case 'preparing':
        return 'Hazırlanıyor';
      case 'inTransit':
        return 'Yolda';
      case 'assigned':
        return 'Kurye atandı';
      case 'awaitingCourier':
        return 'Kurye bekleniyor';
      case 'completed':
        return 'Teslim edildi';
      case 'canceled':
        return 'İptal edildi';
      case 'refundRequested':
        return 'İade talebi';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return AppScaffold(
      appBar: GeneralAppBar(title: 'Sipariş Detayı'),
      body: _loading
          ? _buildSkeleton()
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Dimens.largePadding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        AppButton(
                          title: 'Tekrar Dene',
                          onPressed: _load,
                          margin: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                )
              : _detail == null
                  ? const Center(child: Text('Sipariş bulunamadı'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(Dimens.largePadding),
                        children: [
                          _headerCard(_detail!, colors, typography),
                          const SizedBox(height: Dimens.largePadding),
                          _sectionTitle('Ürünler', typography),
                          ..._detail!.lineItems.map(
                            (item) => _lineItemTile(item, colors, typography),
                          ),
                          const SizedBox(height: Dimens.largePadding),
                          _priceCard(_detail!, colors, typography),
                          if (_detail!.statusHistory.isNotEmpty) ...[
                            const SizedBox(height: Dimens.largePadding),
                            _sectionTitle('Durum Geçmişi', typography),
                            ..._detail!.statusHistory.map(
                              (h) => _historyTile(h, colors, typography),
                            ),
                          ],
                          const SizedBox(height: Dimens.largePadding),
                          _actions(_detail!),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(Dimens.largePadding),
      children: const [
        SkeletonBox(height: 120, borderRadius: 16),
        SizedBox(height: 16),
        SkeletonBox(height: 80),
        SizedBox(height: 8),
        SkeletonBox(height: 80),
        SizedBox(height: 16),
        SkeletonBox(height: 140, borderRadius: 16),
      ],
    );
  }

  Widget _headerCard(
    OrderDetailModel d,
    dynamic colors,
    dynamic typography,
  ) {
    return Container(
      padding: const EdgeInsets.all(Dimens.largePadding),
      decoration: BoxDecoration(
        color: colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.gray.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  d.restaurantName ?? 'Pastane',
                  style: typography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OrderStatusChip(
                label: _statusLabel(d.status),
                color: _statusColor(d.status, colors),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Sipariş #${d.orderNumber}', style: typography.bodySmall),
          Text(
            '${formatDate(d.createdAtUtc)} ${formatTime(d.createdAtUtc)}',
            style: typography.bodySmall.copyWith(color: colors.gray4),
          ),
          if (d.deliveryAddress != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: colors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${d.deliveryAddress}${d.deliveryAddressDetail != null ? '\n${d.deliveryAddressDetail}' : ''}',
                    style: typography.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
          if (d.courierName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.delivery_dining, size: 18, color: colors.primary),
                const SizedBox(width: 6),
                Text('Kurye: ${d.courierName}', style: typography.bodyMedium),
              ],
            ),
          ],
          if (d.paymentMethod != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.payment, size: 18, color: colors.primary),
                const SizedBox(width: 6),
                Text(d.paymentMethod!, style: typography.bodyMedium),
              ],
            ),
          ],
          if (d.orderNotes != null && d.orderNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Not: ${d.orderNotes}', style: typography.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _lineItemTile(
    OrderLineItemModel item,
    dynamic colors,
    dynamic typography,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: item.imagePath != null && item.imagePath!.isNotEmpty
                ? Image.network(
                    item.imagePath!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholder(colors),
                  )
                : _imagePlaceholder(colors),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: typography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${item.quantityLabel} · ${formatPrice(item.unitPrice)}',
                  style: typography.bodySmall.copyWith(color: colors.gray4),
                ),
              ],
            ),
          ),
          Text(
            formatPrice(item.lineTotal),
            style: typography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(dynamic colors) {
    return Container(
      width: 64,
      height: 64,
      color: colors.gray.withValues(alpha: 0.2),
      child: Icon(Icons.cake_outlined, color: colors.gray4),
    );
  }

  Widget _priceCard(OrderDetailModel d, dynamic colors, dynamic typography) {
    return Container(
      padding: const EdgeInsets.all(Dimens.largePadding),
      decoration: BoxDecoration(
        color: colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.gray.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _priceRow('Ürün toplamı', d.subtotal, typography),
          _priceRow('Teslimat ücreti', d.deliveryFee, typography),
          if (d.totalDiscount > 0)
            _priceRow(
              'İndirim',
              -d.totalDiscount,
              typography,
              valueColor: colors.success,
            ),
          if (d.couponDiscount > 0)
            _priceRow(
              'Kupon indirimi',
              -d.couponDiscount,
              typography,
              valueColor: colors.success,
            ),
          const Divider(height: 24),
          _priceRow(
            'Toplam',
            d.total,
            typography,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _priceRow(
    String label,
    double value,
    dynamic typography, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: (isBold ? typography.bodyLarge : typography.bodyMedium)
                .copyWith(fontWeight: isBold ? FontWeight.w700 : null),
          ),
          Text(
            formatPrice(value),
            style: (isBold ? typography.bodyLarge : typography.bodyMedium)
                .copyWith(
              fontWeight: isBold ? FontWeight.w700 : null,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyTile(
    OrderStatusHistoryModel h,
    dynamic colors,
    dynamic typography,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel(h.status),
                  style: typography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (h.note != null)
                  Text(h.note!, style: typography.bodySmall),
                Text(
                  '${formatDate(h.createdAtUtc)} ${formatTime(h.createdAtUtc)}',
                  style: typography.labelSmall.copyWith(color: colors.gray4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, dynamic typography) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: typography.titleSmall.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _actions(OrderDetailModel d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (d.canReorder)
          AppButton(
            title: 'Tekrar Sipariş Ver',
            onPressed: () => _reorder(d),
            margin: EdgeInsets.zero,
          ),
        if (d.canCancel) ...[
          const SizedBox(height: 8),
          AppButton(
            title: 'Siparişi İptal Et',
            color: context.theme.appColors.error,
            textStyle: context.theme.appTypography.labelLarge.copyWith(
              color: context.theme.appColors.white,
            ),
            onPressed: () => _cancelOrder(d),
            margin: EdgeInsets.zero,
          ),
        ],
        if (d.canRequestRefund) ...[
          const SizedBox(height: 8),
          AppButton(
            title: 'İade Talebi Oluştur',
            onPressed: () => _refundRequest(d),
            margin: EdgeInsets.zero,
          ),
        ],
        if (d.status == 'completed') ...[
          const SizedBox(height: 8),
          AppButton(
            title: 'Ürünleri Değerlendir',
            color: context.theme.appColors.successLight,
            textStyle: context.theme.appTypography.labelLarge.copyWith(
              color: context.theme.appColors.success,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FeedbackScreen(
                    prefilledOrderId: d.id,
                  ),
                ),
              );
            },
            margin: EdgeInsets.zero,
          ),
        ],
        const SizedBox(height: 8),
        AppButton(
          title: 'Destek Talebi Oluştur',
          color: context.theme.appColors.error,
          textStyle: context.theme.appTypography.labelLarge.copyWith(
            color: context.theme.appColors.white,
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FeedbackScreen()),
            );
          },
          margin: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        AppButton(
          title: 'Fatura Görüntüle',
          color: context.theme.appColors.primary.withValues(alpha: 0.15),
          textStyle: context.theme.appTypography.labelLarge.copyWith(
            color: context.theme.appColors.primary,
          ),
          onPressed: () => _viewInvoice(d),
          margin: EdgeInsets.zero,
        ),
      ],
    );
  }

  Future<void> _reorder(OrderDetailModel d) async {
    try {
      final result = await _service.reorder(
        customerUserId: AppSession.userId,
        orderId: d.id,
      );
      if (!mounted) return;
      context.read<CartCubit>().loadCart();
      final unavailable = (result['unavailableProducts'] as List?)?.cast<String>() ?? [];
      final warnings = (result['warnings'] as List?)?.cast<String>() ?? [];
      var msg = 'Ürünler sepete eklendi.';
      if (unavailable.isNotEmpty) {
        msg += '\nStokta yok: ${unavailable.join(', ')}';
      }
      if (warnings.isNotEmpty) {
        msg += '\n${warnings.join('\n')}';
      }
      context.showSuccessMessage(msg);
    } catch (e) {
      if (mounted) context.showErrorMessage(e);
    }
  }

  Future<void> _cancelOrder(OrderDetailModel d) async {
    final reason = await _showReasonSheet(
      title: 'İptal sebebi',
      confirmLabel: 'İptal Et',
    );
    if (reason == null) return;
    try {
      await _service.cancelOrder(
        customerUserId: AppSession.userId,
        orderId: d.id,
        reason: reason.$1,
        reasonNote: reason.$2,
      );
      if (!mounted) return;
      context.showSuccessMessage('Sipariş iptal edildi.');
      _load();
    } catch (e) {
      if (mounted) context.showErrorMessage(e);
    }
  }

  Future<void> _refundRequest(OrderDetailModel d) async {
    final reason = await _showReasonSheet(
      title: 'İade sebebi',
      confirmLabel: 'İade Talebi Gönder',
    );
    if (reason == null) return;
    try {
      await _service.createRefundRequest(
        customerUserId: AppSession.userId,
        orderId: d.id,
        reason: reason.$1,
        reasonNote: reason.$2,
      );
      if (!mounted) return;
      context.showSuccessMessage('İade talebiniz alındı.');
      _load();
    } catch (e) {
      if (mounted) context.showErrorMessage(e);
    }
  }

  Future<(int, String?)?> _showReasonSheet({
    required String title,
    required String confirmLabel,
  }) async {
    int selected = 1;
    final noteController = TextEditingController();
    return showModalBottomSheet<(int, String?)>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: context.theme.appTypography.titleMedium),
                  const SizedBox(height: 12),
                  ..._reasonOptions.entries.map(
                    (e) => RadioListTile<int>(
                      value: e.key,
                      groupValue: selected,
                      onChanged: (v) => setModalState(() => selected = v!),
                      title: Text(e.value),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama (opsiyonel)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    title: confirmLabel,
                    margin: EdgeInsets.zero,
                    onPressed: () {
                      Navigator.pop(
                        ctx,
                        (
                          selected,
                          noteController.text.trim().isEmpty
                              ? null
                              : noteController.text.trim(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static const _reasonOptions = {
    1: 'Fikrimi değiştirdim',
    2: 'Yanlış sipariş',
    3: 'Geç teslimat',
    4: 'Kalite sorunu',
    99: 'Diğer',
  };

  void _viewInvoice(OrderDetailModel d) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerOrderInvoiceScreen(order: d),
      ),
    );
  }
}
