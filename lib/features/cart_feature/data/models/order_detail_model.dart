class OrderDetailModel {
  OrderDetailModel({
    required this.id,
    required this.orderNumber,
    required this.restaurantId,
    this.restaurantName,
    required this.status,
    required this.createdAtUtc,
    this.deliveryAddress,
    this.deliveryAddressDetail,
    this.courierName,
    this.paymentMethod,
    this.orderNotes,
    required this.subtotal,
    required this.deliveryFee,
    required this.totalDiscount,
    required this.couponDiscount,
    required this.total,
    this.minimumOrderAmount,
    required this.meetsMinimumOrder,
    this.cancellationReason,
    this.rejectionReason,
    required this.lineItems,
    required this.statusHistory,
    required this.canCancel,
    required this.canRequestRefund,
    required this.canReorder,
  });

  final String id;
  final String orderNumber;
  final String restaurantId;
  final String? restaurantName;
  final String status;
  final DateTime createdAtUtc;
  final String? deliveryAddress;
  final String? deliveryAddressDetail;
  final String? courierName;
  final String? paymentMethod;
  final String? orderNotes;
  final double subtotal;
  final double deliveryFee;
  final double totalDiscount;
  final double couponDiscount;
  final double total;
  final double? minimumOrderAmount;
  final bool meetsMinimumOrder;
  final String? cancellationReason;
  final String? rejectionReason;
  final List<OrderLineItemModel> lineItems;
  final List<OrderStatusHistoryModel> statusHistory;
  final bool canCancel;
  final bool canRequestRefund;
  final bool canReorder;

  factory OrderDetailModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }

    final itemsRaw = json['lineItems'];
    final historyRaw = json['statusHistory'];

    return OrderDetailModel(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      restaurantId: json['restaurantId']?.toString() ?? '',
      restaurantName: json['restaurantName']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      createdAtUtc: DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ??
          DateTime.now(),
      deliveryAddress: json['deliveryAddress']?.toString(),
      deliveryAddressDetail: json['deliveryAddressDetail']?.toString(),
      courierName: json['courierName']?.toString(),
      paymentMethod: json['paymentMethod']?.toString(),
      orderNotes: json['orderNotes']?.toString(),
      subtotal: parseDouble(json['subtotal']),
      deliveryFee: parseDouble(json['deliveryFee']),
      totalDiscount: parseDouble(json['totalDiscount']),
      couponDiscount: parseDouble(json['couponDiscount']),
      total: parseDouble(json['total']),
      minimumOrderAmount: json['minimumOrderAmount'] == null
          ? null
          : parseDouble(json['minimumOrderAmount']),
      meetsMinimumOrder: json['meetsMinimumOrder'] != false,
      cancellationReason: json['cancellationReason']?.toString(),
      rejectionReason: json['rejectionReason']?.toString(),
      lineItems: itemsRaw is List
          ? itemsRaw
              .whereType<Map>()
              .map((e) => OrderLineItemModel.fromJson(e.cast<String, dynamic>()))
              .toList()
          : [],
      statusHistory: historyRaw is List
          ? historyRaw
              .whereType<Map>()
              .map(
                (e) =>
                    OrderStatusHistoryModel.fromJson(e.cast<String, dynamic>()),
              )
              .toList()
          : [],
      canCancel: json['canCancel'] == true,
      canRequestRefund: json['canRequestRefund'] == true,
      canReorder: json['canReorder'] != false,
    );
  }
}

class OrderLineItemModel {
  OrderLineItemModel({
    required this.productId,
    required this.productName,
    this.imagePath,
    required this.quantity,
    required this.weightKg,
    required this.saleUnit,
    required this.unitPrice,
    required this.lineTotal,
    this.variationJson,
  });

  final String productId;
  final String productName;
  final String? imagePath;
  final int quantity;
  final double weightKg;
  final int saleUnit;
  final double unitPrice;
  final double lineTotal;
  final String? variationJson;

  factory OrderLineItemModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }

    return OrderLineItemModel(
      productId: json['productId']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      imagePath: json['imagePath']?.toString(),
      quantity: int.tryParse(json['quantity']?.toString() ?? '') ?? 1,
      weightKg: parseDouble(json['weightKg']),
      saleUnit: int.tryParse(json['saleUnit']?.toString() ?? '') ?? 0,
      unitPrice: parseDouble(json['unitPrice']),
      lineTotal: parseDouble(json['lineTotal']),
      variationJson: json['variationJson']?.toString(),
    );
  }

  String get quantityLabel =>
      saleUnit == 1 ? '$quantity dilim' : '${weightKg} kg × $quantity';
}

class OrderStatusHistoryModel {
  OrderStatusHistoryModel({
    required this.status,
    this.note,
    this.actorRole,
    required this.createdAtUtc,
  });

  final String status;
  final String? note;
  final String? actorRole;
  final DateTime createdAtUtc;

  factory OrderStatusHistoryModel.fromJson(Map<String, dynamic> json) {
    return OrderStatusHistoryModel(
      status: json['status']?.toString() ?? '',
      note: json['note']?.toString(),
      actorRole: json['actorRole']?.toString(),
      createdAtUtc: DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class RefundRequestModel {
  RefundRequestModel({
    required this.refundRequestId,
    required this.orderId,
    required this.orderNumber,
    this.restaurantName,
    required this.status,
    required this.reason,
    this.reasonNote,
    this.restaurantResponse,
    required this.createdAtUtc,
    this.resolvedAtUtc,
    required this.statusHistory,
  });

  final String refundRequestId;
  final String orderId;
  final String orderNumber;
  final String? restaurantName;
  final String status;
  final String reason;
  final String? reasonNote;
  final String? restaurantResponse;
  final DateTime createdAtUtc;
  final DateTime? resolvedAtUtc;
  final List<OrderStatusHistoryModel> statusHistory;

  factory RefundRequestModel.fromJson(Map<String, dynamic> json) {
    final historyRaw = json['statusHistory'];
    return RefundRequestModel(
      refundRequestId: json['refundRequestId']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      restaurantName: json['restaurantName']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      reason: json['reason']?.toString() ?? '',
      reasonNote: json['reasonNote']?.toString(),
      restaurantResponse: json['restaurantResponse']?.toString(),
      createdAtUtc: DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ??
          DateTime.now(),
      resolvedAtUtc: json['resolvedAtUtc'] == null
          ? null
          : DateTime.tryParse(json['resolvedAtUtc'].toString()),
      statusHistory: historyRaw is List
          ? historyRaw
              .whereType<Map>()
              .map(
                (e) =>
                    OrderStatusHistoryModel.fromJson(e.cast<String, dynamic>()),
              )
              .toList()
          : [],
    );
  }
}
