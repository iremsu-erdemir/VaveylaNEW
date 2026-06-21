import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/services/restaurant_campaign_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/presentation/bloc/restaurant_settings_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/presentation/screens/restaurant_campaign_form_screen.dart';

class RestaurantCampaignsScreen extends StatefulWidget {
  const RestaurantCampaignsScreen({super.key});

  @override
  State<RestaurantCampaignsScreen> createState() =>
      _RestaurantCampaignsScreenState();
}

class _RestaurantCampaignsScreenState extends State<RestaurantCampaignsScreen> {
  final RestaurantCampaignService _service = RestaurantCampaignService();
  List<dynamic> _campaigns = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _service.getCampaigns();
      if (mounted) {
        setState(() {
          _campaigns = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Aktif kampanya varsa onay iste, sonra formu aç. Mevcut aktif pasifleşecek.
  Future<void> _openCampaignForm(BuildContext context) async {
    final activeCampaign = <Map<String, dynamic>>[];
    for (final item in _campaigns) {
      if (item is! Map<String, dynamic>) continue;
      final c = item;
      final isActive = c['isActive'] == true;
      final status = c['status']?.toString() ?? '';
      if (isActive || status == 'Active') activeCampaign.add(c);
    }

    if (activeCampaign.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Yeni Kampanya'),
          content: const Text(
            'Mevcut aktif kampanya pasifleştirilecek. Yeni kampanya onay bekleyecektir. Emin misiniz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Evet'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      // Restoran indirimi ise önce pasifleştir
      final active = activeCampaign.first;
      if (active['savedAs']?.toString() == 'restaurant_discount') {
        try {
          final cubit = context.read<RestaurantSettingsCubit>();
          await cubit.toggleDiscountActive(false);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kampanya pasifleştirilemedi.')),
            );
          }
          return;
        }
      }
    }

    if (!mounted) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const RestaurantCampaignFormScreen(),
      ),
    );
    if (result == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return AppScaffold(
      appBar: GeneralAppBar(
        title: 'Kampanyalarım',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openCampaignForm(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _campaigns.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.campaign, size: 64, color: colors.gray4),
                          const SizedBox(height: Dimens.largePadding),
                          Text(
                            'Henüz kampanya yok',
                            style: typography.bodyLarge.copyWith(
                              color: colors.gray4,
                            ),
                          ),
                          const SizedBox(height: Dimens.padding),
                          FilledButton.icon(
                            onPressed: () => _openCampaignForm(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Kampanya Oluştur'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(Dimens.largePadding),
                      itemCount: _campaigns.length,
                      itemBuilder: (context, index) {
                        final c =
                            _campaigns[index] as Map<String, dynamic>;
                        final status = c['status']?.toString() ?? 'Pending';
                        final isRestaurantDiscount =
                            c['savedAs']?.toString() == 'restaurant_discount';
                        return Card(
                          margin: const EdgeInsets.only(
                            bottom: Dimens.largePadding,
                          ),
                          child: ListTile(
                            title: Text(c['name']?.toString() ?? ''),
                            subtitle: Text(
                              '${c['discountValue']} ${c['discountType'] == 1 ? '%' : '₺'} • $status',
                            ),
                            trailing: isRestaurantDiscount
                                ? _buildRestaurantDiscountMenu(context, c)
                                : PopupMenuButton(
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Sil'),
                                      ),
                                    ],
                                    onSelected: (v) async {
                                      if (v == 'delete') {
                                        try {
                                          await _service.deleteCampaign(
                                            c['campaignId']?.toString() ?? '',
                                          );
                                          if (mounted) _load();
                                        } catch (_) {}
                                      }
                                    },
                                  ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget? _buildRestaurantDiscountMenu(
      BuildContext context, Map<String, dynamic> c) {
    final isActive = c['isActive'] == true || c['status']?.toString() == 'Active';
    return PopupMenuButton<String>(
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'toggle',
          child: Text(isActive ? 'Pasif yap' : 'Aktif yap'),
        ),
      ],
      onSelected: (v) async {
        if (v == 'toggle') {
          final cubit = context.read<RestaurantSettingsCubit>();
          try {
            await cubit.toggleDiscountActive(!isActive);
            if (mounted) _load();
          } catch (_) {}
        }
      },
    );
  }
}
