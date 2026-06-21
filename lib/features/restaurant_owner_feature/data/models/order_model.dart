enum RestaurantOrderStatus { pending, preparing, completed, rejected }

class RestaurantOrderModel {
  RestaurantOrderModel({
    required this.id,
    required this.time,
    required this.date,
    required this.imagePath,
    this.preparationMinutes,
    required this.items,
    required this.total,
    required this.status,
    this.rejectionReason,
    this.assignedCourierUserId,
    this.assignedCourierName,
    this.fulfillmentStatus,
    this.canAssignCourier = false,
    this.courierReassignmentRequired = false,
    this.courierReleaseReason,
  });

  final String id;
  final String time;
  final String date;
  final String imagePath;
  final int? preparationMinutes;
  final String items;
  final int total;
  final RestaurantOrderStatus status;
  final String? rejectionReason;
  final String? assignedCourierUserId;
  final String? assignedCourierName;
  /// API: pending, preparing, assigned, inTransit, delivered, cancelled
  final String? fulfillmentStatus;
  final bool canAssignCourier;
  final bool courierReassignmentRequired;
  final String? courierReleaseReason;

  factory RestaurantOrderModel.fromJson(Map<String, dynamic> json) {
    final status = _parseStatus(json['status']);
    final explicitCourier = json['canAssignCourier'];
    // Yalnızca API açıkça true derse (teslimata hazır / Assigned); aksi halde güvenli: false
    final resolvedCanAssign = explicitCourier == true;

    return RestaurantOrderModel(
      id: json['id']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      imagePath: json['imagePath']?.toString() ?? '',
      preparationMinutes: _parseNullableInt(json['preparationMinutes']),
      items: json['items']?.toString() ?? '',
      total: _parseInt(json['total']),
      status: status,
      rejectionReason: _parseOptionalTrimmed(json['rejectionReason']),
      assignedCourierUserId: _parseOptionalTrimmed(json['assignedCourierUserId']),
      assignedCourierName: _parseOptionalTrimmed(json['assignedCourierName']),
      fulfillmentStatus: _parseOptionalTrimmed(json['fulfillmentStatus']),
      canAssignCourier: resolvedCanAssign,
      courierReassignmentRequired: json['courierReassignmentRequired'] == true,
      courierReleaseReason: _parseOptionalTrimmed(json['courierReleaseReason']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'time': time,
      'date': date,
      'imagePath': imagePath,
      'preparationMinutes': preparationMinutes,
      'items': items,
      'total': total,
      'status': status.name,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (assignedCourierUserId != null)
        'assignedCourierUserId': assignedCourierUserId,
      if (assignedCourierName != null) 'assignedCourierName': assignedCourierName,
      if (fulfillmentStatus != null) 'fulfillmentStatus': fulfillmentStatus,
      'canAssignCourier': canAssignCourier,
      'courierReassignmentRequired': courierReassignmentRequired,
      if (courierReleaseReason != null)
        'courierReleaseReason': courierReleaseReason,
    };
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  static String? _parseOptionalTrimmed(dynamic value) {
    if (value == null) {
      return null;
    }
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static RestaurantOrderStatus _parseStatus(dynamic value) {
    final text = value?.toString().toLowerCase().trim();
    switch (text) {
      case 'preparing':
        return RestaurantOrderStatus.preparing;
      case 'completed':
        return RestaurantOrderStatus.completed;
      case 'rejected':
        return RestaurantOrderStatus.rejected;
      default:
        return RestaurantOrderStatus.pending;
    }
  }

  RestaurantOrderModel copyWith({
    String? id,
    String? time,
    String? date,
    String? imagePath,
    int? preparationMinutes,
    String? items,
    int? total,
    RestaurantOrderStatus? status,
    String? rejectionReason,
    String? assignedCourierUserId,
    String? assignedCourierName,
    String? fulfillmentStatus,
    bool? canAssignCourier,
    bool? courierReassignmentRequired,
    String? courierReleaseReason,
  }) {
    return RestaurantOrderModel(
      id: id ?? this.id,
      time: time ?? this.time,
      date: date ?? this.date,
      imagePath: imagePath ?? this.imagePath,
      preparationMinutes: preparationMinutes ?? this.preparationMinutes,
      items: items ?? this.items,
      total: total ?? this.total,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      assignedCourierUserId:
          assignedCourierUserId ?? this.assignedCourierUserId,
      assignedCourierName: assignedCourierName ?? this.assignedCourierName,
      fulfillmentStatus: fulfillmentStatus ?? this.fulfillmentStatus,
      canAssignCourier: canAssignCourier ?? this.canAssignCourier,
      courierReassignmentRequired:
          courierReassignmentRequired ?? this.courierReassignmentRequired,
      courierReleaseReason: courierReleaseReason ?? this.courierReleaseReason,
    );
  }
}
