import 'package:latlong2/latlong.dart';

enum ShopLocationStatus { backendCoordinates, geocodedFromAddress, unavailable }

class SweetShop {
  const SweetShop({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.description,
    required this.deliveryInfo,
    required this.imageUrl,
    required this.estimatedDeliveryMinutes,
    required this.locationStatus,
  });

  final String id;
  final String name;
  final String address;
  final LatLng? location;
  final String description;
  final String deliveryInfo;
  final String imageUrl;
  final int estimatedDeliveryMinutes;
  final ShopLocationStatus locationStatus;
}
