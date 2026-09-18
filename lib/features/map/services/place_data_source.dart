import '../models/map_place.dart';

abstract class PlaceDataSource {
  Future<List<GoMateMapPlace>> getPlaces({
    String? query,
    GoMatePlaceCategory? category,
  });

  Future<GoMateMapPlace> getPlaceById(String placeId);
}
