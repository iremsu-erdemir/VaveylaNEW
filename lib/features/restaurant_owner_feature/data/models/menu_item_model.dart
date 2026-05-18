class MenuItemModel {
  MenuItemModel({
    required this.id,
    required this.name,
    required this.price,
    required this.imagePath,
    this.categoryName,
    this.isAvailable = true,
    this.isFeatured = false,
    this.saleUnit = 0,
  });

  final String id;
  final String name;
  final int price;
  final String imagePath;
  final String? categoryName;
  final bool isAvailable;
  final bool isFeatured;
  /// 0 = kg başına fiyat, 1 = dilim başına fiyat (API ile aynı).
  final int saleUnit;

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    return MenuItemModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: _parseInt(json['price']),
      imagePath: json['imagePath']?.toString() ?? '',
      categoryName: json['categoryName']?.toString(),
      isAvailable: json['isAvailable'] == true || json['isAvailable'] == 1,
      isFeatured: json['isFeatured'] == true || json['isFeatured'] == 1,
      saleUnit: _parseSaleUnit(json['saleUnit']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'imagePath': imagePath,
      'categoryName': categoryName,
      'isAvailable': isAvailable,
      'isFeatured': isFeatured,
      'saleUnit': saleUnit,
    };
  }

  static int _parseSaleUnit(dynamic value) {
    if (value is int) return value == 1 ? 1 : 0;
    final n = int.tryParse(value?.toString() ?? '');
    if (n == 1) return 1;
    return 0;
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  MenuItemModel copyWith({
    String? id,
    String? name,
    int? price,
    String? imagePath,
    String? categoryName,
    bool? isAvailable,
    bool? isFeatured,
    int? saleUnit,
  }) {
    return MenuItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      imagePath: imagePath ?? this.imagePath,
      categoryName: categoryName ?? this.categoryName,
      isAvailable: isAvailable ?? this.isAvailable,
      isFeatured: isFeatured ?? this.isFeatured,
      saleUnit: saleUnit ?? this.saleUnit,
    );
  }
}
