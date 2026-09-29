import '../models/place_models.dart';
import 'place_api.dart';

class PlaceRepository {
  final PlaceApi _api;

  const PlaceRepository(this._api);

  factory PlaceRepository.production() => PlaceRepository(PlaceApi());

  Future<List<PlaceSummary>> listPlaces() => _api.listPlaces();

  Future<List<PlaceSummary>> searchPlaces(String query) =>
      _api.searchPlaces(query);

  Future<PlaceDetail> getPlace(int id) => _api.getPlace(id);
}
