DateTime _parseUtc(dynamic value) {
  if (value == null) return DateTime.now().toUtc();
  if (value is DateTime) return value.toUtc();
  final s = value.toString().trim();
  if (s.isEmpty) return DateTime.now().toUtc();

  final hasTimeZone = RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(s);
  final normalized = hasTimeZone ? s : '${s}Z';
  return DateTime.tryParse(normalized)?.toUtc() ?? DateTime.now().toUtc();
}

class OwnerChatConversationModel {
  OwnerChatConversationModel({
    required this.customerUserId,
    required this.customerName,
    required this.lastMessage,
    required this.lastMessageSenderType,
    required this.lastMessageAtUtc,
    required this.messageCount,
  });

  final String customerUserId;
  final String customerName;
  final String lastMessage;
  final String lastMessageSenderType;
  final DateTime lastMessageAtUtc;
  final int messageCount;

  factory OwnerChatConversationModel.fromJson(Map<String, dynamic> json) {
    return OwnerChatConversationModel(
      customerUserId: json['customerUserId']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? 'Müşteri',
      lastMessage: json['lastMessage']?.toString() ?? '',
      lastMessageSenderType: json['lastMessageSenderType']?.toString() ?? 'customer',
      lastMessageAtUtc: _parseUtc(json['lastMessageAtUtc'] ?? json['LastMessageAtUtc']),
      messageCount: _parseInt(json['messageCount']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class OwnerChatMessageModel {
  OwnerChatMessageModel({
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

  bool get isRestaurant => senderType.toLowerCase() == 'restaurant';

  factory OwnerChatMessageModel.fromJson(Map<String, dynamic> json) {
    return OwnerChatMessageModel(
      id: json['id']?.toString() ?? '',
      restaurantId: json['restaurantId']?.toString() ?? '',
      customerUserId: json['customerUserId']?.toString() ?? '',
      senderUserId: json['senderUserId']?.toString() ?? '',
      senderType: json['senderType']?.toString() ?? 'customer',
      senderName: json['senderName']?.toString() ?? 'Kullanıcı',
      message: json['message']?.toString() ?? '',
      createdAtUtc: _parseUtc(json['createdAtUtc'] ?? json['CreatedAtUtc']),
    );
  }
}
