import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class GoMateMapRoute {
  final String routeId;
  final List<Position> geometry;
  final double distanceKm;
  final int durationMinutes;
  final List<String> orderedPlaceIds;
  final bool isFallback;
  final String? warning;

  const GoMateMapRoute({
    required this.routeId,
    required this.geometry,
    required this.distanceKm,
    required this.durationMinutes,
    required this.orderedPlaceIds,
    this.isFallback = false,
    this.warning,
  });
}
