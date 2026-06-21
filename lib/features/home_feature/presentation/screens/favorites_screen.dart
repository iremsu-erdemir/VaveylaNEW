import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/formatters.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/product_model.dart'
    show ProductModel, ProductSaleUnit;
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/models/favorite_models.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/services/customer_favorites_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/product_details_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/restaurant_products_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/widgets/product_image_widget.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final CustomerFavoritesService _favoritesService = CustomerFavoritesService();
  bool _isLoading = true;
  List<FavoriteRestaurantModel> _restaurants = const [];
  List<FavoriteProductModel> _products = const [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final userId = AppSession.userId;
    if (userId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final data = await _favoritesService.getFavorites(customerUserId: userId);
      if (!mounted) return;
      setState(() {
        _restaurants = data.restaurants;
        _products = data.products;
      });
    } catch (error) {
      if (!mounted) return;
      context.showErrorMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeRestaurant(String restaurantId) async {
    final userId = AppSession.userId;
    if (userId.isEmpty) return;
    await _favoritesService.removeRestaurantFavorite(
      customerUserId: userId,
      restaurantId: restaurantId,
    );
    if (!mounted) return;
    setState(() {
      _restaurants = _restaurants.where((x) => x.id != restaurantId).toList();
    });
    context.showSuccessMessage('Favorilerden çıkarıldı.');
  }

  Future<void> _removeProduct(String productId) async {
    final userId = AppSession.userId;
    if (userId.isEmpty) return;
    await _favoritesService.removeProductFavorite(
      customerUserId: userId,
      productId: productId,
    );
    if (!mounted) return;
    setState(() {
      _products = _products.where((x) => x.id != productId).toList();
    });
    context.showSuccessMessage('Favorilerden çıkarıldı.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                height: 76,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                color: const Color(0xFFFDECEC),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      'Favoriler',
                      style: typography.titleSmall.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                color: const Color(0xFFFDECEC),
                child: TabBar(
                  indicatorColor: colors.primary,
                  indicatorWeight: 2,
                  labelColor: colors.primary,
                  unselectedLabelColor: colors.gray4,
                  labelStyle: typography.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'Favori Pastaneler'),
                    Tab(text: 'Favori Ürünler'),
                  ],
                ),
              ),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : TabBarView(
                          children: [
                            _restaurants.isEmpty
                                ? const _FavoritesEmptyState()
                                : ListView.separated(
                                  padding: const EdgeInsets.all(
                                    Dimens.largePadding,
                                  ),
                                  itemCount: _restaurants.length,
                                  separatorBuilder:
                                      (_, __) =>
                                          const SizedBox(height: Dimens.padding),
                                  itemBuilder: (context, index) {
                                    final item = _restaurants[index];
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(
                                        Dimens.corners * 1.2,
                                      ),
                                      onTap: () {
                                        appPush(
                                          context,
                                          RestaurantProductsScreen(
                                            restaurantId: item.id,
                                            restaurantName: item.name,
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(
                                          Dimens.largePadding,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.white,
                                          borderRadius: BorderRadius.circular(
                                            Dimens.corners * 1.2,
                                          ),
                                          border: Border.all(
                                            color: colors.gray.withValues(
                                              alpha: 0.25,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(
                                                16,
                                              ),
                                              child: buildProductImage(
                                                item.photoPath ?? '',
                                                70,
                                                70,
                                              ),
                                            ),
                                            const SizedBox(
                                              width: Dimens.largePadding,
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: typography.bodyLarge
                                                        .copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                  Text(
                                                    item.type,
                                                    style: typography.bodySmall
                                                        .copyWith(
                                                          color: colors.gray4,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              onPressed:
                                                  () => _removeRestaurant(
                                                    item.id,
                                                  ),
                                              icon: Icon(
                                                Icons.favorite_border,
                                                color: colors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            _products.isEmpty
                                ? const _FavoritesEmptyState()
                                : ListView.separated(
                                  padding: const EdgeInsets.all(
                                    Dimens.largePadding,
                                  ),
                                  itemCount: _products.length,
                                  separatorBuilder:
                                      (_, __) =>
                                          const SizedBox(height: Dimens.padding),
                                  itemBuilder: (context, index) {
                                    final item = _products[index];
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(
                                        Dimens.corners * 1.2,
                                      ),
                                      onTap: () {
                                        appPush(
                                          context,
                                          ProductDetailsScreen(
                                            product: ProductModel(
                                              id: item.id,
                                              name: item.name,
                                              price: item.price.toDouble(),
                                              imageUrl: item.imagePath,
                                              restaurantId: item.restaurantId,
                                              restaurantName:
                                                  item.restaurantName,
                                              restaurantType: item.restaurantType,
                                              saleUnit: item.saleUnit == 1
                                                  ? ProductSaleUnit.perSlice
                                                  : ProductSaleUnit.perKilogram,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(
                                          Dimens.largePadding,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.white,
                                          borderRadius: BorderRadius.circular(
                                            Dimens.corners * 1.2,
                                          ),
                                          border: Border.all(
                                            color: colors.gray.withValues(
                                              alpha: 0.25,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(
                                                14,
                                              ),
                                              child: buildProductImage(
                                                item.imagePath,
                                                74,
                                                74,
                                              ),
                                            ),
                                            const SizedBox(
                                              width: Dimens.largePadding,
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: typography.bodyLarge
                                                        .copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                  Text(
                                                    formatPrice(item.price),
                                                    style: typography.bodyLarge
                                                        .copyWith(
                                                          color: colors.primary,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              onPressed:
                                                  () => _removeProduct(item.id),
                                              icon: Icon(
                                                Icons.favorite_border,
                                                color: colors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                          ],
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoritesEmptyState extends StatelessWidget {
  const _FavoritesEmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.restaurant_menu, size: 44, color: colors.gray4),
          const SizedBox(height: 16),
          Text(
            'Henüz favori ürün veya pastane eklemediniz.',
            style: typography.bodySmall.copyWith(color: colors.gray4),
          ),
        ],
      ),
    );
  }
}
