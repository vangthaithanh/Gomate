import '../models/map_member.dart';
import '../models/map_place.dart';
import '../models/map_route.dart';
import '../services/map_gateway.dart';
import '../services/spring_postgres_place_data_source.dart';
import '../services/spring_route_service.dart';

class SpringGoMateMapGateway implements GoMateMapGateway {
  final SpringPostgresPlaceDataSource _places;
  final SpringRouteService _routes;

  SpringGoMateMapGateway({
    SpringPostgresPlaceDataSource? places,
    SpringRouteService? routes,
  }) : _places = places ?? SpringPostgresPlaceDataSource(),
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
    String? originPlaceId,
    double? originLatitude,
    double? originLongitude,
    required String destinationPlaceId,
  }) {
    return _routes.calculateDirections(
      originPlaceId: originPlaceId,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      destinationPlaceId: destinationPlaceId,
    );
  }

  @override
  Future<GoMateMapRoute> loadTripRoute(String tripId) {
    throw UnsupportedError(
      'Trip route chưa được nối với Place API thật trong task này.',
    );
  }

  @override
  Future<List<GoMateMapMember>> loadTripMembers(String tripId) async {
    return const <GoMateMapMember>[];
  }
}
