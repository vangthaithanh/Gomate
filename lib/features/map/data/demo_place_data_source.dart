import '../models/map_place.dart';
import '../services/place_data_source.dart';
import 'demo_places.dart';

class DemoPlaceDataSource implements PlaceDataSource {
  @override
  Future<List<GoMateMapPlace>> getPlaces({
    String? query,
    GoMatePlaceCategory? category,
  }) async {
    final q = (query ?? '').trim().toLowerCase();

    return demoPlaces.where((p) {
      final categoryOk = category == null || p.category == category;
      final queryOk = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.address.toLowerCase().contains(q) ||
          p.categoryLabel.toLowerCase().contains(q);
      return categoryOk && queryOk;
    }).toList();
  }

  @override
  Future<GoMateMapPlace> getPlaceById(String placeId) async {
    return demoPlaces.firstWhere((p) => p.placeId == placeId);
  }
}
