enum CustomerOrderStatus {
  pending,
  preparing,
  /// Sunucu: kurye görevi bıraktı / havuz; gerçek atama yok (`awaitingCourier`).
  awaitingCourier,
  assigned,
  inTransit,
  completed,
  canceled,
}

class CustomerOrderModel {
  CustomerOrderModel({
    required this.id,
    required this.items,
    required this.total,
    required this.status,
    required this.time,
    required this.date,
    this.restaurantId = '',
    this.imagePath = '',
    this.preparationMinutes,
    this.customerLat,
    this.customerLng,
    this.courierLat,
    this.courierLng,
    this.courierLocationUpdatedAtUtc,
    this.courierName,
    this.restaurantLat,
    this.restaurantLng,
    this.restaurantAddress,
    this.restaurantName,
    this.deliveryAddress,
    this.deliveryAddressDetail,
    this.customerName,
    this.customerPhone,
    this.assignedCourierUserId,
  });

  final String id;
  final String items;
  final int total;
  final CustomerOrderStatus status;
  final String time;
  final String date;
  final String restaurantId;
  final String imagePath;
  final int? preparationMinutes;
  final double? customerLat;
  final double? customerLng;
  final double? courierLat;
  final double? courierLng;
  final DateTime? courierLocationUpdatedAtUtc;
  final String? courierName;
  final double? restaurantLat;
  final double? restaurantLng;
  final String? restaurantAddress;
  final String? restaurantName;
  final String? deliveryAddress;
  final String? deliveryAddressDetail;
  final String? customerName;
  final String? customerPhone;

  /// Sunucudaki gerçek atama; boşsa müşteri için "kurye ataması bekleniyor" (assigned havuz).
  final String? assignedCourierUserId;

  factory CustomerOrderModel.fromJson(Map<String, dynamic> json) {
    return CustomerOrderModel(
      id: json['id']?.toString() ?? '',
      items: json['items']?.toString() ?? '',
      total: _parseInt(json['total']),
      status: _resolveDisplayStatus(json),
      time: json['time']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      restaurantId: json['restaurantId']?.toString() ?? '',
      imagePath: json['imagePath']?.toString() ?? '',
      preparationMinutes: _parseNullableInt(json['preparationMinutes']),
      customerLat: _parseNullableDouble(json['customerLat']),
      customerLng: _parseNullableDouble(json['customerLng']),
      courierLat: _parseNullableDouble(json['courierLat']),
      courierLng: _parseNullableDouble(json['courierLng']),
      courierLocationUpdatedAtUtc: _parseNullableDateTime(
        json['courierLocationUpdatedAtUtc'],
      ),
      courierName: () {
        final raw =
            json['courierName']?.toString() ?? json['CourierName']?.toString();
        final s = raw?.trim();
        if (s == null || s.isEmpty) return null;
        return s;
      }(),
      restaurantLat: _parseNullableDouble(json['restaurantLat']),
      restaurantLng: _parseNullableDouble(json['restaurantLng']),
      restaurantAddress: () {
        final raw = json['restaurantAddress']?.toString();
        final s = raw?.trim();
        if (s == null || s.isEmpty) return null;
        return s;
      }(),
      restaurantName: () {
        final raw =
            json['restaurantName']?.toString() ??
            json['RestaurantName']?.toString();
        final s = raw?.trim();
        if (s == null || s.isEmpty) return null;
        return s;
      }(),
      deliveryAddress: () {
        final raw =
            json['deliveryAddress']?.toString() ??
            json['DeliveryAddress']?.toString();
        final s = raw?.trim();
        if (s == null || s.isEmpty) return null;
        return s;
      }(),
      deliveryAddressDetail: () {
        final raw =
            json['deliveryAddressDetail']?.toString() ??
            json['DeliveryAddressDetail']?.toString();
        final s = raw?.trim();
        if (s == null || s.isEmpty) return null;
        return s;
      }(),
      customerName: () {
        final raw =
            json['customerName']?.toString() ??
            json['CustomerName']?.toString();
        final s = raw?.trim();
        if (s == null || s.isEmpty) return null;
        return s;
      }(),
      customerPhone: () {
        final raw =
            json['customerPhone']?.toString() ??
            json['CustomerPhone']?.toString();
        final s = raw?.trim();
        if (s == null || s.isEmpty) return null;
        return s;
      }(),
      assignedCourierUserId: () {
        final v = json['assignedCourierUserId'];
        final raw = v?.toString().trim() ?? '';
        if (raw.isEmpty) return null;
        if (raw == '00000000-0000-0000-0000-000000000000') return null;
        return raw;
      }(),
    );
  }

  /// API `assigned` döndürse bile gerçek kurye yoksa havuz olarak göster (senkron rozet).
  static CustomerOrderStatus _resolveDisplayStatus(Map<String, dynamic> json) {
    final parsed = _parseStatus(json['status']?.toString());
    if (parsed != CustomerOrderStatus.assigned) {
      return parsed;
    }
    final v = json['assignedCourierUserId'];
    final raw = v?.toString().trim() ?? '';
    final hasCourier =
        raw.isNotEmpty && raw != '00000000-0000-0000-0000-000000000000';
    if (!hasCourier) {
      return CustomerOrderStatus.awaitingCourier;
    }
    return CustomerOrderStatus.assigned;
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

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static CustomerOrderStatus _parseStatus(dynamic value) {
    if (value is int) {
      switch (value) {
        case 2:
          return CustomerOrderStatus.preparing;
        case 3:
          return CustomerOrderStatus.assigned;
        case 4:
          return CustomerOrderStatus.inTransit;
        case 5:
          return CustomerOrderStatus.completed;
        case 6:
          return CustomerOrderStatus.canceled;
        case 7:
          return CustomerOrderStatus.awaitingCourier;
        default:
          return CustomerOrderStatus.pending;
      }
    }

    final normalized = value?.toString().trim().toLowerCase() ?? '';
    switch (normalized) {
      case 'preparing':
      case 'accepted':
        return CustomerOrderStatus.preparing;
      case 'ready':
      case 'awaitingcourier':
      case 'awaiting_courier':
        return CustomerOrderStatus.awaitingCourier;
      case 'assigned':
        return CustomerOrderStatus.assigned;
      case 'intransit':
      case 'in_transit':
      case 'ontheway':
      case 'on_the_way':
        return CustomerOrderStatus.inTransit;
      case 'completed':
      case 'delivered':
        return CustomerOrderStatus.completed;
      case 'canceled':
      case 'cancelled':
      case 'rejected':
        return CustomerOrderStatus.canceled;
      case 'pending':
        return CustomerOrderStatus.pending;
      default:
        return CustomerOrderStatus.pending;
    }
  }
}
