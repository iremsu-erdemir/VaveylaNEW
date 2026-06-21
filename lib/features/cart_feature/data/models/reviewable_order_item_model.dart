class ReviewableOrderItemModel {
  ReviewableOrderItemModel({
    required this.id,
    required this.name,
    required this.imagePath,
  });

  final String id;
  final String name;
  final String imagePath;

  factory ReviewableOrderItemModel.fromJson(Map<String, dynamic> json) {
    return ReviewableOrderItemModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imagePath: json['imagePath']?.toString() ?? '',
    );
  }
}
