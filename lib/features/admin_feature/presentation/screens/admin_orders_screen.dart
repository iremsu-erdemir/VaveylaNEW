import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/formatters.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/modern_order_card.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/data/services/admin_service.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  double _totalRevenue = 0;
  double _totalDiscount = 0;
  double _totalPlatformEarning = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _adminService.getOrders(take: 100);
      if (!mounted) return;
      double rev = 0;
      double disc = 0;
      double plat = 0;
      final maps = <Map<String, dynamic>>[];
      for (final o in list) {
        if (o is Map<String, dynamic>) {
          maps.add(o);
          rev += _toDouble(o['total']) ?? 0;
          disc += _toDouble(o['totalDiscount']) ?? 0;
          plat += _toDouble(o['platformEarning']) ?? 0;
        }
      }
      setState(() {
        _orders = maps;
        _totalRevenue = rev;
        _totalDiscount = disc;
        _totalPlatformEarning = plat;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  int _toIntTotal(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return AppScaffold(
      appBar: GeneralAppBar(title: 'Sipariş ve Finans'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(Dimens.largePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FinanceStatTile(
                      icon: Icons.trending_up_rounded,
                      iconColor: colors.primary,
                      title: 'Toplam ciro',
                      value: formatPrice(_totalRevenue),
                    ),
                    const SizedBox(height: Dimens.largePadding),
                    _FinanceStatTile(
                      icon: Icons.local_offer_outlined,
                      iconColor: colors.success,
                      title: 'Toplam indirim',
                      value: formatPrice(_totalDiscount),
                    ),
                    const SizedBox(height: Dimens.largePadding),
                    _FinanceStatTile(
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: colors.primary,
                      title: 'Platform kazancı',
                      value: formatPrice(_totalPlatformEarning),
                    ),
                    const SizedBox(height: Dimens.extraLargePadding),
                    Text(
                      'Son siparişler',
                      style: typography.titleSmall.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Son ${_orders.length.clamp(0, 20)} kayıt',
                      style: typography.bodySmall.copyWith(color: colors.gray4),
                    ),
                    const SizedBox(height: Dimens.largePadding),
                    if (_orders.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 56,
                                color: colors.gray4,
                              ),
                              const SizedBox(height: Dimens.padding),
                              Text(
                                'Henüz sipariş yok',
                                style: typography.bodyLarge.copyWith(
                                  color: colors.gray4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...List.generate(
                        _orders.length.clamp(0, 20),
                        (index) {
                          final o = _orders[index];
                          final total = _toIntTotal(o['total']);
                          final disc = _toDouble(o['totalDiscount']) ?? 0;
                          final plat = _toDouble(o['platformEarning']) ?? 0;
                          final status = _adminStatusFromJson(o['status']);
                          final created = _parseDate(o['createdAtUtc']);
                          final dateStr = created != null
                              ? '${formatDate(created)} • ${formatTime(created)}'
                              : null;

                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index ==
                                      _orders.length.clamp(0, 20) - 1
                                  ? 0
                                  : Dimens.largePadding,
                            ),
                            child: ModernOrderCard(
                              productName: o['items']?.toString() ?? '—',
                              price: total,
                              imageUrl: '',
                              dateTime: dateStr,
                              status: status.label,
                              statusColor: status.color(colors),
                              detailLine:
                                  'İndirim: ${formatPrice(disc)} · Platform: ${formatPrice(plat)}',
                              imageSize: 72,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}

class _AdminStatus {
  const _AdminStatus(this.label, this.color);
  final String label;
  final Color Function(dynamic appColors) color;
}

_AdminStatus _adminStatusFromJson(dynamic raw) {
  final n = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
  switch (n) {
    case 1:
      return _AdminStatus(
        'Bekliyor',
        (c) => c.warning,
      );
    case 2:
      return _AdminStatus(
        'Hazırlanıyor',
        (c) => c.primary,
      );
    case 3:
      return _AdminStatus(
        'Kurye atandı',
        (c) => c.primary,
      );
    case 4:
      return _AdminStatus(
        'Yolda',
        (c) => c.primary,
      );
    case 5:
      return _AdminStatus(
        'Teslim edildi',
        (c) => c.success,
      );
    case 6:
      return _AdminStatus(
        'İptal edildi',
        (c) => c.error,
      );
    default:
      return _AdminStatus(
        'Bilinmiyor',
        (c) => c.gray4,
      );
  }
}

/// Dashboard / restoran sipariş listesi ile uyumlu özet satırı
class _FinanceStatTile extends StatelessWidget {
  const _FinanceStatTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return Container(
      padding: const EdgeInsets.all(Dimens.largePadding),
      decoration: BoxDecoration(
        color: colors.white,
        borderRadius: BorderRadius.circular(Dimens.corners),
        border: Border.all(color: colors.gray.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(Dimens.padding),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: Dimens.largePadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: typography.labelMedium.copyWith(
                    color: colors.gray4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: typography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.black,
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
