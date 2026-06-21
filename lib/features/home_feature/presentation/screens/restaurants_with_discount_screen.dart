import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/special_offers_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/restaurant_products_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/widgets/product_image_widget.dart';

class RestaurantsWithDiscountScreen extends StatefulWidget {
  const RestaurantsWithDiscountScreen({
    super.key,
    required this.discountPercent,
    required this.discountTitle,
  });

  final double discountPercent;
  final String discountTitle;

  @override
  State<RestaurantsWithDiscountScreen> createState() =>
      _RestaurantsWithDiscountScreenState();
}

class _RestaurantsWithDiscountScreenState
    extends State<RestaurantsWithDiscountScreen> {
  final SpecialOffersService _service = SpecialOffersService();
  List<RestaurantWithDiscount> _restaurants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _service.getRestaurantsWithDiscount(widget.discountPercent);
      if (mounted) setState(() {
        _restaurants = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.theme.appColors;
    final appTypography = context.theme.appTypography;

    return AppScaffold(
      appBar: GeneralAppBar(
        title: '${widget.discountTitle} - Pastaneler',
        showBackIcon: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _restaurants.isEmpty
              ? Center(
                  child: Text(
                    'Bu indirime sahip pastane bulunamadı.',
                    style: appTypography.bodyLarge.copyWith(color: appColors.gray4),
                    textAlign: TextAlign.center,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(Dimens.largePadding),
                    itemCount: _restaurants.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: Dimens.largePadding),
                    itemBuilder: (context, index) {
                      final r = _restaurants[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(Dimens.corners),
                        onTap: () {
                          appPush(
                            context,
                            RestaurantProductsScreen(
                              restaurantId: r.restaurantId,
                              restaurantName: r.name,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(Dimens.largePadding),
                          decoration: BoxDecoration(
                            color: appColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(Dimens.corners),
                            border: Border.all(
                              color: appColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(Dimens.smallCorners),
                                child: SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: buildProductImage(
                                    r.photoPath ?? '',
                                    160,
                                    160,
                                  ),
                                ),
                              ),
                              const SizedBox(width: Dimens.largePadding),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.name,
                                      style: appTypography.titleMedium
                                          .copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      r.type,
                                      style: appTypography.bodySmall
                                          .copyWith(color: appColors.gray4),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: Dimens.padding,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: appColors.primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '%${r.discountPercent.toInt()} indirim',
                                        style: appTypography.labelSmall
                                            .copyWith(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios,
                                  size: 16, color: appColors.gray4),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
