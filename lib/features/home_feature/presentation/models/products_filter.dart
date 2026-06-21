enum ProductSortOption { topRated, nearest, newest, cheapest }

extension ProductSortOptionLabel on ProductSortOption {
  String get label {
    switch (this) {
      case ProductSortOption.topRated:
        return 'En yüksek puan';
      case ProductSortOption.nearest:
        return 'En yakın';
      case ProductSortOption.newest:
        return 'En yeni';
      case ProductSortOption.cheapest:
        return 'En uygun';
    }
  }
}

class ProductsFilter {
  const ProductsFilter({
    required this.sort,
    this.category,
  });

  final ProductSortOption sort;
  final String? category;
}
