import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:latlong2/latlong.dart';

class MapMarkerItem {
  const MapMarkerItem({
    required this.id,
    required this.point,
    this.isSelected = false,
  });

  final String id;
  final LatLng point;
  final bool isSelected;
}

class FlutterMapWidget extends StatelessWidget {
  const FlutterMapWidget({
    super.key,
    required this.latLng,
    this.mapController,
    this.userLatLng,
    this.markers = const [],
    this.markerItems = const [],
    this.onMarkerTap,
    this.initialZoom = 14.2,
  });

  final LatLng latLng;
  final MapController? mapController;
  final LatLng? userLatLng;
  final List<LatLng> markers;
  final List<MapMarkerItem> markerItems;
  final ValueChanged<String>? onMarkerTap;
  final double initialZoom;

  @override
  Widget build(BuildContext context) {
    final effectiveMarkers = markerItems.isNotEmpty
        ? markerItems
        : markers
              .asMap()
              .entries
              .map((entry) => MapMarkerItem(
                    id: 'marker-${entry.key}',
                    point: entry.value,
                  ))
              .toList();

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(initialCenter: latLng, initialZoom: initialZoom),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: ['a', 'b', 'c'],
          userAgentPackageName: 'com.sweet.shop.flutter_sweet_shop_app_ui',
        ),
        MarkerLayer(
          markers: [
            for (final marker in effectiveMarkers)
              Marker(
                point: marker.point,
                width: 36,
                height: 36,
                child: GestureDetector(
                  onTap: () => onMarkerTap?.call(marker.id),
                  child: Icon(
                    Icons.location_pin,
                    color: marker.isSelected
                        ? context.theme.appColors.secondary
                        : context.theme.appColors.primary,
                    size: marker.isSelected ? 42 : 36,
                  ),
                ),
              ),
            if (userLatLng != null)
              Marker(
                point: userLatLng!,
                width: 40,
                height: 40,
                child: Icon(
                  Icons.person_pin_circle,
                  color: context.theme.appColors.secondary,
                  size: 40,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
