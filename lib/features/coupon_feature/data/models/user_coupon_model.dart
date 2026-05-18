class UserCouponModel {
  final String userCouponId;
  final String couponId;
  final String code;
  final String? description;
  final int discountType;
  final double discountValue;
  final double? minCartAmount;
  final double? maxDiscountAmount;
  final DateTime expiresAtUtc;
  final String? restaurantId;
  final String status;
  final DateTime? usedAtUtc;

  UserCouponModel({
    required this.userCouponId,
    required this.couponId,
    required this.code,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.minCartAmount,
    this.maxDiscountAmount,
    required this.expiresAtUtc,
    this.restaurantId,
    required this.status,
    this.usedAtUtc,
  });

  bool get isUsable => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isUsed => status == 'used';
  bool get isExpired => status == 'expired';

  String get discountText {
    if (discountType == 1) {
      return '%${discountValue.toInt()} indirim';
    }
    return '${discountValue.toInt()} TL indirim';
  }

  String get conditionsText {
    final parts = <String>[];
    if (minCartAmount != null && minCartAmount! > 0) {
      parts.add('Min. sepet: ${minCartAmount!.toInt()} TL');
    }
    if (maxDiscountAmount != null && maxDiscountAmount! > 0 && discountType == 1) {
      parts.add('Max indirim: ${maxDiscountAmount!.toInt()} TL');
    }
    if (parts.isEmpty) return 'Şartsız';
    return parts.join(', ');
  }

  factory UserCouponModel.fromJson(Map<String, dynamic> json) {
    return UserCouponModel(
      userCouponId: json['userCouponId']?.toString() ?? '',
      couponId: json['couponId']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString(),
      discountType: _parseInt(json['discountType']) ?? 1,
      discountValue: _parseDouble(json['discountValue']) ?? 0,
      minCartAmount: _parseDouble(json['minCartAmount']),
      maxDiscountAmount: _parseDouble(json['maxDiscountAmount']),
      expiresAtUtc: DateTime.tryParse(json['expiresAtUtc']?.toString() ?? '') ?? DateTime.now(),
      restaurantId: json['restaurantId']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      usedAtUtc: json['usedAtUtc'] != null ? DateTime.tryParse(json['usedAtUtc'].toString()) : null,
    );
  }

  static int? _parseInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '');
  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
