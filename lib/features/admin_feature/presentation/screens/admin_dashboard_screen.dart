import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_logout.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/presentation/screens/admin_assign_coupon_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/presentation/screens/admin_coupons_list_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/presentation/screens/admin_feedback_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/presentation/screens/admin_marketing_banners_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/presentation/screens/admin_orders_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/presentation/screens/admin_pastane_campaigns_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/presentation/screens/admin_restaurants_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/splash_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return AppScaffold(
      appBar: GeneralAppBar(
        title: 'Admin Panel',
        showBackIcon: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await performAuthLogout();
              if (context.mounted) {
                appPushReplacement(context, const SplashScreen());
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Dimens.largePadding),
        children: [
          Text(
            'Hoş geldiniz, ${AppSession.fullName}',
            style: typography.titleMedium.copyWith(color: colors.gray4),
          ),
          const SizedBox(height: Dimens.extraLargePadding),
          _MenuCard(
            icon: Icons.card_giftcard,
            title: 'Kupon Ata',
            subtitle: 'Müşteriye kupon atama',
            onTap: () => appPush(context, const AdminAssignCouponScreen()),
          ),
          const SizedBox(height: Dimens.largePadding),
          _MenuCard(
            icon: Icons.list_alt,
            title: 'Kupon Listesi',
            subtitle: 'Atanmış kuponlar (Kullanıldı etiketi)',
            onTap: () => appPush(context, const AdminCouponsListScreen()),
          ),
          const SizedBox(height: Dimens.largePadding),
          _MenuCard(
            icon: Icons.restaurant,
            title: 'Restoran Yönetimi',
            subtitle: 'Restoranlar, komisyon oranları',
            onTap: () => appPush(context, const AdminRestaurantsScreen()),
          ),
          const SizedBox(height: Dimens.largePadding),
          _MenuCard(
            icon: Icons.store,
            title: 'Pastane Kampanya Yönetimi',
            subtitle: 'Kampanyalar ve restoran indirimi onayı',
            onTap: () => appPush(context, const AdminPastaneCampaignsScreen()),
          ),
          const SizedBox(height: Dimens.largePadding),
          _MenuCard(
            icon: Icons.image_outlined,
            title: 'Özel teklif bannerları',
            subtitle: 'Ana sayfa kaydırıcı (görsel, metin, yönlendirme)',
            onTap: () => appPush(context, const AdminMarketingBannersScreen()),
          ),
          const SizedBox(height: Dimens.largePadding),
          _MenuCard(
            icon: Icons.receipt_long,
            title: 'Sipariş ve Finans',
            subtitle: 'Siparişler, ciro, platform kazancı',
            onTap: () => appPush(context, const AdminOrdersScreen()),
          ),
          const SizedBox(height: Dimens.largePadding),
          _MenuCard(
            icon: Icons.support_agent,
            title: 'Geri bildirimler',
            subtitle: 'Müşteri şikayetleri ve ceza yönetimi',
            onTap: () => appPush(context, const AdminFeedbackScreen()),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return Material(
      color: colors.white,
      borderRadius: BorderRadius.circular(Dimens.corners),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Dimens.corners),
        child: Container(
          padding: const EdgeInsets.all(Dimens.largePadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimens.corners),
            border: Border.all(color: colors.gray.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(Dimens.padding),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colors.primary, size: 28),
              ),
              const SizedBox(width: Dimens.largePadding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: typography.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: typography.bodySmall.copyWith(color: colors.gray4),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: colors.gray4),
            ],
          ),
        ),
      ),
    );
  }
}
