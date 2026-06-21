class CustomerChatConversationModel {
  CustomerChatConversationModel({
    required this.restaurantId,
    required this.restaurantName,
    required this.lastMessage,
    required this.lastMessageSenderType,
    required this.lastMessageAtUtc,
    required this.messageCount,
    this.kind = 'restaurant',
    this.orderId,
    this.courierName,
    this.orderItemsPreview,
  });

  final String restaurantId;
  final String restaurantName;
  final String lastMessage;
  final String lastMessageSenderType;
  final DateTime lastMessageAtUtc;
  final int messageCount;

  /// `restaurant` (pastane) veya `delivery` (kurye teslimat).
  final String kind;
  final String? orderId;

  /// Teslimat: atanmış kurye tam adı (API / sipariş).
  final String? courierName;

  /// Teslimat: sipariş ürün özeti (liste alt satırı).
  final String? orderItemsPreview;

  bool get isDelivery => kind.toLowerCase() == 'delivery';

  /// Liste başlığı — teslimatta kurye adı veya kurye yoksa açıklayıcı metin.
  String get deliveryListTitle {
    if (!isDelivery) {
      return restaurantName;
    }
    final c = courierName?.trim();
    if (c != null && c.isNotEmpty) {
      return c;
    }
    return 'Teslimat (kurye ataması yapılmamış)';
  }

  /// Atanmış kurye adı var mı (liste ikonu / başlık ayrımı için).
  bool get hasAssignedCourier {
    if (!isDelivery) return false;
    final c = courierName?.trim();
    return c != null && c.isNotEmpty;
  }

  /// Ürün özeti metni.
  String get deliveryOrderPreview {
    if (!isDelivery) {
      return '';
    }
    final o = orderItemsPreview?.trim();
    if (o != null && o.isNotEmpty) {
      return o;
    }
    const sep = ' — ';
    final i = restaurantName.indexOf(sep);
    if (i >= 0) {
      return restaurantName.substring(i + sep.length).trim();
    }
    return '';
  }

  /// Teslimat sohbeti tam ekran başlığı.
  String get deliveryChatAppBarTitle {
    final p = deliveryOrderPreview;
    final c = courierName?.trim();
    if (c != null && c.isNotEmpty) {
      return '$c · $p';
    }
    if (p.isEmpty) {
      return 'Teslimat (kurye ataması yapılmamış)';
    }
    return 'Teslimat (kurye ataması yapılmamış) · $p';
  }

  static DateTime _parseUtc(dynamic value) {
    if (value == null) return DateTime.now().toUtc();
    if (value is DateTime) return value.toUtc();
    final s = value.toString().trim();
    if (s.isEmpty) return DateTime.now().toUtc();

    final hasTimeZone = RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(s);
    final normalized = hasTimeZone ? s : '${s}Z';
    return DateTime.tryParse(normalized)?.toUtc() ?? DateTime.now().toUtc();
  }

  factory CustomerChatConversationModel.fromJson(Map<String, dynamic> json) {
    final oid = json['orderId']?.toString() ?? json['OrderId']?.toString();
    final k =
        json['kind']?.toString() ??
        json['Kind']?.toString() ??
        (oid != null && oid.isNotEmpty ? 'delivery' : 'restaurant');
    final restaurantName =
        json['restaurantName']?.toString() ??
        json['RestaurantName']?.toString() ??
        'Pastane';
    var courierName =
        json['courierName']?.toString() ?? json['CourierName']?.toString();
    var orderItemsPreview =
        json['orderItemsPreview']?.toString() ??
        json['OrderItemsPreview']?.toString();
    courierName = courierName?.trim();
    orderItemsPreview = orderItemsPreview?.trim();
    if (courierName != null && courierName.isEmpty) {
      courierName = null;
    }
    if (orderItemsPreview != null && orderItemsPreview.isEmpty) {
      orderItemsPreview = null;
    }
    if (k.toLowerCase() == 'delivery' &&
        (orderItemsPreview == null || orderItemsPreview.isEmpty)) {
      const sep = ' — ';
      final i = restaurantName.indexOf(sep);
      if (i >= 0) {
        orderItemsPreview = restaurantName.substring(i + sep.length).trim();
        final left = restaurantName.substring(0, i).trim();
        if ((courierName?.isEmpty ?? true) &&
            left.isNotEmpty &&
            left != 'Teslimat') {
          courierName = left;
        }
      }
    }
    return CustomerChatConversationModel(
      restaurantId:
          json['restaurantId']?.toString() ??
          json['RestaurantId']?.toString() ??
          '',
      restaurantName: restaurantName,
      lastMessage:
          json['lastMessage']?.toString() ??
          json['LastMessage']?.toString() ??
          '',
      lastMessageSenderType:
          json['lastMessageSenderType']?.toString() ??
          json['LastMessageSenderType']?.toString() ??
          'customer',
      lastMessageAtUtc: _parseUtc(
        json['lastMessageAtUtc'] ?? json['LastMessageAtUtc'],
      ),
      messageCount: () {
        final raw = json['messageCount'] ?? json['MessageCount'];
        if (raw is int) return raw;
        if (raw is num) return raw.toInt();
        return int.tryParse(raw?.toString() ?? '') ?? 0;
      }(),
      kind: k,
      orderId: oid?.trim().isEmpty == true ? null : oid?.trim(),
      courierName: courierName,
      orderItemsPreview: orderItemsPreview,
    );
  }
}
