import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/formatters.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/order_detail_model.dart';

class CustomerOrderInvoiceScreen extends StatelessWidget {
  const CustomerOrderInvoiceScreen({super.key, required this.order});

  final OrderDetailModel order;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    final customerName = AppSession.fullName.trim();

    return AppScaffold(
      appBar: GeneralAppBar(title: 'Fatura'),
      body: ListView(
        padding: const EdgeInsets.all(Dimens.largePadding),
        children: [
          _invoiceHeader(colors, typography),
          const SizedBox(height: Dimens.largePadding),
          _infoBlock(
            colors,
            typography,
            title: 'Satıcı',
            lines: [
              order.restaurantName ?? 'Pastane',
              'Vaveyla Sipariş Platformu',
            ],
          ),
          const SizedBox(height: 12),
          _infoBlock(
            colors,
            typography,
            title: 'Alıcı',
            lines: [
              if (customerName.isNotEmpty) customerName else 'Müşteri',
              if (order.deliveryAddress != null) order.deliveryAddress!,
              if (order.deliveryAddressDetail != null &&
                  order.deliveryAddressDetail!.isNotEmpty)
                order.deliveryAddressDetail!,
            ],
          ),
          const SizedBox(height: Dimens.largePadding),
          _sectionTitle('Kalemler', typography),
          const SizedBox(height: 8),
          ...order.lineItems.map(
            (item) => _lineRow(item, colors, typography),
          ),
          const SizedBox(height: Dimens.largePadding),
          _totalsCard(order, colors, typography),
          const SizedBox(height: Dimens.largePadding),
          Text(
            'Bu belge bilgilendirme amaçlıdır. Resmi e-fatura değildir.',
            style: typography.bodySmall.copyWith(color: colors.gray4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _invoiceHeader(dynamic colors, dynamic typography) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimens.largePadding),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SİPARİŞ FATURASI',
            style: typography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _metaRow('Sipariş No', '#${order.orderNumber}', typography),
          _metaRow(
            'Fatura Tarihi',
            '${formatDate(order.createdAtUtc)} ${formatTime(order.createdAtUtc)}',
            typography,
          ),
          if (order.paymentMethod != null)
            _metaRow('Ödeme Yöntemi', order.paymentMethod!, typography),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value, dynamic typography) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: typography.bodySmall.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value, style: typography.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _infoBlock(
    dynamic colors,
    dynamic typography, {
    required String title,
    required List<String> lines,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimens.padding),
      decoration: BoxDecoration(
        color: colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.gray.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typography.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 6),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(line, style: typography.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, dynamic typography) {
    return Text(
      title,
      style: typography.titleSmall.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _lineRow(
    OrderLineItemModel item,
    dynamic colors,
    dynamic typography,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.gray.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
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
                  '${item.quantityLabel} × ${formatPrice(item.unitPrice)}',
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

  Widget _totalsCard(
    OrderDetailModel order,
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
        children: [
          _totalRow('Ara toplam', order.subtotal, typography),
          _totalRow('Teslimat ücreti', order.deliveryFee, typography),
          if (order.totalDiscount > 0)
            _totalRow(
              'İndirim',
              -order.totalDiscount,
              typography,
              valueColor: colors.success,
            ),
          if (order.couponDiscount > 0)
            _totalRow(
              'Kupon indirimi',
              -order.couponDiscount,
              typography,
              valueColor: colors.success,
            ),
          const Divider(height: 24),
          _totalRow(
            'Ödenecek tutar (KDV dahil)',
            order.total,
            typography,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _totalRow(
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
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
