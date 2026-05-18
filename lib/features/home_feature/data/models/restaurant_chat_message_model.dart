class RestaurantChatMessageModel {
  RestaurantChatMessageModel({
    required this.id,
    required this.restaurantId,
    required this.customerUserId,
    required this.senderUserId,
    required this.senderType,
    required this.senderName,
    required this.message,
    required this.createdAtUtc,
  });

  final String id;
  final String restaurantId;
  final String customerUserId;
  final String senderUserId;
  final String senderType;
  final String senderName;
  final String message;
  final DateTime createdAtUtc;

  bool get isCustomer => senderType.toLowerCase() == 'customer';

  static DateTime _parseUtc(dynamic value) {
    if (value == null) return DateTime.now().toUtc();
    if (value is DateTime) return value.toUtc();
    final s = value.toString().trim();
    if (s.isEmpty) return DateTime.now().toUtc();

    final hasTimeZone = RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(s);
    final normalized = hasTimeZone ? s : '${s}Z';
    return DateTime.tryParse(normalized)?.toUtc() ?? DateTime.now().toUtc();
  }

  factory RestaurantChatMessageModel.fromJson(Map<String, dynamic> json) {
    return RestaurantChatMessageModel(
      id: json['id']?.toString() ?? '',
      restaurantId: json['restaurantId']?.toString() ?? '',
      customerUserId: json['customerUserId']?.toString() ?? '',
      senderUserId: json['senderUserId']?.toString() ?? '',
      senderType: json['senderType']?.toString() ?? 'customer',
      senderName: json['senderName']?.toString() ?? 'Kullanıcı',
      message: json['message']?.toString() ?? '',
      createdAtUtc: _parseUtc(json['createdAtUtc']),
    );
  }
}
