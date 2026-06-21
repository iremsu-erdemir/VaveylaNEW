import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/widgets/product_image_widget.dart';

import '../../../core/gen/assets.gen.dart';
import '../../../core/widgets/app_svg_viewer.dart';
import '../models/sweet_shop.dart';

class StoresOnMapScreen extends StatelessWidget {
  static const double cardWidth = 150;

  const StoresOnMapScreen({
    super.key,
    required this.stores,
    required this.selectedStoreId,
    required this.onStoreTap,
    this.scrollController,
  });

  final List<SweetShop> stores;
  final String? selectedStoreId;
  final ValueChanged<SweetShop> onStoreTap;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final appColors = context.theme.appColors;
    final appTypography = context.theme.appTypography;
    return Container(
      height: 124,
      margin: EdgeInsets.only(bottom: Dimens.largePadding),
      child: ListView.builder(
        controller: scrollController,
        itemCount: stores.length,
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        itemBuilder: (final context, final index) {
          final store = stores[index];
          final isSelected = selectedStoreId == store.id;
          final locationBadge = _locationBadge(store, appColors);
          return GestureDetector(
            onTap: () => onStoreTap(store),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: cardWidth,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Dimens.corners),
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border.all(
                  color: isSelected ? appColors.primary : Colors.transparent,
                  width: 1.4,
                ),
              ),
              margin: EdgeInsets.only(left: Dimens.largePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Dimens.corners),
                    child: buildProductImage(store.imageUrl, cardWidth, 40),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: Column(
                      spacing: 4,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.name,
                          style: appTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: locationBadge.$2.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: locationBadge.$2.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            locationBadge.$1,
                            style: appTypography.caption.copyWith(
                              color: locationBadge.$2,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                        Row(
                          children: [
                            AppSvgViewer(
                              Assets.icons.clock,
                              color: appColors.primary,
                              width: 10,
                              height: 10,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                store.estimatedDeliveryMinutes.toString() + ' dk',
                                style: appTypography.caption.copyWith(fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  (String, Color) _locationBadge(SweetShop store, dynamic appColors) {
    switch (store.locationStatus) {
      case ShopLocationStatus.backendCoordinates:
        return ('Konum dogrulandi', Colors.green.shade700);
      case ShopLocationStatus.geocodedFromAddress:
        return ('Adresle bulundu', Colors.orange.shade700);
      case ShopLocationStatus.unavailable:
        return ('Konum dogrulanamadi', appColors.primary);
    }
  }
}
