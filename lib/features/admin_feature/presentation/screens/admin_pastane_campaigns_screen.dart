import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/colors.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/typography.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/data/services/admin_restaurant_discount_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/data/services/admin_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/presentation/widgets/admin_list_card.dart';

class AdminPastaneCampaignsScreen extends StatefulWidget {
  const AdminPastaneCampaignsScreen({super.key});

  @override
  State<AdminPastaneCampaignsScreen> createState() =>
      _AdminPastaneCampaignsScreenState();
}

class _AdminPastaneCampaignsScreenState extends State<AdminPastaneCampaignsScreen>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  final AdminRestaurantDiscountService _restaurantDiscountService =
      AdminRestaurantDiscountService();

  // Kampanyalar
  List<dynamic> _campaigns = [];

  // Restoran indirimleri
  List<PendingRestaurantDiscountDto> _pendingItems = [];
  List<RestaurantDiscountDto> _approvedItems = [];

  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      final results = await Future.wait([
        _adminService.getCampaigns(),
        _restaurantDiscountService.getPendingDiscounts(),
        _restaurantDiscountService.getApprovedDiscounts(),
      ]);
      if (mounted) {
        setState(() {
          _campaigns = results[0];
          _pendingItems = results[1] as List<PendingRestaurantDiscountDto>;
          _approvedItems = results[2] as List<RestaurantDiscountDto>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- Kampanya işlemleri ---
  Future<void> _approveCampaign(String campaignId) async {
    try {
      await _adminService.approveCampaign(campaignId);
      if (mounted) _load();
    } catch (_) {}
  }

  Future<void> _rejectCampaign(String campaignId) async {
    try {
      await _adminService.rejectCampaign(campaignId);
      if (mounted) _load();
    } catch (_) {}
  }

  String _restaurantDisplay(Map<String, dynamic> c) {
    final name = c['restaurantName']?.toString().trim();
    if (name != null && name.isNotEmpty) {
      return 'Restoran: $name';
    }
    return 'Tüm restoranlar';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Active':
        return context.theme.appColors.success;
      case 'Pasif':
        return context.theme.appColors.gray4;
      case 'Rejected':
        return context.theme.appColors.error;
      case 'Pending':
        return context.theme.appColors.warning;
      default:
        return context.theme.appColors.warning;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Active':
        return 'Aktif';
      case 'Pasif':
        return 'Pasif';
      case 'Rejected':
        return 'Reddedildi';
      case 'Pending':
        return 'Onay bekliyor';
      default:
        return status;
    }
  }

  // --- Restoran indirimi işlemleri ---
  Future<void> _approveRestaurantDiscount(PendingRestaurantDiscountDto item) async {
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
      await _restaurantDiscountService.approveDiscount(item.restaurantId,
          restaurantDiscountPercent: pct.toDouble());
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

  Future<void> _editApprovedRestaurantDiscount(RestaurantDiscountDto item) async {
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
            Text(
                '${item.name} - Mevcut: %${item.restaurantDiscountPercent.toInt()}'),
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
      await _restaurantDiscountService.updateDiscountPercent(
          item.restaurantId, pct.toDouble());
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

  Future<void> _rejectRestaurantDiscount(String restaurantId) async {
    try {
      await _restaurantDiscountService.rejectDiscount(restaurantId);
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
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return AppScaffold(
      appBar: GeneralAppBar(
        title: 'Pastane Kampanya Yönetimi',
        showBackIcon: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Kampanyalar (${_campaigns.length})'),
            Tab(text: 'Restoran İndirimi Bekleyen (${_pendingItems.length})'),
            Tab(text: 'Restoran İndirimi Onaylı (${_approvedItems.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCampaignsTab(colors, typography),
                _buildPendingRestaurantDiscountsTab(colors, typography),
                _buildApprovedRestaurantDiscountsTab(colors, typography),
              ],
            ),
    );
  }

  Widget _buildCampaignsTab(
      AppColors colors, AppTypography typography) {
    if (_campaigns.isEmpty) {
      return Center(
        child: Text(
          'Kampanya bulunamadı.',
          style: typography.bodyLarge.copyWith(color: colors.gray4),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(Dimens.largePadding),
        itemCount: _campaigns.length,
        itemBuilder: (context, index) {
          final c = _campaigns[index] as Map<String, dynamic>;
          final status = c['status']?.toString() ?? 'Pending';
          final campaignId = c['campaignId']?.toString() ?? '';
          final name = c['name']?.toString() ?? 'Kampanya';
          final discType = c['discountType'];
          final isPercent = discType == 1 || discType == '1';
          final discVal = c['discountValue'];
          final discountLine = isPercent
              ? '%$discVal indirim'
              : '$discVal ₺ indirim';

          return AdminListCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(Dimens.padding),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.campaign_outlined,
                        color: colors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: Dimens.padding),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: typography.titleSmall.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            discountLine,
                            style: typography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: typography.labelSmall.copyWith(
                          color: _statusColor(status),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Dimens.padding),
                Row(
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 18,
                      color: colors.gray4,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _restaurantDisplay(c),
                        style: typography.bodySmall.copyWith(
                          color: colors.gray4,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                if (status == 'Pending') ...[
                  const SizedBox(height: Dimens.largePadding),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _approveCampaign(campaignId),
                          child: const Text('Onayla'),
                        ),
                      ),
                      const SizedBox(width: Dimens.padding),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _rejectCampaign(campaignId),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.error,
                            side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
                          ),
                          child: const Text('Reddet'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPendingRestaurantDiscountsTab(
      AppColors colors, AppTypography typography) {
    if (_pendingItems.isEmpty) {
      return Center(
        child: Text(
          'Onay bekleyen restoran indirimi yok.',
          style: typography.bodyLarge.copyWith(color: colors.gray4),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(Dimens.largePadding),
        itemCount: _pendingItems.length,
        itemBuilder: (context, i) {
          final item = _pendingItems[i];
          return AdminListCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(Dimens.padding),
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.hourglass_top_rounded,
                        color: colors.warning,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: Dimens.padding),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: typography.titleSmall.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '%${item.restaurantDiscountPercent.toInt()} indirim',
                              style: typography.labelMedium.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Dimens.largePadding),
                Text(
                  'Onayınızı bekliyor',
                  style: typography.bodySmall.copyWith(color: colors.gray4),
                ),
                const SizedBox(height: Dimens.padding),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _approveRestaurantDiscount(item),
                        child: const Text('Onayla'),
                      ),
                    ),
                    const SizedBox(width: Dimens.padding),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _rejectRestaurantDiscount(item.restaurantId),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.error,
                          side: BorderSide(
                            color: colors.error.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Text('Reddet'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildApprovedRestaurantDiscountsTab(
      AppColors colors, AppTypography typography) {
    if (_approvedItems.isEmpty) {
      return Center(
        child: Text(
          'Onaylı restoran indirimi yok.',
          style: typography.bodyLarge.copyWith(color: colors.gray4),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(Dimens.largePadding),
        itemCount: _approvedItems.length,
        itemBuilder: (context, i) {
          final item = _approvedItems[i];
          final active = item.restaurantDiscountIsActive;
          return AdminListCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(Dimens.padding),
                      decoration: BoxDecoration(
                        color: (active ? colors.success : colors.gray4)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.verified_outlined,
                        color: active ? colors.success : colors.gray4,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: Dimens.padding),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: typography.titleSmall.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: Dimens.padding,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '%${item.restaurantDiscountPercent.toInt()} indirim',
                                style: typography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: (active ? colors.success : colors.gray4)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  active ? 'Aktif' : 'Pasif',
                                  style: typography.labelSmall.copyWith(
                                    color:
                                        active ? colors.success : colors.gray4,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Dimens.largePadding),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () => _editApprovedRestaurantDiscount(item),
                    child: const Text('Oranı düzelt'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
