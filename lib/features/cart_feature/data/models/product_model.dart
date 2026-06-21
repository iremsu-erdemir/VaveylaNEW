/// API [saleUnit]: 0 = kg başına fiyat, 1 = dilim başına fiyat.
enum ProductSaleUnit {
  perKilogram,
  perSlice,
}

ProductSaleUnit productSaleUnitFromApi(dynamic value) {
  if (value == null) return ProductSaleUnit.perKilogram;
  if (value is int) {
    return value == 1 ? ProductSaleUnit.perSlice : ProductSaleUnit.perKilogram;
  }
  final n = int.tryParse(value.toString());
  if (n == 1) return ProductSaleUnit.perSlice;
  return ProductSaleUnit.perKilogram;
}

class ProductModel {
  final String id;
  final String name;
  final double price;
  final double weight;
  final double rate;
  final int reviewCount;
  final String imageUrl;
  final String? restaurantId;
  final String? restaurantName;
  final String? restaurantPhotoPath;
  final String? restaurantType;
  final String? restaurantAddress;
  final String? restaurantPhone;
  final double? restaurantLat;
  final double? restaurantLng;
  final int? estimatedDeliveryMinutes;
  final bool restaurantIsOpen;
  final String? categoryName;
  final bool isFeatured;
  final DateTime? createdAtUtc;
  final ProductSaleUnit saleUnit;

  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    this.weight = 1.0,
    this.rate = 0.0,
    this.reviewCount = 0,
    required this.imageUrl,
    this.restaurantId,
    this.restaurantName,
    this.restaurantPhotoPath,
    this.restaurantType,
    this.restaurantAddress,
    this.restaurantPhone,
    this.restaurantLat,
    this.restaurantLng,
    this.estimatedDeliveryMinutes,
    this.restaurantIsOpen = true,
    this.categoryName,
    this.isFeatured = false,
    this.createdAtUtc,
    this.saleUnit = ProductSaleUnit.perKilogram,
  });

  ProductModel copyWith({
    String? id,
    String? name,
    double? price,
    double? weight,
    double? rate,
    int? reviewCount,
    String? imageUrl,
    String? restaurantId,
    String? restaurantName,
    String? restaurantPhotoPath,
    String? restaurantType,
    String? restaurantAddress,
    String? restaurantPhone,
    double? restaurantLat,
    double? restaurantLng,
    int? estimatedDeliveryMinutes,
    bool? restaurantIsOpen,
    String? categoryName,
    bool? isFeatured,
    DateTime? createdAtUtc,
    ProductSaleUnit? saleUnit,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      weight: weight ?? this.weight,
      rate: rate ?? this.rate,
      reviewCount: reviewCount ?? this.reviewCount,
      imageUrl: imageUrl ?? this.imageUrl,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      restaurantPhotoPath: restaurantPhotoPath ?? this.restaurantPhotoPath,
      restaurantType: restaurantType ?? this.restaurantType,
      restaurantAddress: restaurantAddress ?? this.restaurantAddress,
      restaurantPhone: restaurantPhone ?? this.restaurantPhone,
      restaurantLat: restaurantLat ?? this.restaurantLat,
      restaurantLng: restaurantLng ?? this.restaurantLng,
      estimatedDeliveryMinutes:
          estimatedDeliveryMinutes ?? this.estimatedDeliveryMinutes,
      restaurantIsOpen: restaurantIsOpen ?? this.restaurantIsOpen,
      categoryName: categoryName ?? this.categoryName,
      isFeatured: isFeatured ?? this.isFeatured,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      saleUnit: saleUnit ?? this.saleUnit,
    );
  }

  factory ProductModel.fromApiJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] is int ? (json['price'] as int).toDouble() : double.tryParse(json['price']?.toString() ?? '') ?? 0),
      rate: _parseDouble(json['rating']) ?? 0,
      reviewCount: _parseInt(json['reviewCount']),
      imageUrl: json['imagePath']?.toString() ?? '',
      restaurantId: json['restaurantId']?.toString(),
      restaurantName:
          json['restaurantName']?.toString() ?? json['RestaurantName']?.toString(),
      restaurantPhotoPath: json['restaurantPhotoPath']?.toString(),
      restaurantType: json['restaurantType']?.toString(),
      restaurantAddress: json['restaurantAddress']?.toString(),
      restaurantPhone: json['restaurantPhone']?.toString(),
      restaurantLat: _parseDouble(json['restaurantLat']),
      restaurantLng: _parseDouble(json['restaurantLng']),
      estimatedDeliveryMinutes: _parseIntNullable(json['estimatedDeliveryMinutes']),
      restaurantIsOpen:
          json['restaurantIsOpen'] == true || json['restaurantIsOpen'] == 1,
      categoryName: json['categoryName']?.toString(),
      isFeatured: json['isFeatured'] == true || json['isFeatured'] == 1,
      createdAtUtc: _parseDateTime(json['createdAtUtc']),
      saleUnit: productSaleUnitFromApi(
        json['saleUnit'] ?? json['SaleUnit'],
      ),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final s = value.toString();
    return DateTime.tryParse(s);
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _parseIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
