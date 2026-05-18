import 'package:flutter_sweet_shop_app_ui/core/services/google_geocoding_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/product_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/services/products_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/map_feature/models/sweet_shop.dart';
import 'package:latlong2/latlong.dart';

class MapShopsService {
  MapShopsService({
    ProductsService? productsService,
    GoogleGeocodingService? geocodingService,
  }) : _productsService = productsService ?? ProductsService(),
       _geocodingService = geocodingService ?? GoogleGeocodingService();

  final ProductsService _productsService;
  final GoogleGeocodingService _geocodingService;
  final Map<String, LatLng?> _geocodeCache = <String, LatLng?>{};

  Future<List<SweetShop>> getShops() async {
    final products = await _productsService.getProducts(type: 'all');
    final byRestaurant = <String, List<ProductModel>>{};
    for (final product in products) {
      final restaurantId = product.restaurantId;
      if (restaurantId == null || restaurantId.isEmpty) {
        continue;
      }
      byRestaurant.putIfAbsent(restaurantId, () => <ProductModel>[]).add(product);
    }

    final stores = <SweetShop>[];
    for (final entry in byRestaurant.entries) {
      final first = entry.value.first;
      final categorySummary = _buildCategorySummary(entry.value);
      final estimatedMinutes = first.estimatedDeliveryMinutes ?? 15;
      final resolvedLocation = await _resolveLocation(first);
      final location = resolvedLocation.$1;
      final locationStatus = resolvedLocation.$2;
      stores.add(
        SweetShop(
          id: entry.key,
          name: first.restaurantName?.trim().isNotEmpty == true
              ? first.restaurantName!.trim()
              : 'Pastane',
          address: first.restaurantAddress?.trim().isNotEmpty == true
              ? first.restaurantAddress!.trim()
              : 'Adres bilgisi yok',
          location: location,
          description: categorySummary,
          deliveryInfo: '$estimatedMinutes dk, Tahmini teslimat',
          imageUrl: _resolveImage(first),
          estimatedDeliveryMinutes: estimatedMinutes,
          locationStatus: locationStatus,
        ),
      );
    }

    stores.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return stores;
  }

  static String _buildCategorySummary(List<ProductModel> products) {
    final categories = products
        .map((x) => x.categoryName?.trim())
        .whereType<String>()
        .where((x) => x.isNotEmpty)
        .toSet()
        .take(3)
        .toList();
    if (categories.isNotEmpty) {
      return categories.join(', ');
    }
    final names = products.map((x) => x.name.trim()).where((x) => x.isNotEmpty).take(2).toList();
    if (names.isNotEmpty) {
      return names.join(', ');
    }
    return 'Tatli cesitleri';
  }

  static String _resolveImage(ProductModel product) {
    if (product.restaurantPhotoPath?.isNotEmpty == true) {
      return product.restaurantPhotoPath!;
    }
    return product.imageUrl;
  }

  Future<(LatLng?, ShopLocationStatus)> _resolveLocation(
    ProductModel product,
  ) async {
    final lat = product.restaurantLat;
    final lng = product.restaurantLng;
    if (lat != null && lng != null) {
      return (LatLng(lat, lng), ShopLocationStatus.backendCoordinates);
    }

    final address = product.restaurantAddress?.trim() ?? '';
    if (address.isNotEmpty) {
      final cached = _geocodeCache[address];
      if (cached != null) {
        return (cached, ShopLocationStatus.geocodedFromAddress);
      }
      if (_geocodeCache.containsKey(address) && cached == null) {
        return (null, ShopLocationStatus.unavailable);
      }
      final geocode = await _geocodingService.geocodeAddress(address);
      if (geocode != null) {
        final resolved = LatLng(geocode.latitude, geocode.longitude);
        _geocodeCache[address] = resolved;
        return (resolved, ShopLocationStatus.geocodedFromAddress);
      }
      _geocodeCache[address] = null;
    }

    return (null, ShopLocationStatus.unavailable);
  }
}
