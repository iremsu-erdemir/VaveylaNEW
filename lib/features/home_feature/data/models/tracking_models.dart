class CourierDetailsModel {
  const CourierDetailsModel({
    required this.courierUserId,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    this.phone,
    this.photoUrl,
  });

  final String courierUserId;
  final String firstName;
  final String lastName;
  final String fullName;
  final String? phone;
  final String? photoUrl;

  factory CourierDetailsModel.fromJson(Map<dynamic, dynamic> json) {
    return CourierDetailsModel(
      courierUserId: json['courierUserId']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      phone: json['phone']?.toString(),
      photoUrl: json['photoUrl']?.toString(),
    );
  }
}

class LocationUpdateModel {
  const LocationUpdateModel({
    required this.orderId,
    required this.lat,
    required this.lng,
    this.bearing,
    this.timestampUtc,
    this.courier,
  });

  final String orderId;
  final double lat;
  final double lng;
  final double? bearing;
  final DateTime? timestampUtc;
  final CourierDetailsModel? courier;

  /// SignalR / .NET bazen PascalCase anahtar gönderir; eksik koordinatta [null] dönün (0,0 kurye değildir).
  static LocationUpdateModel? tryFromJson(Map<dynamic, dynamic> json) {
    dynamic g(String camel, String pascal) {
      if (json.containsKey(camel)) return json[camel];
      return json[pascal];
    }

    final orderId = g('orderId', 'OrderId')?.toString() ?? '';
    if (orderId.isEmpty) return null;

    final lat = _parseDouble(g('lat', 'Lat'));
    final lng = _parseDouble(g('lng', 'Lng'));
    if (lat == null || lng == null) return null;
    if (!lat.isFinite || !lng.isFinite) return null;
    if (lat.abs() < 1e-6 && lng.abs() < 1e-6) return null;

    final courierRaw = g('courier', 'Courier');
    return LocationUpdateModel(
      orderId: orderId,
      lat: lat,
      lng: lng,
      bearing: _parseDouble(g('bearing', 'Bearing')),
      timestampUtc: DateTime.tryParse(
        g('timestampUtc', 'TimestampUtc')?.toString() ?? '',
      )?.toLocal(),
      courier:
          courierRaw is Map
              ? CourierDetailsModel.fromJson(courierRaw)
              : null,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class TrackingSnapshotModel {
  const TrackingSnapshotModel({
    required this.orderId,
    required this.items,
    required this.deliveryAddress,
    this.customerLat,
    this.customerLng,
    this.courierLat,
    this.courierLng,
    this.bearing,
    this.courierLocationUpdatedAtUtc,
    required this.isTrackingActive,
    this.courier,
    this.restaurantLat,
    this.restaurantLng,
    this.restaurantAddress,
    this.restaurantName,
    this.customerName,
    this.customerPhone,
  });

  final String orderId;
  final String items;
  final String deliveryAddress;
  final double? customerLat;
  final double? customerLng;
  final double? courierLat;
  final double? courierLng;
  final double? bearing;
  final DateTime? courierLocationUpdatedAtUtc;
  final bool isTrackingActive;
  final CourierDetailsModel? courier;
  final double? restaurantLat;
  final double? restaurantLng;
  final String? restaurantAddress;
  final String? restaurantName;
  final String? customerName;
  final String? customerPhone;

  factory TrackingSnapshotModel.fromJson(Map<String, dynamic> json) {
    dynamic j(String camel, String pascal) {
      if (json.containsKey(camel)) return json[camel];
      return json[pascal];
    }

    final courierRaw = j('courier', 'Courier');
    return TrackingSnapshotModel(
      orderId: j('orderId', 'OrderId')?.toString() ?? '',
      items: j('items', 'Items')?.toString() ?? '',
      deliveryAddress: j('deliveryAddress', 'DeliveryAddress')?.toString() ?? '',
      customerLat: _parseDouble(j('customerLat', 'CustomerLat')),
      customerLng: _parseDouble(j('customerLng', 'CustomerLng')),
      courierLat: _parseDouble(j('courierLat', 'CourierLat')),
      courierLng: _parseDouble(j('courierLng', 'CourierLng')),
      bearing: _parseDouble(j('bearing', 'Bearing')),
      courierLocationUpdatedAtUtc: DateTime.tryParse(
        j('courierLocationUpdatedAtUtc', 'CourierLocationUpdatedAtUtc')
                ?.toString() ??
            '',
      )?.toLocal(),
      isTrackingActive: j('isTrackingActive', 'IsTrackingActive') == true,
      courier:
          courierRaw is Map
              ? CourierDetailsModel.fromJson(courierRaw)
              : null,
      restaurantLat: _parseDouble(j('restaurantLat', 'RestaurantLat')),
      restaurantLng: _parseDouble(j('restaurantLng', 'RestaurantLng')),
      restaurantAddress: () {
        final raw = j('restaurantAddress', 'RestaurantAddress')?.toString();
        final s = raw?.trim();
        if (s == null || s.isEmpty) return null;
        return s;
      }(),
      restaurantName: () {
        final raw = j('restaurantName', 'RestaurantName')?.toString();
        final s = raw?.trim();
        if (s == null || s.isEmpty) return null;
        return s;
      }(),
      customerName: () {
        final raw = j('customerName', 'CustomerName')?.toString();
        final s = raw?.trim();
        if (s == null || s.isEmpty) return null;
        return s;
      }(),
      customerPhone: () {
        final raw = j('customerPhone', 'CustomerPhone')?.toString();
        final s = raw?.trim();
        if (s == null || s.isEmpty) return null;
        return s;
      }(),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
