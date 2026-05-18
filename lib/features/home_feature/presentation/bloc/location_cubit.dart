import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_sweet_shop_app_ui/core/services/google_geocoding_service.dart';

part 'location_state.dart';

class LocationCubit extends Cubit<LocationState> {
  LocationCubit() : super(const LocationState());

  final GoogleGeocodingService _googleGeocodingService =
      GoogleGeocodingService();

  Future<void> requestLocation() async {
    emit(state.copyWith(status: LocationStatus.loading, message: null));

    final positionResult = await _tryGetCurrentPosition();
    if (positionResult != null) {
      final precisePlace = await _tryReverseGeocode(
        latitude: positionResult.position.latitude,
        longitude: positionResult.position.longitude,
      );
      emit(
        state.copyWith(
          status: LocationStatus.success,
          latitude: positionResult.position.latitude,
          longitude: positionResult.position.longitude,
          city: precisePlace?.city,
          country: precisePlace?.country,
          message:
              positionResult.isFromLastKnown
                  ? 'Son bilinen konum gösteriliyor.'
                  : null,
        ),
      );
      return;
    }

    final ipLocation = await _tryGetLocationFromIp();
    if (ipLocation != null) {
      emit(
        state.copyWith(
          status: LocationStatus.success,
          latitude: ipLocation.latitude,
          longitude: ipLocation.longitude,
          city: ipLocation.city,
          country: ipLocation.country,
          message: 'Kesin konum alınamadı, yaklaşık konum gösteriliyor.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: LocationStatus.error,
        message: 'Konum alınamadı. Lütfen tekrar deneyin.',
      ),
    );
  }

  Future<_PositionResult?> _tryGetCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return _PositionResult(position: position, isFromLastKnown: false);
    } catch (_) {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown == null || !_isRecentEnough(lastKnown)) {
        return null;
      }
      return _PositionResult(position: lastKnown, isFromLastKnown: true);
    }
  }

  bool _isRecentEnough(Position position) {
    final ageMinutes = DateTime.now().difference(position.timestamp).inMinutes;
    return ageMinutes <= 15;
  }

  Future<_PlaceName?> _tryReverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    _PlaceName? nativePlace;
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      final place = placemarks.isNotEmpty ? placemarks.first : null;
      final city = place?.locality ?? place?.administrativeArea;
      final country = place?.country;
      nativePlace = _PlaceName(city: city, country: country);
      if (_hasPlaceText(nativePlace)) {
        return nativePlace;
      }
    } catch (_) {
      nativePlace = null;
    }

    final googlePlace = await _tryReverseGeocodeWithGoogle(
      latitude: latitude,
      longitude: longitude,
    );
    if (_hasPlaceText(googlePlace)) {
      return googlePlace;
    }

    final osmPlace = await _tryReverseGeocodeWithOsm(
      latitude: latitude,
      longitude: longitude,
    );
    if (_hasPlaceText(osmPlace)) {
      return osmPlace;
    }

    return nativePlace;
  }

  Future<_PlaceName?> _tryReverseGeocodeWithGoogle({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final place = await _googleGeocodingService.reverseGeocodePlace(
        latitude: latitude,
        longitude: longitude,
      );
      if (place == null) {
        return null;
      }
      return _PlaceName(city: place.city, country: place.country);
    } catch (_) {
      return null;
    }
  }

  Future<_PlaceName?> _tryReverseGeocodeWithOsm({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse')
          .replace(
            queryParameters: <String, String>{
              'format': 'jsonv2',
              'lat': latitude.toString(),
              'lon': longitude.toString(),
              'accept-language': 'tr,en',
              'zoom': '10',
            },
          );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        return null;
      }
      final address = data['address'];
      if (address is! Map<String, dynamic>) {
        return null;
      }
      final city = _pickBestText(
        address['city'],
        address['town'] ??
            address['village'] ??
            address['municipality'] ??
            address['county'] ??
            address['state'],
      );
      final country = _asString(address['country']);
      return _PlaceName(city: city, country: country);
    } catch (_) {
      return null;
    }
  }

  Future<_IpLocation?> _tryGetLocationFromIp() async {
    final providers = <Uri>[
      Uri.parse('https://ipapi.co/json/'),
      Uri.parse('https://ipwho.is/'),
    ];

    for (final url in providers) {
      final result = await _tryGetLocationFromSingleProvider(url);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  Future<_IpLocation?> _tryGetLocationFromSingleProvider(Uri url) async {
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final city = _pickBestText(data['city'], data['region']);
      final country = _pickBestText(data['country_name'], data['country']);
      final latitude = _asDouble(data['latitude'] ?? data['lat']);
      final longitude = _asDouble(data['longitude'] ?? data['lon']);

      if ((city == null || city.isEmpty) && (country == null || country.isEmpty)) {
        return null;
      }

      return _IpLocation(
        city: city,
        country: country,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (_) {
      return null;
    }
  }

  String? _pickBestText(dynamic first, dynamic second) {
    final firstValue = _asString(first);
    if (firstValue != null && firstValue.isNotEmpty) {
      return firstValue;
    }
    final secondValue = _asString(second);
    if (secondValue != null && secondValue.isNotEmpty) {
      return secondValue;
    }
    return null;
  }

  String? _asString(dynamic value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  bool _hasPlaceText(_PlaceName? place) {
    if (place == null) {
      return false;
    }
    final city = place.city?.trim() ?? '';
    final country = place.country?.trim() ?? '';
    return city.isNotEmpty || country.isNotEmpty;
  }
}

class _PlaceName {
  const _PlaceName({this.city, this.country});

  final String? city;
  final String? country;
}

class _IpLocation {
  const _IpLocation({
    required this.city,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  final String? city;
  final String? country;
  final double? latitude;
  final double? longitude;
}

class _PositionResult {
  const _PositionResult({
    required this.position,
    required this.isFromLastKnown,
  });

  final Position position;
  final bool isFromLastKnown;
}
