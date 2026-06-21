import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/data/services/admin_service.dart';

class AdminCampaignsScreen extends StatefulWidget {
  const AdminCampaignsScreen({super.key});

  @override
  State<AdminCampaignsScreen> createState() => _AdminCampaignsScreenState();
}

class _AdminCampaignsScreenState extends State<AdminCampaignsScreen> {
  final AdminService _adminService = AdminService();
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
      final list = await _adminService.getCampaigns();
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

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return AppScaffold(
      appBar: GeneralAppBar(title: 'Kampanya Yönetimi'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(Dimens.largePadding),
                itemCount: _campaigns.length,
                itemBuilder: (context, index) {
                  final c = _campaigns[index] as Map<String, dynamic>;
                  final status = c['status']?.toString() ?? 'Pending';
                  final campaignId = c['campaignId']?.toString() ?? '';
                  return Card(
                    margin: const EdgeInsets.only(bottom: Dimens.largePadding),
                    child: Padding(
                      padding: const EdgeInsets.all(Dimens.largePadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c['name']?.toString() ?? '',
                                  style: typography.titleSmall,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Dimens.padding,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(status)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status,
                                  style: typography.labelSmall.copyWith(
                                    color: _statusColor(status),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Dimens.padding),
                          Text(
                            '${c['discountValue']} ${c['discountType'] == 1 ? '%' : '₺'} indirim',
                            style: typography.bodyMedium,
                          ),
                          const SizedBox(height: Dimens.smallPadding),
                          Text(
                            _restaurantDisplay(c),
                            style: typography.bodySmall.copyWith(
                              color: colors.gray4,
                            ),
                          ),
                          if (status == 'Pending') ...[
                            const SizedBox(height: Dimens.padding),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    try {
                                      await _adminService.approveCampaign(
                                        campaignId,
                                      );
                                      if (mounted) _load();
                                    } catch (_) {}
                                  },
                                  child: const Text('Onayla'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    try {
                                      await _adminService.rejectCampaign(
                                        campaignId,
                                      );
                                      if (mounted) _load();
                                    } catch (_) {}
                                  },
                                  child: Text(
                                    'Reddet',
                                    style: TextStyle(color: colors.error),
                                  ),
                                ),
                              ],
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
      default:
        return Colors.orange;
    }
  }
}
