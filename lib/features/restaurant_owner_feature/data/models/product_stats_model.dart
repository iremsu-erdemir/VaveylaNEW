class ProductStat {
  ProductStat({
    required this.productId,
    required this.productName,
    required this.totalSold,
  });

  final String productId;
  final String productName;
  final int totalSold;

  factory ProductStat.fromJson(Map<String, dynamic> json) {
    return ProductStat(
      productId: json['productId']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      totalSold: _parseInt(json['totalSold']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class ProductStats {
  ProductStats({
    required this.bestSeller,
    required this.topProducts,
  });

  final ProductStat? bestSeller;
  final List<ProductStat> topProducts;

  factory ProductStats.fromJson(Map<String, dynamic> json) {
    final bestSellerJson = json['bestSeller'];
    final bestSeller = bestSellerJson is Map<String, dynamic>
        ? ProductStat.fromJson(bestSellerJson)
        : bestSellerJson is Map
            ? ProductStat.fromJson(bestSellerJson.cast<String, dynamic>())
            : null;

    final rawTopProducts = json['topProducts'];
    final topProducts = <ProductStat>[];
    if (rawTopProducts is List) {
      for (final item in rawTopProducts) {
        if (item is Map<String, dynamic>) {
          topProducts.add(ProductStat.fromJson(item));
        } else if (item is Map) {
          topProducts.add(ProductStat.fromJson(item.cast<String, dynamic>()));
        }
      }
    }

    return ProductStats(bestSeller: bestSeller, topProducts: topProducts);
  }
}

