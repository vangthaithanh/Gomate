import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../models/map_member.dart';
import '../models/map_place.dart';
import '../models/map_route.dart';

abstract class GoMateMapGateway {
  Future<List<GoMateMapPlace>> loadPlaces({
    String? query,
    GoMatePlaceCategory? category,
  });

  Future<GoMateMapPlace> loadPlaceDetail(String placeId);

  Future<GoMateMapRoute> loadDirections({
    required Position origin,
    required String destinationPlaceId,
  });

  Future<GoMateMapRoute> loadTripRoute(String tripId);
  Future<List<GoMateMapMember>> loadTripMembers(String tripId);
}
