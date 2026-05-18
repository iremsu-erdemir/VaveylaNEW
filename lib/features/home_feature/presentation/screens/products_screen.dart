import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_search_bar.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_svg_viewer.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/product_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/sort_and_filter_screen.dart';

import '../../../../core/gen/assets.gen.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/general_app_bar.dart';
import '../../../../core/widgets/shaded_container.dart';
import '../../data/services/products_service.dart';
import '../bloc/all_products_cubit.dart';
import '../models/products_filter.dart';
import 'product_details_screen.dart';
import '../widgets/product_card.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, this.initialType, this.title = 'Ürünler'});

  final String? initialType;
  final String title;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  static const _closedRestaurantMessage =
      'Bu pastane şu anda hizmet verememektedir.';

  late final AllProductsCubit _productsCubit;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  ProductSortOption _sortOption = ProductSortOption.topRated;
  String? _selectedCategory;
  double? _userLat;
  double? _userLng;
  bool _isResolvingLocation = false;

  @override
  void initState() {
    super.initState();
    _productsCubit = AllProductsCubit(ProductsService())
      ..loadProducts(type: widget.initialType)
      ..startPolling();
  }

  @override
  void dispose() {
    _productsCubit.close();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _ensureCurrentLocation() async {
    if (_userLat != null && _userLng != null) {
      return;
    }
    if (_isResolvingLocation) {
      return;
    }
    setState(() => _isResolvingLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _userLat = position.latitude;
        _userLng = position.longitude;
      });
    } catch (_) {
      // If location fails, keep default ordering.
    } finally {
      if (mounted) {
        setState(() => _isResolvingLocation = false);
      }
    }
  }

  double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            (sin(dLng / 2) * sin(dLng / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (3.141592653589793 / 180.0);

  String _normalizeTr(String value) {
    var s = value.trim().toLowerCase();
    const map = {
      'ı': 'i',
      'ğ': 'g',
      'ü': 'u',
      'ş': 's',
      'ö': 'o',
      'ç': 'c',
      'İ': 'i',
    };
    map.forEach((from, to) {
      s = s.replaceAll(from, to);
    });
    return s;
  }

  bool _categoryMatches(ProductModel product) {
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      return true;
    }
    final productCategory = product.categoryName?.toString() ?? '';
    return _normalizeTr(productCategory) == _normalizeTr(_selectedCategory!);
  }

  List<ProductModel> _applyFilter(List<ProductModel> products) {
    final query = _normalizeTr(_searchQuery);
    var filtered =
        products.where((product) {
          final name = _normalizeTr(product.name.toString());
          final category = _normalizeTr(product.categoryName?.toString() ?? '');
          final categoryMatches = _categoryMatches(product);
          final searchMatches =
              query.isEmpty || name.contains(query) || category.contains(query);
          return categoryMatches && searchMatches;
        }).toList();

    switch (_sortOption) {
      case ProductSortOption.topRated:
        filtered.sort((a, b) => b.rate.compareTo(a.rate));
        break;
      case ProductSortOption.cheapest:
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case ProductSortOption.newest:
        filtered.sort((a, b) {
          final aDate =
              a.createdAtUtc ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate =
              b.createdAtUtc ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
        break;
      case ProductSortOption.nearest:
        if (_userLat == null || _userLng == null) {
          break;
        }
        filtered.sort((a, b) {
          final aLat = a.restaurantLat;
          final aLng = a.restaurantLng;
          final bLat = b.restaurantLat;
          final bLng = b.restaurantLng;
          if (aLat == null || aLng == null) return 1;
          if (bLat == null || bLng == null) return -1;
          final distA = _distanceKm(_userLat!, _userLng!, aLat, aLng);
          final distB = _distanceKm(_userLat!, _userLng!, bLat, bLng);
          return distA.compareTo(distB);
        });
        break;
    }
    return filtered;
  }

  Future<void> _openSortAndFilter(
    BuildContext blocContext, {
    required SortAndFilterMode mode,
  }) async {
    final state = blocContext.read<AllProductsCubit>().state;
    final categories =
        state.products
            .map((x) => x.categoryName?.trim() ?? '')
            .where((x) => x.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final result = await Navigator.of(context).push<ProductsFilter>(
      MaterialPageRoute(
        builder: (_) => SortAndFilterScreen(
          categories: categories,
          initialSort: _sortOption,
          initialCategory: _selectedCategory,
          mode: mode,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _sortOption = result.sort;
        _selectedCategory = result.category;
      });
      if (result.sort == ProductSortOption.nearest) {
        await _ensureCurrentLocation();
      }
    }
  }

  String _activeFilterLabel() {
    final parts = <String>[];
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      parts.add(_selectedCategory!);
    }
    if (_sortOption != ProductSortOption.topRated) {
      parts.add(_sortOption.label);
    }
    return parts.isEmpty ? '' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _productsCubit,
      child: Builder(
        builder: (blocContext) {
          final filterLabel = _activeFilterLabel();
          return AppScaffold(
            appBar: GeneralAppBar(
              title: widget.title,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(50),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: Dimens.largePadding,
                    right: Dimens.largePadding,
                  ),
                  child: AppSearchBar(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
              ),
              height: 128,
            ),
            body: Column(
              spacing: Dimens.largePadding,
              children: [
                const SizedBox.shrink(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  spacing: Dimens.largePadding,
                  children: [
                    InkWell(
                      onTap: () => _openSortAndFilter(
                        blocContext,
                        mode: SortAndFilterMode.filterOnly,
                      ),
                      borderRadius: BorderRadius.circular(100),
                      child: ShadedContainer(
                        padding: const EdgeInsets.all(Dimens.largePadding),
                        borderRadius: 100,
                        child: Row(
                          spacing: Dimens.padding,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppSvgViewer(Assets.icons.filterSearch, width: 16),
                            const Text('Filtreler'),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _openSortAndFilter(
                        blocContext,
                        mode: SortAndFilterMode.sortOnly,
                      ),
                      borderRadius: BorderRadius.circular(100),
                      child: ShadedContainer(
                        padding: const EdgeInsets.all(Dimens.largePadding),
                        borderRadius: 100,
                        child: Row(
                          spacing: Dimens.padding,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppSvgViewer(Assets.icons.sort, width: 16),
                            const Text('Sırala'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (filterLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimens.largePadding,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        label: Text(
                          filterLabel,
                          style: context.theme.appTypography.labelMedium,
                        ),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          setState(() {
                            _selectedCategory = null;
                            _sortOption = ProductSortOption.topRated;
                          });
                        },
                      ),
                    ),
                  ),
                Expanded(
                  child: BlocBuilder<AllProductsCubit, AllProductsState>(
                    builder: (context, state) {
                      if (state.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (_sortOption == ProductSortOption.nearest &&
                          _isResolvingLocation) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final products = _applyFilter(state.products);
                      if (products.isEmpty) {
                        return Center(
                          child: Text(
                            _searchQuery.isNotEmpty || _selectedCategory != null
                                ? 'Arama/filtreye uygun ürün bulunamadı.'
                                : 'Henüz ürün bulunamadı.',
                          ),
                        );
                      }
                      return GridView.builder(
                        key: ValueKey(
                          '${_sortOption.name}|${_selectedCategory ?? ''}|$_searchQuery',
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimens.largePadding,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: Dimens.largePadding,
                          crossAxisSpacing: Dimens.largePadding,
                          childAspectRatio: 0.65,
                        ),
                        itemCount: products.length,
                        itemBuilder: (final context, final index) {
                          final product = products[index];
                          final isRestaurantOpen = product.restaurantIsOpen;
                          return InkWell(
                            onTap: () {
                              if (!isRestaurantOpen) {
                                context.showErrorMessage(
                                  _closedRestaurantMessage,
                                );
                                return;
                              }
                              appPush(
                                context,
                                ProductDetailsScreen(product: product),
                              );
                            },
                            borderRadius: BorderRadius.circular(Dimens.corners),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ProductCard(product: product),
                                if (!isRestaurantOpen)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          color: Colors.grey.withValues(
                                            alpha: 0.35,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: Dimens.padding,
                                  right: Dimens.padding,
                                  child: Visibility(
                                    visible: !isRestaurantOpen,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: Dimens.smallPadding,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.7,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          Dimens.smallCorners,
                                        ),
                                      ),
                                      child: Text(
                                        'Kapalı',
                                        style: context
                                            .theme
                                            .appTypography
                                            .labelSmall
                                            .copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
