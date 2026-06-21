import 'dart:convert';

import 'package:http/http.dart' as http;

class GeocodingResult {
  const GeocodingResult({
    required this.latitude,
    required this.longitude,
    this.formattedAddress,
  });

  final double latitude;
  final double longitude;
  final String? formattedAddress;
}

class GoogleGeocodingService {
  static const String _apiKey = 'AIzaSyBTTh8R-M9dD4cxgQYnUhGBqebLKiv0Qbs';

  /// Adres metninden koordinat (lat, lng) döner. Harita üzerinde göstermek için kullanılır.
  Future<GeocodingResult?> geocodeAddress(String address) async {
    if (_apiKey.trim().isEmpty || address.trim().isEmpty) {
      return null;
    }
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'address': address.trim(),
        'key': _apiKey,
        'language': 'tr',
        'region': 'tr',
      },
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;
      final status = data['status']?.toString() ?? '';
      if (status != 'OK' && status != 'ZERO_RESULTS') return null;
      final results = data['results'];
      if (results is! List || results.isEmpty) return null;
      final first = results.first as Map<String, dynamic>;
      final geometry = first['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;
      final lat = _parseDouble(location?['lat']);
      final lng = _parseDouble(location?['lng']);
      if (lat == null || lng == null) return null;
      return GeocodingResult(
        latitude: lat,
        longitude: lng,
        formattedAddress: first['formatted_address']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final data = await _getGeocodeResponse(
      latitude: latitude,
      longitude: longitude,
    );

    final results = data['results'];
    if (results is List && results.isNotEmpty) {
      final first = results.first;
      if (first is Map<String, dynamic>) {
        return first['formatted_address']?.toString();
      }
    }

    return null;
  }

  Future<GoogleReversePlace?> reverseGeocodePlace({
    required double latitude,
    required double longitude,
  }) async {
    final data = await _getGeocodeResponse(
      latitude: latitude,
      longitude: longitude,
    );

    final results = data['results'];
    if (results is! List || results.isEmpty) {
      return null;
    }

    final first = results.first;
    if (first is! Map<String, dynamic>) {
      return null;
    }

    String? city;
    String? country;
    final components = first['address_components'];
    if (components is List) {
      for (final component in components) {
        if (component is! Map<String, dynamic>) {
          continue;
        }
        final types = component['types'];
        if (types is! List) {
          continue;
        }
        final longName = component['long_name']?.toString();
        if (longName == null || longName.trim().isEmpty) {
          continue;
        }

        if (country == null && types.contains('country')) {
          country = longName;
        }

        if (city == null &&
            (types.contains('locality') ||
                types.contains('administrative_area_level_2') ||
                types.contains('administrative_area_level_1'))) {
          city = longName;
        }
      }
    }

    if ((city == null || city.trim().isEmpty) &&
        (country == null || country.trim().isEmpty)) {
      return null;
    }

    return GoogleReversePlace(
      city: city?.trim(),
      country: country?.trim(),
    );
  }

  Future<Map<String, dynamic>> _getGeocodeResponse({
    required double latitude,
    required double longitude,
  }) async {
    if (_apiKey.trim().isEmpty) {
      throw GoogleGeocodingException(
        'GOOGLE_MAPS_API_KEY tanimli degil.',
      );
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'latlng': '$latitude,$longitude',
        'key': _apiKey,
        'language': 'tr',
      },
    );

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GoogleGeocodingException(
        'Google Geocoding istegi basarisiz oldu.',
      );
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw GoogleGeocodingException('Gecersiz cevap formati.');
    }

    final status = data['status']?.toString() ?? 'UNKNOWN';
    if (status != 'OK') {
      final error = data['error_message']?.toString();
      throw GoogleGeocodingException(
        error ?? 'Google Geocoding hatasi: $status',
      );
    }
    return data;
  }
}

class GoogleReversePlace {
  const GoogleReversePlace({
    required this.city,
    required this.country,
  });

  final String? city;
  final String? country;
}

class GoogleGeocodingException implements Exception {
  GoogleGeocodingException(this.message);

  final String message;

  @override
  String toString() => message;
}
