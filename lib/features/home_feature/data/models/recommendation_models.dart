import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/product_model.dart';

enum ProductCategory { sweet, savory, drink, snack, bakery, unknown }

ProductCategory productCategoryFromRaw(dynamic raw) {
  final value = raw?.toString().trim().toLowerCase() ?? '';
  return switch (value) {
    'sweet' => ProductCategory.sweet,
    'savory' => ProductCategory.savory,
    'drink' => ProductCategory.drink,
    'snack' => ProductCategory.snack,
    'bakery' => ProductCategory.bakery,
    _ => ProductCategory.unknown,
  };
}

enum RecommendationFilterType { chocolate, fruit, any, bakery, drink, savory }

RecommendationFilterType recommendationFilterTypeFromRaw(String raw) {
  final value = raw.trim().toLowerCase();
  return switch (value) {
    'chocolate' => RecommendationFilterType.chocolate,
    'fruit' => RecommendationFilterType.fruit,
    'bakery' => RecommendationFilterType.bakery,
    'drink' => RecommendationFilterType.drink,
    'savory' => RecommendationFilterType.savory,
    _ => RecommendationFilterType.any,
  };
}

class RecommendationFilterOption {
  const RecommendationFilterOption({
    required this.id,
    required this.label,
    required this.apiPreference,
  });

  final String id;
  final String label;
  final String apiPreference;

  factory RecommendationFilterOption.fromJson(Map<String, dynamic> json) {
    final apiPreference =
        json['apiPreference']?.toString() ?? json['id']?.toString() ?? '';
    return RecommendationFilterOption(
      id: json['id']?.toString() ?? apiPreference,
      label: json['label']?.toString() ?? apiPreference,
      apiPreference: apiPreference,
    );
  }
}

class RecommendationItem {
  const RecommendationItem({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.name,
    required this.shortDescription,
    required this.imagePath,
    required this.price,
    required this.saleUnit,
    required this.score,
    required this.reason,
    required this.category,
    required this.subcategory,
    required this.tags,
    required this.isActive,
  });

  final String id;
  final String restaurantId;
  final String? restaurantName;
  final String name;
  final String shortDescription;
  final String imagePath;
  final int price;
  final int saleUnit;
  final double score;
  final String reason;
  final ProductCategory category;
  final String subcategory;
  final List<String> tags;
  final bool isActive;

  factory RecommendationItem.fromJson(Map<String, dynamic> json) {
    return RecommendationItem(
      id: json['id']?.toString() ?? '',
      restaurantId: json['restaurantId']?.toString() ?? '',
      restaurantName: json['restaurantName']?.toString(),
      name: json['name']?.toString() ?? '',
      shortDescription: json['shortDescription']?.toString() ?? '',
      imagePath: json['imageUrl']?.toString() ?? json['imagePath']?.toString() ?? '',
      price: int.tryParse(json['price']?.toString() ?? '') ?? 0,
      saleUnit: int.tryParse(json['saleUnit']?.toString() ?? '') ?? 0,
      score: (json['score'] is num)
          ? (json['score'] as num).toDouble()
          : double.tryParse(json['score']?.toString() ?? '') ?? 0,
      reason: json['reason']?.toString() ?? '',
      category: productCategoryFromRaw(json['category']),
      subcategory: json['subcategory']?.toString() ?? '',
      tags: (json['tags'] is List)
          ? (json['tags'] as List<dynamic>)
              .map((e) => e.toString().trim().toLowerCase())
              .where((e) => e.isNotEmpty)
              .toList()
          : const <String>[],
      isActive: json['isActive'] != false,
    );
  }

  ProductModel toProductModel() {
    return ProductModel.fromApiJson(<String, dynamic>{
      'id': id,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName ?? '',
      'name': name,
      'price': price,
      'rating': 0,
      'reviewCount': 0,
      'imagePath': imagePath,
      'saleUnit': saleUnit,
      'restaurantIsOpen': true,
      'categoryName': category.name,
    });
  }

  RecommendationItem copyWith({
    String? reason,
    double? score,
  }) {
    return RecommendationItem(
      id: id,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      name: name,
      shortDescription: shortDescription,
      imagePath: imagePath,
      price: price,
      saleUnit: saleUnit,
      score: score ?? this.score,
      reason: reason ?? this.reason,
      category: category,
      subcategory: subcategory,
      tags: tags,
      isActive: isActive,
    );
  }
}

class RecommendationResult {
  const RecommendationResult({
    required this.products,
    required this.appliedFilter,
    required this.excludedProducts,
    required this.reason,
    required this.availableFilters,
  });

  final List<RecommendationItem> products;
  final String appliedFilter;
  final List<String> excludedProducts;
  final String reason;
  final List<RecommendationFilterOption> availableFilters;
}
