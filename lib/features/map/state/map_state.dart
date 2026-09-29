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
      places = await gateway.loadPlaces(query: query, category: category);
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
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      selectedPlace = await gateway.loadPlaceDetail(placeId);
    } catch (e) {
      selectedPlace = null;
      errorMessage = 'Không tải được chi tiết địa điểm: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
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

  void beginDirectionsTo(GoMateMapPlace destination) {
    route = null;
    directionsOrigin = null;
    directionsOriginLabel = 'Chọn địa điểm bắt đầu';
    directionsOriginIsCurrentLocation = false;
    choosingDirectionsOrigin = true;
    directionsDestination = destination;
    selectedPlace = null;
    mode = GoMateMapMode.directions;
    tripStops = [];
    members = [];
    errorMessage = null;
    notifyListeners();
  }

  Future<bool> showDirections({
    required GoMateMapPlace origin,
    required GoMateMapPlace destination,
  }) async {
    loading = true;
    errorMessage = null;
    choosingDirectionsOrigin = false;
    notifyListeners();

    try {
      final calculated = await gateway.loadDirections(
        originPlaceId: origin.placeId,
        destinationPlaceId: destination.placeId,
      );

      route = calculated;
      directionsOrigin = origin.position;
      directionsOriginLabel = origin.name;
      directionsOriginIsCurrentLocation = false;
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

  Future<bool> showDirectionsFromCurrentLocation({
    required Position origin,
    required GoMateMapPlace destination,
  }) async {
    loading = true;
    errorMessage = null;
    choosingDirectionsOrigin = false;
    notifyListeners();

    try {
      final calculated = await gateway.loadDirections(
        originLatitude: origin.lat.toDouble(),
        originLongitude: origin.lng.toDouble(),
        destinationPlaceId: destination.placeId,
      );

      route = calculated;
      directionsOrigin = origin;
      directionsOriginLabel = 'Vị trí của tôi';
      directionsOriginIsCurrentLocation = true;
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

  Future<bool> changeDirectionsOriginPlace(String originPlaceId) async {
    final destination = directionsDestination;
    if (destination == null) return false;

    if (originPlaceId == destination.placeId) {
      errorMessage = 'Điểm bắt đầu phải khác điểm đến.';
      notifyListeners();
      return false;
    }

    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final origin = await gateway.loadPlaceDetail(originPlaceId);
      return showDirections(origin: origin, destination: destination);
    } catch (e) {
      errorMessage = 'Không tải được chỉ đường: $e';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> recalculateDirectionsFrom(GoMateMapPlace origin) {
    final destination = directionsDestination;
    if (destination == null) return Future.value(false);

    return showDirections(origin: origin, destination: destination);
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
