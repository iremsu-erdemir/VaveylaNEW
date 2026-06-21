import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/services/customer_favorites_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/services/products_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/all_products_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/restaurant_chat_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/restaurant_products_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/widgets/product_image_widget.dart';

class RestaurantsScreen extends StatefulWidget {
  const RestaurantsScreen({super.key});

  @override
  State<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends State<RestaurantsScreen> {
  final CustomerFavoritesService _favoritesService = CustomerFavoritesService();
  Set<String> _favoriteRestaurantIds = const {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final userId = AppSession.userId;
    if (userId.isEmpty) {
      return;
    }
    try {
      final data = await _favoritesService.getFavorites(customerUserId: userId);
      if (!mounted) return;
      setState(() {
        _favoriteRestaurantIds = data.restaurants.map((x) => x.id).toSet();
      });
    } catch (_) {}
  }

  Future<void> _toggleFavorite(String restaurantId) async {
    final userId = AppSession.userId;
    if (userId.isEmpty) {
      context.showErrorMessage('Favori için giriş yapmalısınız.');
      return;
    }
    final isFavorite = _favoriteRestaurantIds.contains(restaurantId);
    try {
      if (isFavorite) {
        await _favoritesService.removeRestaurantFavorite(
          customerUserId: userId,
          restaurantId: restaurantId,
        );
      } else {
        await _favoritesService.addRestaurantFavorite(
          customerUserId: userId,
          restaurantId: restaurantId,
        );
      }
      if (!mounted) return;
      setState(() {
        final updated = Set<String>.from(_favoriteRestaurantIds);
        if (isFavorite) {
          updated.remove(restaurantId);
        } else {
          updated.add(restaurantId);
        }
        _favoriteRestaurantIds = updated;
      });
      context.showSuccessMessage(
        isFavorite ? 'Favorilerden çıkarıldı.' : 'Favorilere eklendi.',
      );
    } catch (error) {
      if (!mounted) return;
      context.showErrorMessage(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (_) => AllProductsCubit(ProductsService())..loadProducts()..startPolling(),
      child: AppScaffold(
        appBar: const GeneralAppBar(title: 'Pastaneler'),
        body: BlocBuilder<AllProductsCubit, AllProductsState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final byRestaurant =
                <String, (String name, String type, String? photoPath, bool isOpen)>{};
            for (final product in state.products) {
              final id = product.restaurantId;
              if (id == null || id.isEmpty) continue;
              byRestaurant[id] = (
                product.restaurantName ?? 'Pastane',
                product.restaurantType ?? 'Kategori',
                product.restaurantPhotoPath,
                product.restaurantIsOpen,
              );
            }
            final restaurants = byRestaurant.entries.toList();
            if (restaurants.isEmpty) {
              return const Center(child: Text('Pastane bulunamadı.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.all(Dimens.largePadding),
              itemCount: restaurants.length,
              separatorBuilder: (_, __) => const SizedBox(height: Dimens.largePadding),
              itemBuilder: (context, index) {
                final item = restaurants[index];
                final restaurantId = item.key;
                final (name, type, photoPath, isOpen) = item.value;
                final isFavorite = _favoriteRestaurantIds.contains(restaurantId);
                return InkWell(
                  borderRadius: BorderRadius.circular(Dimens.corners),
                  onTap: () {
                    if (!isOpen) {
                      context.showErrorMessage(
                        'Bu pastane şu anda hizmet verememektedir.',
                      );
                      return;
                    }
                    appPush(
                      context,
                      RestaurantProductsScreen(
                        restaurantId: restaurantId,
                        restaurantName: name,
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Dimens.corners),
                    child: Stack(
                      children: [
                        SizedBox(
                          height: 140,
                          width: double.infinity,
                          child: buildProductImage(photoPath ?? '', 360, 140),
                        ),
                        if (!isOpen)
                          Positioned.fill(
                            child: Container(
                              color: Colors.grey.withValues(alpha: 0.45),
                            ),
                          ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.08),
                                  Colors.black.withValues(alpha: 0.55),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: Dimens.padding,
                          right: Dimens.padding,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _toggleFavorite(restaurantId),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: context.theme.appColors.primary,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: Dimens.padding,
                          left: Dimens.padding,
                          child: Visibility(
                            visible: !isOpen,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Dimens.smallPadding,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(
                                  Dimens.smallCorners,
                                ),
                              ),
                              child: Text(
                                'Kapalı',
                                style: context.theme.appTypography.labelSmall
                                    .copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: Dimens.largePadding,
                          bottom: Dimens.largePadding,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              appPush(
                                context,
                                RestaurantChatScreen(
                                  restaurantId: restaurantId,
                                  restaurantName: name,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Dimens.padding,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 16,
                                    color: context.theme.appColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Sohbet',
                                    style: context.theme.appTypography.labelSmall
                                        .copyWith(
                                          color: context.theme.appColors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: Dimens.largePadding,
                          right: 124,
                          bottom: Dimens.largePadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: context.theme.appTypography.titleMedium
                                    .copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                type,
                                style: context.theme.appTypography.bodySmall.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
