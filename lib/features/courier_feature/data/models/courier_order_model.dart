enum CourierOrderStatus {
  assigned, // Atanmış - Teslim alınacak
  pickedUp, // Alındı - Pastaneden alındı
  inTransit, // Yolda - Müşteriye gidiliyor
  delivered, // Teslim edildi
}

class CourierOrderModel {
  CourierOrderModel({
    required this.id,
    required this.time,
    required this.date,
    this.createdAtUtc,
    required this.imagePath,
    this.preparationMinutes,
    required this.items,
    required this.total,
    this.totalDiscount = 0,
    double? customerPaidAmount,
    this.restaurantEarning = 0,
    this.platformEarning = 0,
    required this.status,
    required this.customerAddress,
    this.customerLat,
    this.customerLng,
    this.restaurantName,
    this.restaurantAddress,
    this.restaurantLat,
    this.restaurantLng,
    this.customerName,
    this.customerPhone,
    this.customerUserId,
    this.assignedCourierUserId,
    this.courierDeclined = false,
    this.courierDeclineReason,
  }) : customerPaidAmount = customerPaidAmount ?? total.toDouble();

  final String id;
  final String time;
  final String date;
  final DateTime? createdAtUtc;
  final String imagePath;
  final int? preparationMinutes;
  final String items;
  final int total;
  final double totalDiscount;
  final double customerPaidAmount;
  final double restaurantEarning;
  final double platformEarning;
  final CourierOrderStatus status;
  final String customerAddress;
  final double? customerLat;
  final double? customerLng;
  final String? restaurantName;
  final String? restaurantAddress;
  final double? restaurantLat;
  final double? restaurantLng;
  final String? customerName;
  final String? customerPhone;
  /// Siparişi veren müşteri kullanıcı kimliği (gösterim yedekleri için).
  final String? customerUserId;
  /// Sunucudaki atanmış kurye (havuzda null).
  final String? assignedCourierUserId;

  /// Bu kurye bu siparişi reddetti (havuz veya görev); API `courierDeclined`.
  final bool courierDeclined;

  /// Red nedeni özeti; API `courierDeclineReason`.
  final String? courierDeclineReason;

  factory CourierOrderModel.fromJson(Map<String, dynamic> json) {
    return CourierOrderModel(
      id: json['id']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      createdAtUtc: _parseDateTime(
        json['createdAtUtc'] ?? json['createdAt'],
      ),
      imagePath: json['imagePath']?.toString() ?? '',
      preparationMinutes: _parseNullableInt(json['preparationMinutes']),
      items: json['items']?.toString() ?? '',
      total: _parseInt(json['total']),
      totalDiscount: _parseDouble(json['totalDiscount']) ?? 0,
      customerPaidAmount: _parseDouble(json['customerPaidAmount']),
      restaurantEarning: _parseDouble(json['restaurantEarning']) ?? 0,
      platformEarning: _parseDouble(json['platformEarning']) ?? 0,
      status: _parseStatus(json['status']),
      customerAddress: json['customerAddress']?.toString() ?? '',
      customerLat: _parseDouble(json['customerLat']),
      customerLng: _parseDouble(json['customerLng']),
      restaurantName: json['restaurantName']?.toString(),
      restaurantAddress: json['restaurantAddress']?.toString(),
      restaurantLat: _parseDouble(json['restaurantLat']),
      restaurantLng: _parseDouble(json['restaurantLng']),
      customerName: json['customerName']?.toString(),
      customerPhone: json['customerPhone']?.toString(),
      customerUserId: json['customerUserId']?.toString(),
      assignedCourierUserId: json['courierUserId']?.toString(),
      courierDeclined: json['courierDeclined'] == true,
      courierDeclineReason: json['courierDeclineReason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'time': time,
      'date': date,
      'createdAtUtc': createdAtUtc?.toUtc().toIso8601String(),
      'imagePath': imagePath,
      'preparationMinutes': preparationMinutes,
      'items': items,
      'total': total,
      'totalDiscount': totalDiscount,
      'customerPaidAmount': customerPaidAmount,
      'restaurantEarning': restaurantEarning,
      'platformEarning': platformEarning,
      'status': status.name,
      'customerAddress': customerAddress,
      'customerLat': customerLat,
      'customerLng': customerLng,
      'restaurantName': restaurantName,
      'restaurantAddress': restaurantAddress,
      'restaurantLat': restaurantLat,
      'restaurantLng': restaurantLng,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerUserId': customerUserId,
      'courierUserId': assignedCourierUserId,
      'courierDeclined': courierDeclined,
      'courierDeclineReason': courierDeclineReason,
    };
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static CourierOrderStatus _parseStatus(dynamic value) {
    final text = value?.toString().toLowerCase().trim();
    switch (text) {
      case 'picked_up':
      case 'pickedup':
        return CourierOrderStatus.pickedUp;
      case 'in_transit':
      case 'intransit':
        return CourierOrderStatus.inTransit;
      case 'delivered':
        return CourierOrderStatus.delivered;
      default:
        return CourierOrderStatus.assigned;
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text)?.toUtc();
  }

  CourierOrderModel copyWith({
    String? id,
    String? time,
    String? date,
    DateTime? createdAtUtc,
    String? imagePath,
    int? preparationMinutes,
    String? items,
    int? total,
    double? totalDiscount,
    double? customerPaidAmount,
    double? restaurantEarning,
    double? platformEarning,
    CourierOrderStatus? status,
    String? customerAddress,
    double? customerLat,
    double? customerLng,
    String? restaurantName,
    String? restaurantAddress,
    double? restaurantLat,
    double? restaurantLng,
    String? customerName,
    String? customerPhone,
    String? customerUserId,
    String? assignedCourierUserId,
    bool? courierDeclined,
    String? courierDeclineReason,
    bool resetCourierDecline = false,
  }) {
    final nextDeclined =
        resetCourierDecline ? false : (courierDeclined ?? this.courierDeclined);
    final nextDeclineReason = resetCourierDecline
        ? null
        : (courierDeclineReason ?? this.courierDeclineReason);
    return CourierOrderModel(
      id: id ?? this.id,
      time: time ?? this.time,
      date: date ?? this.date,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      imagePath: imagePath ?? this.imagePath,
      preparationMinutes: preparationMinutes ?? this.preparationMinutes,
      items: items ?? this.items,
      total: total ?? this.total,
      totalDiscount: totalDiscount ?? this.totalDiscount,
      customerPaidAmount: customerPaidAmount ?? this.customerPaidAmount,
      restaurantEarning: restaurantEarning ?? this.restaurantEarning,
      platformEarning: platformEarning ?? this.platformEarning,
      status: status ?? this.status,
      customerAddress: customerAddress ?? this.customerAddress,
      customerLat: customerLat ?? this.customerLat,
      customerLng: customerLng ?? this.customerLng,
      restaurantName: restaurantName ?? this.restaurantName,
      restaurantAddress: restaurantAddress ?? this.restaurantAddress,
      restaurantLat: restaurantLat ?? this.restaurantLat,
      restaurantLng: restaurantLng ?? this.restaurantLng,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerUserId: customerUserId ?? this.customerUserId,
      assignedCourierUserId:
          assignedCourierUserId ?? this.assignedCourierUserId,
      courierDeclined: nextDeclined,
      courierDeclineReason: nextDeclineReason,
    );
  }
}
