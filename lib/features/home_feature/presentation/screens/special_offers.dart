import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/models/home_marketing_banner_model.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/home_marketing_banners_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/special_offers_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/colors.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/typography.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/restaurants_with_discount_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/utils/marketing_banner_navigation.dart';

import '../../data/data_source/local/sample_data.dart';

class SpecialOffers extends StatefulWidget {
  const SpecialOffers({super.key});

  @override
  State<SpecialOffers> createState() => _SpecialOffersState();
}

class _SpecialOffersState extends State<SpecialOffers> {
  final SpecialOffersService _specialOffersService = SpecialOffersService();
  final HomeMarketingBannersService _marketingBannersService =
      HomeMarketingBannersService();
  List<HomeMarketingBannerModel> _marketingBanners = [];
  List<SpecialOfferItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = AppSession.userId;
      final results = await Future.wait([
        _marketingBannersService.fetchActive(),
        _specialOffersService.getSpecialOffers(
          customerUserId: userId.isNotEmpty ? userId : null,
        ),
      ]);
      if (mounted) {
        setState(() {
          _marketingBanners = results[0] as List<HomeMarketingBannerModel>;
          _items = results[1] as List<SpecialOfferItem>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _marketingBanners = [];
          _items = [];
          _loading = false;
        });
      }
    }
  }

  void _onCouponTap() {
    context.showInfoMessage(
      'Kuponlar admin tarafından müşterilere atanır. Atanmış kuponlarınızı Kuponlarım sayfasında görebilirsiniz.',
    );
  }

  void _onRestaurantDiscountTap(SpecialOfferItem item) {
    appPush(
      context,
      RestaurantsWithDiscountScreen(
        discountPercent: item.discountValue,
        discountTitle: item.discountLabel,
      ),
    );
  }

  void _onItemTap(SpecialOfferItem item) {
    if (item.isCoupon) {
      _onCouponTap();
    } else if (item.isRestaurantDiscount) {
      _onRestaurantDiscountTap(item);
    }
  }

  int get _totalRows => _marketingBanners.length + _items.length;

  @override
  Widget build(BuildContext context) {
    final appTypography = context.theme.appTypography;
    final appColors = context.theme.appColors;

    return AppScaffold(
      appBar: GeneralAppBar(title: 'Özel Teklifler'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _totalRows == 0
              ? _buildFallbackBanners(context)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(Dimens.largePadding),
                    itemCount: _totalRows,
                    itemBuilder: (context, index) {
                      if (index < _marketingBanners.length) {
                        return _buildMarketingBannerRow(
                          context,
                          _marketingBanners[index],
                          appTypography,
                          appColors,
                        );
                      }
                      final item = _items[index - _marketingBanners.length];
                      return _buildOfferRow(
                        context,
                        item,
                        appTypography,
                        appColors,
                      );
                    },
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: Dimens.largePadding),
                  ),
                ),
    );
  }

  Widget _buildMarketingBannerRow(
    BuildContext context,
    HomeMarketingBannerModel banner,
    AppTypography appTypography,
    AppColors appColors,
  ) {
    final showOverlay = banner.hasTextOverlay;
    return InkWell(
      onTap: () => navigateFromMarketingBanner(context, banner),
      borderRadius: BorderRadius.circular(Dimens.largePadding),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Dimens.largePadding),
        child: AspectRatio(
          aspectRatio: 2.2,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                banner.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: appColors.gray.withValues(alpha: 0.2),
                  child: Icon(Icons.broken_image_outlined, color: appColors.gray4),
                ),
              ),
              if (showOverlay)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(Dimens.padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (banner.badgeText != null &&
                              banner.badgeText!.trim().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: appColors.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                banner.badgeText!.trim(),
                                style: appTypography.labelSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (banner.subtitle != null &&
                              banner.subtitle!.trim().isNotEmpty)
                            Text(
                              banner.subtitle!.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: appTypography.labelSmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          if (banner.title != null &&
                              banner.title!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              banner.title!.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: appTypography.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (banner.bodyText != null &&
                              banner.bodyText!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              banner.bodyText!.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: appTypography.bodySmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfferRow(
    BuildContext context,
    SpecialOfferItem item,
    AppTypography appTypography,
    AppColors appColors,
  ) {
    return InkWell(
      onTap: () => _onItemTap(item),
      borderRadius: BorderRadius.circular(Dimens.largePadding),
      child: Container(
        padding: const EdgeInsets.all(Dimens.largePadding),
        decoration: BoxDecoration(
          color: appColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Dimens.largePadding),
          border: Border.all(
            color: appColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimens.padding,
                    vertical: Dimens.smallPadding,
                  ),
                  decoration: BoxDecoration(
                    color: appColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.discountLabel,
                    style: appTypography.labelMedium.copyWith(color: Colors.white),
                  ),
                ),
                if (item.minCartAmount != null && item.minCartAmount! > 0) ...[
                  const SizedBox(width: Dimens.padding),
                  Text(
                    '${item.minCartAmount!.round()} ₺ üzeri',
                    style: appTypography.bodySmall.copyWith(color: appColors.gray4),
                  ),
                ],
              ],
            ),
            const SizedBox(height: Dimens.padding),
            Text(
              item.title,
              style: appTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (item.description != null && item.description!.isNotEmpty) ...[
              const SizedBox(height: Dimens.smallPadding),
              Text(
                item.description!,
                style: appTypography.bodySmall.copyWith(color: appColors.gray4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(top: Dimens.padding),
              child: Row(
                children: [
                  Text(
                    item.isRestaurantDiscount ? 'Pastanelere git' : 'Bilgi',
                    style: appTypography.labelMedium.copyWith(color: appColors.primary),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 16, color: appColors.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackBanners(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(Dimens.largePadding),
      itemCount: banners.length,
      itemBuilder: (context, index) {
        return InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(Dimens.largePadding),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Dimens.largePadding),
            child: Image.asset(banners[index]),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: Dimens.largePadding),
    );
  }
}
