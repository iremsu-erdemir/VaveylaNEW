import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/models/home_marketing_banner_model.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/product_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/services/products_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/category_products_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/product_details_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/restaurant_products_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/special_offers.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> navigateFromMarketingBanner(
  BuildContext context,
  HomeMarketingBannerModel banner,
) async {
  final t = banner.actionType.trim().toLowerCase();
  final target = banner.actionTarget?.trim() ?? '';

  switch (t) {
    case 'category':
      if (target.isEmpty) return;
      if (!context.mounted) return;
      appPush(context, CategoryProductsScreen(categoryName: target));
      return;
    case 'restaurant':
      if (target.isEmpty) return;
      if (!context.mounted) return;
      appPush(
        context,
        RestaurantProductsScreen(
          restaurantId: target,
          restaurantName: 'Pastane',
        ),
      );
      return;
    case 'product':
      if (target.isEmpty) return;
      try {
        final products = await ProductsService().getProducts();
        ProductModel? match;
        for (final p in products) {
          if (p.id.toLowerCase() == target.toLowerCase()) {
            match = p;
            break;
          }
        }
        if (!context.mounted) return;
        if (match != null) {
          appPush(context, ProductDetailsScreen(product: match));
        } else {
          context.showInfoMessage('Ürün bulunamadı.');
        }
      } catch (_) {
        if (context.mounted) {
          context.showInfoMessage('Ürün yüklenemedi.');
        }
      }
      return;
    case 'externalurl':
    case 'url':
      if (target.isEmpty) return;
      final uri = Uri.tryParse(target);
      if (uri == null || !(uri.hasScheme && (uri.isScheme('http') || uri.isScheme('https')))) {
        if (context.mounted) {
          context.showInfoMessage('Geçersiz bağlantı.');
        }
        return;
      }
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        context.showInfoMessage('Bağlantı açılamadı.');
      }
      return;
    case 'specialoffers':
    case 'special_offers':
      if (!context.mounted) return;
      appPush(context, const SpecialOffers());
      return;
    default:
      return;
  }
}
