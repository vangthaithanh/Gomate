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
    String? originPlaceId,
    double? originLatitude,
    double? originLongitude,
    required String destinationPlaceId,
  });

  Future<GoMateMapRoute> loadTripRoute(String tripId);
  Future<List<GoMateMapMember>> loadTripMembers(String tripId);
}
