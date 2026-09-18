import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../models/map_member.dart';
import '../models/map_place.dart';
import '../models/map_route.dart';
import '../services/map_gateway.dart';

enum GoMateMapMode { explore, directions, trip }

class GoMateMapState extends ChangeNotifier {
  final GoMateMapGateway gateway;
  GoMateMapState(this.gateway);

  bool loading = false;
  String? errorMessage;

  GoMateMapMode mode = GoMateMapMode.explore;
  GoMatePlaceCategory? category;
  String query = '';

  List<GoMateMapPlace> places = [];
  GoMateMapPlace? selectedPlace;

  GoMateMapRoute? route;

  Position? directionsOrigin;
  String directionsOriginLabel = 'Vị trí của tôi';
  bool directionsOriginIsCurrentLocation = true;
  bool choosingDirectionsOrigin = false;
  GoMateMapPlace? directionsDestination;

  List<GoMateMapPlace> tripStops = [];
  List<GoMateMapMember> members = [];

  Future<void> init() => refreshPlaces();

  Future<void> refreshPlaces() async {
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      places = await gateway.loadPlaces(
        query: query,
        category: category,
      );
    } catch (_) {
      errorMessage = 'Không tải được địa điểm.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setQuery(String value) async {
    query = value;
    await refreshPlaces();
  }

  Future<void> setCategory(GoMatePlaceCategory? value) async {
    category = value;
    await refreshPlaces();
  }

  Future<void> selectPlace(String placeId) async {
    selectedPlace = await gateway.loadPlaceDetail(placeId);
    notifyListeners();
  }

  void clearSelection() {
    selectedPlace = null;
    notifyListeners();
  }

  void toggleSavedSelected() {
    final current = selectedPlace;
    if (current == null) return;

    final changed = current.copyWith(isSaved: !current.isSaved);
    selectedPlace = changed;

    final i = places.indexWhere((e) => e.placeId == current.placeId);
    if (i >= 0) {
      places[i] = changed;
    }

    notifyListeners();
  }

  Future<bool> showDirections({
    required Position origin,
    required GoMateMapPlace destination,
    required bool originIsCurrentLocation,
    required String originLabel,
  }) async {
    loading = true;
    errorMessage = null;
    choosingDirectionsOrigin = false;
    notifyListeners();

    try {
      final calculated = await gateway.loadDirections(
        origin: origin,
        destinationPlaceId: destination.placeId,
      );

      route = calculated;
      directionsOrigin = origin;
      directionsOriginLabel = originLabel;
      directionsOriginIsCurrentLocation = originIsCurrentLocation;
      directionsDestination = destination;

      mode = GoMateMapMode.directions;
      selectedPlace = null;

      tripStops = [];
      members = [];

      return true;
    } catch (e) {
      errorMessage = 'Không tải được chỉ đường: $e';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void beginChooseDirectionsOrigin() {
    if (mode != GoMateMapMode.directions) return;
    choosingDirectionsOrigin = true;
    notifyListeners();
  }

  void cancelChooseDirectionsOrigin() {
    choosingDirectionsOrigin = false;
    notifyListeners();
  }

  Future<bool> changeDirectionsOrigin({
    required Position origin,
    required bool originIsCurrentLocation,
    required String originLabel,
  }) async {
    final destination = directionsDestination;
    if (destination == null) return false;

    return showDirections(
      origin: origin,
      destination: destination,
      originIsCurrentLocation: originIsCurrentLocation,
      originLabel: originLabel,
    );
  }

  Future<void> showTrip(String tripId) async {
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      route = await gateway.loadTripRoute(tripId);

      final all = await gateway.loadPlaces();
      tripStops = route!.orderedPlaceIds
          .map((id) => all.firstWhere((p) => p.placeId == id))
          .toList();

      members = await gateway.loadTripMembers(tripId);

      mode = GoMateMapMode.trip;
      selectedPlace = null;

      directionsOrigin = null;
      directionsDestination = null;
      choosingDirectionsOrigin = false;
    } catch (_) {
      errorMessage = 'Không tải được lộ trình.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> showExplore() async {
    mode = GoMateMapMode.explore;

    route = null;
    tripStops = [];
    members = [];

    directionsOrigin = null;
    directionsDestination = null;
    choosingDirectionsOrigin = false;
    directionsOriginLabel = 'Vị trí của tôi';
    directionsOriginIsCurrentLocation = true;

    selectedPlace = null;

    notifyListeners();
    await refreshPlaces();
  }
}
