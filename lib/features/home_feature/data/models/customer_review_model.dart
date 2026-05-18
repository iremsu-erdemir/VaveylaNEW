class CustomerReviewModel {
  CustomerReviewModel({
    required this.id,
    required this.restaurantId,
    required this.targetType,
    required this.targetId,
    required this.productId,
    required this.customerUserId,
    required this.customerName,
    required this.rating,
    required this.comment,
    required this.date,
    this.ownerReply,
  });

  final String id;
  final String restaurantId;
  final String targetType;
  final String targetId;
  final String productId;
  final String customerUserId;
  final String customerName;
  final int rating;
  final String comment;
  final String date;
  final String? ownerReply;

  factory CustomerReviewModel.fromJson(Map<String, dynamic> json) {
    return CustomerReviewModel(
      id: json['id']?.toString() ?? '',
      restaurantId: json['restaurantId']?.toString() ?? '',
      targetType: json['targetType']?.toString() ?? '',
      targetId: json['targetId']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      customerUserId: json['customerUserId']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? 'Müşteri',
      rating: _parseInt(json['rating']),
      comment: json['comment']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      ownerReply: json['ownerReply']?.toString(),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
