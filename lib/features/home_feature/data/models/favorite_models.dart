class FavoriteRestaurantModel {
  FavoriteRestaurantModel({
    required this.id,
    required this.name,
    required this.type,
    this.photoPath,
  });

  final String id;
  final String name;
  final String type;
  final String? photoPath;

  factory FavoriteRestaurantModel.fromJson(Map<String, dynamic> json) {
    return FavoriteRestaurantModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Pastane',
      type: json['type']?.toString() ?? 'Kategori',
      photoPath: json['photoPath']?.toString(),
    );
  }
}

class FavoriteProductModel {
  FavoriteProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.imagePath,
    required this.restaurantId,
    required this.restaurantName,
    this.restaurantType,
    this.saleUnit = 0,
  });

  final String id;
  final String name;
  final int price;
  final String imagePath;
  final String restaurantId;
  final String restaurantName;
  final String? restaurantType;

  /// API: 0 = kilo, 1 = dilim (menu ile aynı).
  final int saleUnit;

  factory FavoriteProductModel.fromJson(Map<String, dynamic> json) {
    return FavoriteProductModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Ürün',
      price: _parseInt(json['price']),
      imagePath: json['imagePath']?.toString() ?? '',
      restaurantId: json['restaurantId']?.toString() ?? '',
      restaurantName: json['restaurantName']?.toString() ?? 'Pastane',
      restaurantType: json['restaurantType']?.toString(),
      saleUnit: _parseInt(json['saleUnit']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class CustomerFavoritesModel {
  CustomerFavoritesModel({
    required this.restaurants,
    required this.products,
  });

  final List<FavoriteRestaurantModel> restaurants;
  final List<FavoriteProductModel> products;

  factory CustomerFavoritesModel.fromJson(Map<String, dynamic> json) {
    final restaurantsRaw = json['restaurants'];
    final productsRaw = json['products'];
    return CustomerFavoritesModel(
      restaurants:
          restaurantsRaw is List
              ? restaurantsRaw
                  .whereType<Map>()
                  .map(
                    (item) => FavoriteRestaurantModel.fromJson(
                      item.cast<String, dynamic>(),
                    ),
                  )
                  .toList()
              : const [],
      products:
          productsRaw is List
              ? productsRaw
                  .whereType<Map>()
                  .map(
                    (item) =>
                        FavoriteProductModel.fromJson(item.cast<String, dynamic>()),
                  )
                  .toList()
              : const [],
    );
  }
}
