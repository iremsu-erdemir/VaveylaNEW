import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/data/services/admin_restaurant_discount_service.dart';

class AdminRestaurantDiscountsScreen extends StatefulWidget {
  const AdminRestaurantDiscountsScreen({super.key});

  @override
  State<AdminRestaurantDiscountsScreen> createState() =>
      _AdminRestaurantDiscountsScreenState();
}

class _AdminRestaurantDiscountsScreenState
    extends State<AdminRestaurantDiscountsScreen>
    with SingleTickerProviderStateMixin {
  final AdminRestaurantDiscountService _service =
      AdminRestaurantDiscountService();
  List<PendingRestaurantDiscountDto> _pendingItems = [];
  List<RestaurantDiscountDto> _approvedItems = [];
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final pending = await _service.getPendingDiscounts();
      final approved = await _service.getApprovedDiscounts();
      if (mounted) setState(() {
        _pendingItems = pending;
        _approvedItems = approved;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(PendingRestaurantDiscountDto item) async {
    final controller = TextEditingController(
      text: item.restaurantDiscountPercent.toInt().toString(),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İndirimi onayla'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item.name} için indirim onaylanacak.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'İndirim oranı (%)',
                hintText: 'Yanlış kaydedildiyse buradan düzeltin',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    final pctStr = controller.text.trim();
    controller.dispose();
    if (confirmed != true || !mounted) return;
    final pct = int.tryParse(pctStr);
    if (pct == null || pct < 1 || pct > 100) {
      if (mounted) context.showErrorMessage('Geçerli bir oran girin (1-100).');
      return;
    }
    try {
      await _service.approveDiscount(item.restaurantId, restaurantDiscountPercent: pct.toDouble());
      if (mounted) {
        context.showSuccessMessage('Restoran indirimi onaylandı.');
        _load();
      }
    } catch (e) {
      if (mounted) {
        context.showErrorMessage(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _editApproved(RestaurantDiscountDto item) async {
    final controller = TextEditingController(
      text: item.restaurantDiscountPercent.toInt().toString(),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İndirim oranını düzelt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item.name} - Mevcut: %${item.restaurantDiscountPercent.toInt()}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Yeni indirim oranı (%)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    final pctStr = controller.text.trim();
    controller.dispose();
    if (confirmed != true || !mounted) return;
    final pct = int.tryParse(pctStr);
    if (pct == null || pct < 1 || pct > 100) {
      if (mounted) context.showErrorMessage('Geçerli bir oran girin (1-100).');
      return;
    }
    try {
      await _service.updateDiscountPercent(item.restaurantId, pct.toDouble());
      if (mounted) {
        context.showSuccessMessage('İndirim oranı güncellendi.');
        _load();
      }
    } catch (e) {
      if (mounted) {
        context.showErrorMessage(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _reject(String restaurantId) async {
    try {
      await _service.rejectDiscount(restaurantId);
      if (mounted) {
        context.showSuccessMessage('Restoran indirimi reddedildi.');
        _load();
      }
    } catch (e) {
      if (mounted) {
        context.showErrorMessage(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.theme.appColors;
    final appTypography = context.theme.appTypography;

    return AppScaffold(
      appBar: GeneralAppBar(
        title: 'Restoran İndirimleri',
        showBackIcon: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Onay Bekleyen (${_pendingItems.length})'),
            Tab(text: 'Onaylı (${_approvedItems.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _pendingItems.isEmpty
                    ? Center(
                        child: Text(
                          'Onay bekleyen restoran indirimi yok.',
                          style: appTypography.bodyLarge.copyWith(color: appColors.gray4),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: EdgeInsets.all(Dimens.largePadding),
                          itemCount: _pendingItems.length,
                          itemBuilder: (context, i) {
                            final item = _pendingItems[i];
                            return Card(
                              margin: EdgeInsets.only(bottom: Dimens.padding),
                              child: ListTile(
                                title: Text(
                                  item.name,
                                  style: appTypography.titleSmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '%${item.restaurantDiscountPercent.toInt()} indirim',
                                  style: appTypography.bodySmall.copyWith(
                                    color: appColors.primary,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: () => _reject(item.restaurantId),
                                      child: Text('Reddet', style: TextStyle(color: appColors.error)),
                                    ),
                                    FilledButton(
                                      onPressed: () => _approve(item),
                                      child: const Text('Onayla'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                _approvedItems.isEmpty
                    ? Center(
                        child: Text(
                          'Onaylı restoran indirimi yok.',
                          style: appTypography.bodyLarge.copyWith(color: appColors.gray4),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: EdgeInsets.all(Dimens.largePadding),
                          itemCount: _approvedItems.length,
                          itemBuilder: (context, i) {
                            final item = _approvedItems[i];
                            return Card(
                              margin: EdgeInsets.only(bottom: Dimens.padding),
                              child: ListTile(
                                title: Text(
                                  item.name,
                                  style: appTypography.titleSmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                          subtitle: Text(
                            '%${item.restaurantDiscountPercent.toInt()} indirim • ${item.restaurantDiscountIsActive ? 'Aktif' : 'Pasif'}',
                            style: appTypography.bodySmall.copyWith(
                              color: item.restaurantDiscountIsActive ? appColors.primary : appColors.gray4,
                            ),
                          ),
                          trailing: FilledButton.tonal(
                            onPressed: () => _editApproved(item),
                            child: const Text('Düzelt'),
                          ),
                              ),
                            );
                          },
                        ),
                      ),
              ],
            ),
    );
  }
}
