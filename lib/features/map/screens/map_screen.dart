import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/snackbar.dart';
import '../../trip/screens/trip_detail_screen.dart';
import '../data/spring_map_gateway.dart';
import '../models/map_place.dart';
import '../models/map_route.dart';
import '../services/location_service.dart';
import '../services/mapbox_layer_controller.dart';
import '../state/map_state.dart';
import '../state/map_ui_session.dart';
import '../widgets/directions_route_sheet.dart';
import '../widgets/map_controls.dart';
import '../widgets/map_status_pill.dart';
import '../widgets/place_bottom_sheet.dart';
import '../widgets/route_editor_sheet.dart';
import 'map_place_search_screen.dart';
import 'place_detail_screen.dart';

class GoMateMapScreen extends StatefulWidget {
  final double bottomNavigationInset;

  const GoMateMapScreen({
    super.key,
    this.bottomNavigationInset = 0,
  });

  @override
  State<GoMateMapScreen> createState() => _GoMateMapScreenState();
}

class _GoMateMapScreenState extends State<GoMateMapScreen> {
  final GoMateMapState _state = GoMateMapState(SpringGoMateMapGateway());
  final GoMateMapboxLayerController _layers = GoMateMapboxLayerController();
  final GoMateLocationService _locationService = GoMateLocationService();

  final Position _defaultCenter = Position(108.4488, 11.9416);

  MapboxMap? _map;
  String? _coordinateText;

  /// Multi-stop là state UI mới. Backend gateway hiện tại không bị sửa.
  List<GoMateMapPlace> _directionsStops = <GoMateMapPlace>[];
  GoMateMapRoute? _routeOverride;
  GoMateMapPlace? _directionsOriginPlace;
  bool _editingRoute = false;

  GoMateMapRoute? get _activeRoute => _routeOverride ?? _state.route;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onStateChanged);
    unawaited(_loadInitialPlaces());
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _state.dispose();
    _layers.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadInitialPlaces() async {
    await _state.init();
    if (_map != null && _state.mode == GoMateMapMode.explore) {
      await _layers.showExplorePlaces(_state.places);
    }
  }

  Future<void> _openPinnedTrip() async {
    final trip = GoMateMapUiSession.pinnedTrip;
    if (trip == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripDetailScreen(trip: trip),
      ),
    );
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    await _layers.attach(
      map,
      onPlaceTap: (placeId) => unawaited(_selectPlace(placeId)),
    );
    await _renderCurrentMode();
  }

  Future<void> _onStyleLoaded() async {
    await _layers.configureGoMateBaseStyle();
  }

  Future<void> _renderCurrentMode() async {
    switch (_state.mode) {
      case GoMateMapMode.explore:
        await _layers.showExplorePlaces(_state.places);
        break;
      case GoMateMapMode.directions:
        final route = _activeRoute;
        final origin = _state.directionsOrigin;
        final destination = _directionsStops.isNotEmpty
            ? _directionsStops.last
            : _state.directionsDestination;
        if (route != null && origin != null && destination != null) {
          await _layers.renderDirections(
            route: route,
            origin: origin,
            destination: destination,
          );
        }
        break;
      case GoMateMapMode.trip:
        if (_state.route != null) {
          await _layers.renderTrip(
            route: _state.route!,
            stops: _state.tripStops,
            members: _state.members,
          );
        }
        break;
    }
  }

  Future<void> _selectPlace(String placeId) async {
    if (_state.mode != GoMateMapMode.explore) return;

    await _state.selectPlace(placeId);
    final place = _state.selectedPlace;
    if (place == null) return;

    GoMateMapUiSession.addRecent(place);
    await _layers.renderSelected(place);
    await _layers.focusPlace(place);
  }

  Future<void> _moveToCurrentLocation() async {
    final result = await _locationService.getCurrentLocation();

    switch (result.state) {
      case GoMateLocationState.ready:
        final p = result.position!;
        await _layers.enableLocationPuck();
        await _layers.focusCoordinate(
          Position(p.longitude, p.latitude),
          zoom: 16.2,
        );
        break;
      case GoMateLocationState.serviceOff:
        _showMessage('GPS đang tắt. Hãy bật Location rồi thử lại.');
        break;
      case GoMateLocationState.permissionDenied:
        _showMessage('GoMate cần quyền vị trí để hiển thị vị trí của bạn.');
        break;
      case GoMateLocationState.permissionDeniedForever:
        _showMessage('Quyền vị trí đã bị chặn. Hãy bật lại trong Settings.');
        break;
    }
  }

  Future<Position?> _currentPositionForDirections() async {
    final result = await _locationService.getCurrentLocation();

    switch (result.state) {
      case GoMateLocationState.ready:
        final p = result.position!;
        return Position(p.longitude, p.latitude);
      case GoMateLocationState.serviceOff:
        _showMessage('GPS đang tắt. Hãy bật Location rồi thử lại.');
        return null;
      case GoMateLocationState.permissionDenied:
        _showMessage('GoMate cần quyền vị trí để chỉ đường.');
        return null;
      case GoMateLocationState.permissionDeniedForever:
        _showMessage('Quyền vị trí đã bị chặn. Hãy bật lại trong Settings.');
        return null;
    }
  }

  Future<void> _directionsToSelected() async {
    final destination = _state.selectedPlace;
    if (destination == null) return;

    final origin = await _currentPositionForDirections();
    if (origin == null) return;

    await _layers.enableLocationPuck();
    final ok = await _state.showDirectionsFromCurrentLocation(
      origin: origin,
      destination: destination,
    );

    if (!ok) {
      _showMessage(_state.errorMessage ?? 'Không tải được chỉ đường.');
      return;
    }

    _routeOverride = null;
    _directionsOriginPlace = null;
    _editingRoute = false;
    _directionsStops = <GoMateMapPlace>[destination];
    setState(() {});
    await _renderCurrentMode();
  }

  Future<void> _openPlaceSearch() async {
    final selected = await Navigator.of(context).push<GoMateMapPlace>(
      MaterialPageRoute(
        builder: (_) => MapPlaceSearchScreen(
          initialPlaces: _state.places,
          onSearch: _searchPlacesForScreen,
        ),
      ),
    );

    if (!mounted || selected == null) return;

    await _state.selectPlace(selected.placeId);
    final loaded = _state.selectedPlace;
    if (loaded == null) return;

    GoMateMapUiSession.addRecent(loaded);
    await _layers.renderSelected(loaded);
    await _layers.focusPlace(loaded);
  }

  Future<List<GoMateMapPlace>> _searchPlacesForScreen(String query) async {
    await _state.setQuery(query);
    if (_state.mode == GoMateMapMode.explore) {
      await _layers.showExplorePlaces(_state.places);
    }
    return _state.places;
  }

  Future<GoMateMapPlace?> _pickRouteStop() async {
    return Navigator.of(context).push<GoMateMapPlace>(
      MaterialPageRoute(
        builder: (_) => MapPlaceSearchScreen(
          initialPlaces: _state.places,
          onSearch: _searchPlacesForScreen,
        ),
      ),
    );
  }


  Future<void> _changeRouteOrigin() async {
    if (_directionsStops.isEmpty) return;

    final selected = await _pickRouteStop();
    if (!mounted || selected == null) return;

    final destination = _directionsStops.first;
    if (selected.placeId == destination.placeId) {
      _showMessage('Điểm bắt đầu phải khác điểm đến.');
      return;
    }

    final ok = await _state.showDirections(
      origin: selected,
      destination: destination,
    );

    if (!ok) {
      _showMessage(_state.errorMessage ?? 'Không tải được chỉ đường.');
      return;
    }

    _directionsOriginPlace = selected;
    _routeOverride = null;
    setState(() {});
    await _renderCurrentMode();
  }

  Future<void> _changeRouteDestination() async {
    if (_directionsStops.isEmpty) return;

    final selected = await _pickRouteStop();
    if (!mounted || selected == null) return;

    if (_directionsOriginPlace?.placeId == selected.placeId) {
      _showMessage('Điểm đến phải khác điểm bắt đầu.');
      return;
    }

    bool ok;
    if (_directionsOriginPlace == null) {
      final origin = await _currentPositionForDirections();
      if (origin == null) return;
      ok = await _state.showDirectionsFromCurrentLocation(
        origin: origin,
        destination: selected,
      );
    } else {
      ok = await _state.showDirections(
        origin: _directionsOriginPlace!,
        destination: selected,
      );
    }

    if (!ok) {
      _showMessage(_state.errorMessage ?? 'Không tải được chỉ đường.');
      return;
    }

    _directionsStops = <GoMateMapPlace>[selected];
    _routeOverride = null;
    setState(() {});
    await _renderCurrentMode();
  }

  Future<void> _swapRouteEndpoints() async {
    if (_directionsStops.length != 1) return;

    final originPlace = _directionsOriginPlace;
    if (originPlace == null) {
      // Backend hiện tại chỉ nhận GPS ở origin, không nhận GPS làm destination.
      // Không sửa backend trong task UI này.
      _showMessage(
        'Đảo chiều với Vị trí của bạn sẽ nối khi backend hỗ trợ GPS ở điểm đến.',
      );
      return;
    }

    final oldDestination = _directionsStops.first;
    final ok = await _state.showDirections(
      origin: oldDestination,
      destination: originPlace,
    );

    if (!ok) {
      _showMessage(_state.errorMessage ?? 'Không đảo được lộ trình.');
      return;
    }

    _directionsOriginPlace = oldDestination;
    _directionsStops = <GoMateMapPlace>[originPlace];
    _routeOverride = null;
    setState(() {});
    await _renderCurrentMode();
  }

  void _openRouteEditor() {
    if (_state.mode != GoMateMapMode.directions) return;
    setState(() => _editingRoute = true);
  }

  Future<void> _applyRouteEditor(GoMateRouteEditorResult result) async {
    if (!mounted || result.stops.isEmpty) {
      _showMessage('Cần ít nhất một điểm đến.');
      return;
    }

    setState(() => _editingRoute = false);

    final firstStop = result.stops.first;
    bool ok;

    if (result.originPlace == null) {
      final currentOrigin = await _currentPositionForDirections();
      if (currentOrigin == null) return;
      ok = await _state.showDirectionsFromCurrentLocation(
        origin: currentOrigin,
        destination: firstStop,
      );
    } else {
      ok = await _state.showDirections(
        origin: result.originPlace!,
        destination: firstStop,
      );
    }

    if (!ok || _state.route == null) {
      _showMessage(_state.errorMessage ?? 'Không tải được chỉ đường.');
      return;
    }

    _directionsOriginPlace = result.originPlace;
    _directionsStops = List<GoMateMapPlace>.from(result.stops);

    if (result.stops.length == 1) {
      _routeOverride = null;
      setState(() {});
      await _renderCurrentMode();
      return;
    }

    try {
      final segments = <GoMateMapRoute>[_state.route!];

      for (var i = 1; i < result.stops.length; i++) {
        segments.add(
          await _state.gateway.loadDirections(
            originPlaceId: result.stops[i - 1].placeId,
            destinationPlaceId: result.stops[i].placeId,
          ),
        );
      }

      final geometry = <Position>[];
      var distanceKm = 0.0;
      var durationMinutes = 0;
      var isFallback = false;

      for (var i = 0; i < segments.length; i++) {
        final segment = segments[i];
        distanceKm += segment.distanceKm;
        durationMinutes += segment.durationMinutes;
        isFallback = isFallback || segment.isFallback;

        if (i == 0 || geometry.isEmpty) {
          geometry.addAll(segment.geometry);
        } else if (segment.geometry.isNotEmpty) {
          geometry.addAll(segment.geometry.skip(1));
        }
      }

      final combined = GoMateMapRoute(
        routeId: 'ui-multistop-${DateTime.now().millisecondsSinceEpoch}',
        geometry: geometry,
        distanceKm: distanceKm,
        durationMinutes: durationMinutes,
        orderedPlaceIds: result.stops.map((item) => item.placeId).toList(),
        isFallback: isFallback,
        warning: isFallback
            ? 'Một phần lộ trình đang dùng dữ liệu fallback.'
            : null,
      );

      _routeOverride = combined;
      setState(() {});

      final origin = _state.directionsOrigin;
      if (origin != null) {
        await _layers.renderDirections(
          route: combined,
          origin: origin,
          destination: result.stops.last,
        );
      }
    } catch (_) {
      _routeOverride = null;
      _showMessage('Không cập nhật được các điểm dừng.');
      await _renderCurrentMode();
    }
  }

  Future<void> _closeDirections() async {
    _routeOverride = null;
    _directionsOriginPlace = null;
    _editingRoute = false;
    _directionsStops.clear();
    await _state.showExplore();
    await _layers.showExplorePlaces(_state.places);
  }

  void _startDirections() {
    GoMateSnackBar.show(
      context,
      message: 'Đã sẵn sàng bắt đầu lộ trình',
      bottomOffset: 90,
      icon: LucideIcons.navigation,
    );
  }

  Future<void> _openSelectedPlaceDetail() async {
    final selected = _state.selectedPlace;
    if (selected == null) return;

    final routeRequested = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PlaceDetailScreen(place: _toUiPlace(selected)),
      ),
    );

    if (!mounted) return;
    if (routeRequested == true) await _directionsToSelected();
  }

  MapPlaceUi _toUiPlace(GoMateMapPlace place) {
    final tags = <String>[
      place.categoryLabel,
      if (place.district != null) place.district!,
      place.province ?? 'Đà Lạt',
    ];

    return MapPlaceUi(
      id: place.placeId,
      name: place.name,
      subtitle: place.description ?? 'Khám phá địa điểm nổi bật.',
      address: place.address,
      distanceText: 'Xem trên bản đồ',
      openInfo: place.openingHours ?? 'Đang cập nhật',
      priceInfo: _priceInfo(place.priceLevel),
      rating: place.rating,
      reviewCount: place.reviewCount,
      likeCount: place.saveCount,
      tags: tags,
      imageUrl: place.thumbnailUrl,
      mediaUrls: place.mediaUrls,
    );
  }

  String _priceInfo(int? priceLevel) {
    return switch (priceLevel) {
      0 => 'Miễn phí',
      1 => 'Chi phí thấp',
      2 => 'Chi phí vừa phải',
      3 => 'Chi phí cao',
      4 => 'Cao cấp',
      _ => 'Đang cập nhật',
    };
  }

  Future<void> _resetNorth() async {
    final map = _map;
    if (map == null) return;
    final camera = await map.getCameraState();
    await map.easeTo(
      CameraOptions(
        center: camera.center,
        zoom: camera.zoom,
        pitch: 15,
        bearing: 0,
      ),
      MapAnimationOptions(duration: 450),
    );
  }

  void _onMapTap(MapContentGestureContext gesture) {
    unawaited(_handleMapTap(gesture));
  }

  Future<void> _handleMapTap(MapContentGestureContext gesture) async {
    if (_state.mode != GoMateMapMode.explore) return;

    if (_state.selectedPlace != null) {
      _state.clearSelection();
      await _layers.renderSelected(null);
      return;
    }

    final lng = gesture.point.coordinates.lng.toDouble();
    final lat = gesture.point.coordinates.lat.toDouble();
    setState(() {
      _coordinateText = '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    });

    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _coordinateText = null);
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    GoMateSnackBar.show(
      context,
      message: message,
      bottomOffset: 90,
      icon: LucideIcons.circle_alert,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = widget.bottomNavigationInset;
    final top = MediaQuery.paddingOf(context).top;
    final route = _activeRoute;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapWidget(
              key: const ValueKey('gomate-map'),
              styleUri: MapboxStyles.STANDARD,
              cameraOptions: CameraOptions(
                center: Point(coordinates: _defaultCenter),
                zoom: 14.2,
                pitch: 15,
                bearing: 0,
              ),
              onMapCreated: _onMapCreated,
              onStyleLoadedListener: (_) => _onStyleLoaded(),
              onTapListener: _onMapTap,
            ),
          ),

          Positioned(
            top: top + 14,
            right: 16,
            child: GoMateMapControls(
              onSearch: _openPlaceSearch,
              onLocation: _moveToCurrentLocation,
              onPinnedTrip:
                  GoMateMapUiSession.hasPinnedTrip ? _openPinnedTrip : null,
            ),
          ),

          if (_state.loading)
            Positioned(
              top: top + 90,
              left: 0,
              right: 0,
              child: const Center(
                child: GoMateMapStatusPill(
                  text: 'Đang tải dữ liệu...',
                  icon: LucideIcons.refresh_cw,
                ),
              ),
            ),

          if (_coordinateText != null)
            Positioned(
              top: top + 90,
              left: 0,
              right: 0,
              child: Center(
                child: GoMateMapStatusPill(
                  text: _coordinateText!,
                  icon: LucideIcons.map_pin,
                ),
              ),
            ),

          if (_state.selectedPlace != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 14 + bottom,
              child: GoMatePlaceBottomSheet(
                place: _state.selectedPlace!,
                onClose: () {
                  _state.clearSelection();
                  unawaited(_layers.renderSelected(null));
                },
                onToggleSaved: _state.toggleSavedSelected,
                onDirections: _directionsToSelected,
                onOpenDetail: () => unawaited(_openSelectedPlaceDetail()),
              ),
            )
          else if (_state.mode == GoMateMapMode.directions &&
              route != null &&
              _directionsStops.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 14 + bottom,
              child: _editingRoute
                  ? GoMateRouteEditorSheet(
                      originLabel: _state.directionsOriginLabel,
                      initialOriginPlace: _directionsOriginPlace,
                      initialStops: _directionsStops,
                      onPickPlace: _pickRouteStop,
                      onCancel: () => setState(() => _editingRoute = false),
                      onDone: (result) => unawaited(_applyRouteEditor(result)),
                    )
                  : GoMateDirectionsRouteSheet(
                      route: route,
                      originLabel: _state.directionsOriginLabel,
                      stops: _directionsStops,
                      onOriginTap: () => unawaited(_changeRouteOrigin()),
                      onDestinationTap: () =>
                          unawaited(_changeRouteDestination()),
                      onSwap: () => unawaited(_swapRouteEndpoints()),
                      onEdit: _openRouteEditor,
                      onAddStop: _openRouteEditor,
                      onStart: _startDirections,
                      onClose: () => unawaited(_closeDirections()),
                    ),
            ),
        ],
      ),
    );
  }
}
