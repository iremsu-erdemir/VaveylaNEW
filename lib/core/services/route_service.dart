import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// OSRM tabanli rota servisi - restoran -> musteri arasi mesafe, sure ve polyline.
class RouteService {
  static const String _osrmBase =
      'https://router.project-osrm.org/route/v1/driving';

  /// Iki nokta arasi rota bilgisi alir.
  /// [from] baslangic, [to] varis.
  /// Kurye konumu varsa [courierPosition] ile kurye->musteri mesafesi hesaplanir.
  Future<RouteResult?> getRoute({
    required LatLng from,
    required LatLng to,
    LatLng? courierPosition,
  }) async {
    try {
      // OSRM: lng,lat formatinda
      final coords =
          '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
      final uri = Uri.parse(
        '$_osrmBase/$coords?overview=full&geometries=polyline',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;
      final routes = data['routes'];
      if (routes is! List || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final distanceMeters = (route['distance'] as num?)?.toDouble();
      final durationSeconds = (route['duration'] as num?)?.toDouble();
      final geometry = route['geometry'] as String?;
      if (geometry == null || geometry.isEmpty) return null;

      final points = _decodePolyline(geometry);
      if (points.isEmpty) return null;

      double? remainingDistanceKm;
      int? remainingMinutes;

      if (courierPosition != null &&
          distanceMeters != null &&
          durationSeconds != null) {
        // Kurye konumundan musteriye kalan mesafe (Haversine yaklasimi)
        final totalKm = distanceMeters / 1000;
        final totalMinutes = durationSeconds / 60;
        final courierToDestKm = haversineKm(
          courierPosition.latitude,
          courierPosition.longitude,
          to.latitude,
          to.longitude,
        );
        remainingDistanceKm = courierToDestKm;
        // Ortalama hiz: totalKm / totalMinutes km/dk
        final avgSpeedKmPerMin = totalKm > 0 ? totalKm / totalMinutes : 0.3;
        remainingMinutes = (courierToDestKm / avgSpeedKmPerMin).round();
      } else if (distanceMeters != null && durationSeconds != null) {
        remainingDistanceKm = distanceMeters / 1000;
        remainingMinutes = (durationSeconds / 60).round();
      }

      return RouteResult(
        polylinePoints: points,
        totalDistanceKm: distanceMeters != null ? distanceMeters / 1000 : null,
        totalDurationMinutes:
            durationSeconds != null ? (durationSeconds / 60).round() : null,
        remainingDistanceKm: remainingDistanceKm,
        remainingMinutes: remainingMinutes,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RouteService getRoute error: $e');
      }
      return null;
    }
  }

  /// Kurye konumundan musteriye kalan mesafe (km) - Haversine.
  static double haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRad(double deg) => deg * math.pi / 180;

  /// Tek OSRM bacagi: iki nokta arasi yol mesafesi ve sure (polyline yok).
  /// Canli kurye -> musteri kalan rota gibi durumlarda kullanilir.
  Future<({double km, int minutes})?> getDrivingLeg(
    LatLng from,
    LatLng to,
  ) async {
    try {
      final coords =
          '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
      final uri = Uri.parse('$_osrmBase/$coords?overview=false');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;
      final routes = data['routes'];
      if (routes is! List || routes.isEmpty) return null;
      final route = routes.first as Map<String, dynamic>;
      final distanceMeters = (route['distance'] as num?)?.toDouble();
      final durationSeconds = (route['duration'] as num?)?.toDouble();
      if (distanceMeters == null || durationSeconds == null) return null;
      return (
        km: distanceMeters / 1000,
        minutes: (durationSeconds / 60).round().clamp(1, 9999),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RouteService getDrivingLeg error: $e');
      }
      return null;
    }
  }

  /// Google/OSRM polyline decode (precision 5)
  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}

class RouteResult {
  const RouteResult({
    required this.polylinePoints,
    this.totalDistanceKm,
    this.totalDurationMinutes,
    this.remainingDistanceKm,
    this.remainingMinutes,
  });

  final List<LatLng> polylinePoints;
  final double? totalDistanceKm;
  final int? totalDurationMinutes;
  final double? remainingDistanceKm;
  final int? remainingMinutes;

  /// Kurye konumundan varisa kalan mesafe ve sureyi hesaplar (OSRM cagrisi yapmadan).
  static (double km, int minutes) computeRemaining({
    required double courierLat,
    required double courierLng,
    required double destLat,
    required double destLng,
    double? avgSpeedKmPerMin,
  }) {
    final km = RouteService.haversineKm(
      courierLat,
      courierLng,
      destLat,
      destLng,
    );
    final speed = avgSpeedKmPerMin ?? 0.5; // varsayilan ~30 km/h
    final minutes = (km / speed).round().clamp(1, 999);
    return (km, minutes);
  }
}
