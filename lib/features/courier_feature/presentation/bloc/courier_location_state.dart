part of 'courier_location_cubit.dart';

enum CourierLocationStatus {
  idle,
  loading,
  success,
  tracking,
  denied,
  error,
}

class CourierLocationState {
  const CourierLocationState({
    this.status = CourierLocationStatus.idle,
    this.latitude,
    this.longitude,
    this.heading,
    this.message,
  });

  final CourierLocationStatus status;
  final double? latitude;
  final double? longitude;

  /// Cihaz pusulası / hareket yönü (°), harita sürüş modunda döndürme için.
  final double? heading;
  final String? message;

  CourierLocationState copyWith({
    CourierLocationStatus? status,
    double? latitude,
    double? longitude,
    double? heading,
    String? message,
    bool clearHeading = false,
  }) {
    return CourierLocationState(
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      heading: clearHeading ? null : (heading ?? this.heading),
      message: message ?? this.message,
    );
  }
}
