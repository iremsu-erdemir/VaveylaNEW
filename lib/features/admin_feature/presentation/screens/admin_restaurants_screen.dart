import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/data/services/admin_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/presentation/widgets/admin_list_card.dart';

class AdminRestaurantsScreen extends StatefulWidget {
  const AdminRestaurantsScreen({super.key});

  @override
  State<AdminRestaurantsScreen> createState() => _AdminRestaurantsScreenState();
}

class _AdminRestaurantsScreenState extends State<AdminRestaurantsScreen> {
  final AdminService _adminService = AdminService();
  List<dynamic> _restaurants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _adminService.getRestaurants();
      if (mounted) {
        setState(() {
          _restaurants = list;
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
      appBar: GeneralAppBar(title: 'Restoran Yönetimi'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(Dimens.largePadding),
                itemCount: _restaurants.length,
                itemBuilder: (context, index) {
                  final r = _restaurants[index] as Map<String, dynamic>;
                  final id = r['restaurantId']?.toString() ?? '';
                  final name = r['name']?.toString() ?? '';
                  final isEnabled = r['isEnabled'] == true;
                  final commissionRate =
                      (r['commissionRate'] ?? 0.10) as num;
                  return AdminListCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(Dimens.padding),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.storefront_outlined,
                            color: colors.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: Dimens.largePadding),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: typography.titleSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Komisyon %${(commissionRate * 100).toStringAsFixed(1)} · ${isEnabled ? 'Açık' : 'Kapalı'}',
                                style: typography.bodySmall.copyWith(
                                  color: colors.gray4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isEnabled,
                          onChanged: (_) async {
                            try {
                              await _adminService.toggleRestaurantStatus(id);
                              if (mounted) _load();
                            } catch (_) {}
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
