import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../models/map_member.dart';
import '../models/map_place.dart';
import '../models/map_route.dart';
import '../services/map_gateway.dart';
import '../services/spring_route_service.dart';
import 'demo_place_data_source.dart';
import 'demo_places.dart';

class DemoGoMateMapGateway implements GoMateMapGateway {
  final DemoPlaceDataSource _places;
  final SpringRouteService _routes;

  DemoGoMateMapGateway({
    DemoPlaceDataSource? places,
    SpringRouteService? routes,
  })  : _places = places ?? DemoPlaceDataSource(),
        _routes = routes ?? const SpringRouteService();

  @override
  Future<List<GoMateMapPlace>> loadPlaces({
    String? query,
    GoMatePlaceCategory? category,
  }) {
    return _places.getPlaces(query: query, category: category);
  }

  @override
  Future<GoMateMapPlace> loadPlaceDetail(String placeId) {
    return _places.getPlaceById(placeId);
  }

  @override
  Future<GoMateMapRoute> loadDirections({
    required Position origin,
    required String destinationPlaceId,
  }) {
    return _routes.calculateDirections(
      origin: origin,
      destinationPlaceId: destinationPlaceId,
    );
  }

  @override
  Future<GoMateMapRoute> loadTripRoute(String tripId) async {
    try {
      return await _routes.calculate(
        placeIds: demoTripStopIds,
      );
    } catch (e) {
      final stops = <GoMateMapPlace>[];
      for (final id in demoTripStopIds) {
        stops.add(await _places.getPlaceById(id));
      }

      return GoMateMapRoute(
        routeId: 'route-fallback-demo',
        geometry: stops.map((e) => e.position).toList(),
        distanceKm: 0,
        durationMinutes: 0,
        orderedPlaceIds: demoTripStopIds,
        isFallback: true,
        warning: 'Route backend chưa sẵn sàng: $e',
      );
    }
  }

  @override
  Future<List<GoMateMapMember>> loadTripMembers(String tripId) async {
    return [];
  }
}
