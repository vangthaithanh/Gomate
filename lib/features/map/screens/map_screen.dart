import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/widgets/gomate_itinerary_picker.dart';
import '../../../core/widgets/snackbar.dart';
import '../../messages/data/message_repository.dart';
import '../../messages/screens/chat_screen.dart';
import '../../trip/data/trip_repository.dart';
import '../../trip/models/trip_ui_models.dart';
import '../../trip/models/trip_planning_context.dart';
import '../../trip/screens/trip_detail_screen.dart';
import '../../trip/location/trip_location_realtime_service.dart';
import '../data/spring_map_gateway.dart';
import '../models/map_focus_target.dart';
import '../models/map_member.dart';
import '../models/map_place.dart';
import '../services/location_service.dart';
import '../services/mapbox_layer_controller.dart';
import '../state/map_state.dart';
import '../state/map_ui_session.dart';
import '../widgets/map_add_place_flow_panel.dart';
import '../widgets/map_controls.dart';
import '../widgets/map_day_route_panel.dart';
import '../widgets/map_place_card.dart';
import '../widgets/map_status_pill.dart';
import '../widgets/map_trip_header.dart';
import '../widgets/map_trip_pin_button.dart';
import 'map_place_search_screen.dart';
import 'place_detail_screen.dart';

class GoMateMapScreen extends StatefulWidget {
  final double bottomNavigationInset;
  final MapFocusTarget? focusTarget;
  final bool active;

  const GoMateMapScreen({
    super.key,
    this.bottomNavigationInset = 0,
    this.focusTarget,
    this.active = true,
  });

  @override
  State<GoMateMapScreen> createState() => _GoMateMapScreenState();
}

class _GoMateMapScreenState extends State<GoMateMapScreen> {
  static const int _mapCameraUiThrottleMs = 80;
  static const int _mapIdleSettleMs = 120;
  static const int _placeDetailEnrichDelayMs = 460;
  static const double _mapZoomUiThreshold = 0.08;
  static const double _placeCardMoveThresholdPx = 4.0;

  final GoMateMapState _state = GoMateMapState(SpringGoMateMapGateway());

  final GoMateMapboxLayerController _layers = GoMateMapboxLayerController();

  final GoMateLocationService _locationService = GoMateLocationService();

  final MessageRepository _messageRepository =
      RealDirectMessageRepository.instance;

  final RealTripRepository _tripRepository = RealTripRepository.instance;
  StreamSubscription<TripMemberLocationSnapshot>? _memberSnapshots;

  final Position _defaultCenter = Position(108.4488, 11.9416);

  MapboxMap? _map;

  String? _coordinateText;
  MapFocusTarget? _pendingFocusTarget;

  double _bearing = 0;
  double _currentZoom = 14.2;

  final ValueNotifier<_MapCameraChromeState> _cameraChrome =
      ValueNotifier<_MapCameraChromeState>(const _MapCameraChromeState());

  final ValueNotifier<_SelectedPlaceOverlayState> _selectedPlaceOverlay =
      ValueNotifier<_SelectedPlaceOverlayState>(
        const _SelectedPlaceOverlayState(),
      );

  double? _pendingLayerZoom;
  bool _mapCameraActive = false;
  bool _mapIdleSyncRunning = false;
  bool _mapIdleSyncQueued = false;
  Timer? _mapIdleTimer;

  // Flutter place-card được neo vào đúng geographic position của marker.
  bool _selectedPlacePointUpdateRunning = false;
  bool _selectedPlacePointUpdateRequested = false;
  Timer? _selectedPlacePointTimer;
  Timer? _coordinateTextTimer;
  int _lastSelectedPlacePointUpdateMs = 0;

  // Chỉ update pulse state sau khi current-user avatar thực sự được bật.
  bool _locationAvatarVisible = false;
  bool _lastAppliedTrackingActive = false;

  bool _tripHeaderExpanded = false;

  int _selectedDay = 1;

  GoMateMapAddPlaceStep? _addStep;
  GoMateMapPlace? _pendingAddPlace;
  TripUi? _pendingAddTrip;

  String? _editingStopId;
  String? _initialStartTime;
  String? _initialEndTime;
  TripPlanningContext? _flowClock;
  String? _flowError;
  bool _savingStop = false;
  bool _openingStop = false;
  int _flowSerial = 0;

  int _flowDay = 1;
  String? _flowStartTime;
  String? _flowEndTime;

  bool _processingSessionRequest = false;
  bool _tripRouteSyncRunning = false;
  bool _tripRouteSyncQueued = false;
  bool _tripRouteQueuedFitCamera = false;
  bool _tripRouteQueuedForceRedraw = false;
  String? _lastTripRouteSignature;
  String? _lastTripRouteErrorSignature;
  final Set<String> _tripRouteDetailLoadingIds = <String>{};
  int _placeSelectionSerial = 0;

  TripUi? get _trip => GoMateMapUiSession.displayedTrip;

  bool get _showCompass {
    final value = ((_bearing % 360) + 360) % 360;

    return value > 1.0 && value < 359.0;
  }

  bool get _addFlowActive => _addStep != null;

  List<TripPlaceUi> get _dayPlaces {
    final trip = _trip;
    if (trip == null) {
      return const <TripPlaceUi>[];
    }

    return trip.places
        .where((place) => place.day == _selectedDay)
        .toList(growable: false);
  }

  List<TripPlaceUi> _routePlacesFor(TripUi trip, int day) {
    return trip.places
        .where((place) => place.day == day)
        .where((place) => place.placeId.trim().isNotEmpty)
        .toList(growable: false);
  }

  String _tripRouteSignature(TripUi trip, int day) {
    final ids = _routePlacesFor(
      trip,
      day,
    ).map((place) => place.placeId.trim()).join('>');
    return '${trip.id}|$day|$ids';
  }

  bool _needsTripDetailForRoute(TripUi trip) {
    if (!trip.isDetail) return true;
    if (trip.places.isEmpty) {
      return false;
    }

    return trip.places.any(
      (place) =>
          place.placeId.trim().isEmpty ||
          place.id.trim().startsWith('summary-stop-'),
    );
  }

  @override
  void initState() {
    super.initState();

    _selectedDay = GoMateMapUiSession.selectedDay;

    _state.addListener(_onMapStateChanged);
    _pendingFocusTarget = widget.focusTarget;

    GoMateMapUiSession.revision.addListener(_onMapUiSessionChanged);
    _memberSnapshots = TripLocationRealtimeService.instance.updates.listen((
      snapshot,
    ) {
      if (!mounted) return;
      final trip = _trip;
      if (trip == null || !trip.isGroup || snapshot.tripId != trip.id) {
        unawaited(_layers.hidePreviewMembers());
      } else {
        // Do not notify MapState/session, rebuild the map, or touch route layers.
        unawaited(
          _layers.showPreviewMembers(
            snapshot.members,
            currentUserId: _messageRepository.currentUserId,
          ),
        );
      }
    });

    unawaited(_loadInitialPlaces());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_consumeSessionRequests());
      unawaited(_applyPendingFocusTarget());
    });
  }

  @override
  void didUpdateWidget(covariant GoMateMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final target = widget.focusTarget;
    if (target != null && !identical(target, oldWidget.focusTarget)) {
      _pendingFocusTarget = target;
      unawaited(_applyPendingFocusTarget());
    }
  }

  @override
  void dispose() {
    unawaited(_memberSnapshots?.cancel());
    _state.removeListener(_onMapStateChanged);

    GoMateMapUiSession.revision.removeListener(_onMapUiSessionChanged);

    if (GoMateMapUiSession.hideMapBottomNav) {
      GoMateMapUiSession.setMapBottomNavHidden(false);
    }

    _state.dispose();
    _layers.dispose();
    _mapIdleTimer?.cancel();
    _selectedPlacePointTimer?.cancel();
    _coordinateTextTimer?.cancel();
    _cameraChrome.dispose();
    _selectedPlaceOverlay.dispose();

    super.dispose();
  }

  void _onMapStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onMapUiSessionChanged() {
    if (!mounted) return;

    final sessionDay = GoMateMapUiSession.selectedDay;

    final trip = _trip;

    if (trip != null) {
      _selectedDay = sessionDay.clamp(1, trip.days).toInt();
    }

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_consumeSessionRequests());
      unawaited(_syncSessionDependentMapVisuals());
    });
  }

  Future<void> _syncSessionDependentMapVisuals() async {
    await _syncTripMemberPreview(_trip);
    await _syncDisplayedTripRoute();

    if (!_locationAvatarVisible) {
      return;
    }

    final trackingActive = GoMateMapUiSession.hasPinnedTrip;

    if (trackingActive == _lastAppliedTrackingActive) {
      return;
    }

    _lastAppliedTrackingActive = trackingActive;

    await _layers.setRouteTrackingActive(trackingActive);
  }

  Future<void> _loadInitialPlaces() async {
    await _state.init();

    if (_map != null) {
      await _renderExplorePlaces(forceTripRouteRedraw: true);
    }

    await _syncTripMemberPreview(_trip);
    await _syncDisplayedTripRoute();

    await _consumeSessionRequests();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;

    // Tắt compass native của Mapbox.
    // Ta render compass vào đúng dãy nút tròn bên phải.
    await map.compass.updateSettings(CompassSettings(enabled: false));

    await _layers.attach(
      map,
      onPlaceTap: (placeId) {
        unawaited(_selectPlace(placeId));
      },
    );

    await _renderExplorePlaces(forceTripRouteRedraw: true);

    await _syncTripMemberPreview(_trip);
    await _syncDisplayedTripRoute(fitCamera: false, forceRedraw: true);

    await _applyPendingFocusTarget();
  }

  Future<void> _applyPendingFocusTarget() async {
    final target = _pendingFocusTarget;
    if (target == null || _map == null) {
      return;
    }

    _pendingFocusTarget = null;

    if (_state.mode != GoMateMapMode.explore) {
      await _state.showExplore();
      await _renderExplorePlaces(forceTripRouteRedraw: true);
      await _syncTripMemberPreview(_trip);
    }

    if (target.hasPlace) {
      await _selectPlace(target.placeId!.trim());
      return;
    }

    if (target.hasCoordinate) {
      setState(() {
        _coordinateText = target.label;
      });

      await _layers.focusCoordinate(
        Position(target.longitude!, target.latitude!),
        zoom: 15.8,
      );
    }
  }

  Future<void> _onStyleLoaded() async {
    await _layers.configureGoMateBaseStyle();

    final map = _map;
    if (map == null) return;

    // Chỉ marker thuộc dữ liệu GoMate (_state.places) được render như
    // "địa điểm" trên Map. Basemap chỉ giữ thông tin nền/đường.
    //
    // `showPointOfInterestLabels = false`:
    //   ẩn icon + text POI Mapbox (hotel, restaurant, shop, attraction...).
    //
    // `showPlaceLabels = false`:
    //   controller V17 đang đặt true; phải override lại ở đây để các
    //   place/landmark từ basemap không lẫn với ~140 địa điểm của app.
    await map.style.setStyleImportConfigProperties('basemap', <String, Object>{
      'showPointOfInterestLabels': false,
      'showPlaceLabels': false,
      'showTransitLabels': false,

      // Vẫn giữ tên đường để người dùng định hướng.
      'showRoadLabels': true,
    });

    // Các option này phụ thuộc version Standard/native SDK.
    // Nếu version hiện tại chưa hỗ trợ thì bỏ qua, không làm hỏng style.
    for (final property in <String>[
      'showLandmarkIcons',
      'showLandmarkIconLabels',
      'showIndoorLabels',
    ]) {
      try {
        await map.style.setStyleImportConfigProperty(
          'basemap',
          property,
          false,
        );
      } catch (_) {
        // Compatibility fallback.
      }
    }

    // Re-render đúng source dữ liệu app sau khi basemap hoàn tất config.
    // Không lấy bất kỳ POI nào từ Mapbox làm marker GoMate.
    await _renderExplorePlaces(forceTripRouteRedraw: true);
  }

  void _onCameraChanged(CameraChangedEventData event) {
    _mapIdleTimer?.cancel();
    _mapIdleTimer = null;

    final camera = event.cameraState;

    final nextBearing = camera.bearing;
    final nextZoom = camera.zoom;

    final bearingChanged = (_bearing - nextBearing).abs() > 0.5;
    final zoomChanged = (_currentZoom - nextZoom).abs() > 0.02;

    if (bearingChanged) {
      _bearing = nextBearing;
    }

    if (zoomChanged) {
      _currentZoom = nextZoom;
    }

    _syncCameraChrome();
    _markMapCameraActive();
    _pendingLayerZoom = nextZoom;

    // Card địa điểm phải đi theo marker khi pan / rotate / zoom.
    _selectedPlacePointUpdateRequested = _state.selectedPlace != null;
  }

  void _syncCameraChrome() {
    final next = _MapCameraChromeState(
      showCompass: _showCompass,
      bearing: _bearing,
    );

    final current = _cameraChrome.value;
    if (current.showCompass == next.showCompass &&
        (current.bearing - next.bearing).abs() <= 0.5) {
      return;
    }

    _cameraChrome.value = next;
  }

  void _markMapCameraActive() {
    if (_mapCameraActive) {
      return;
    }

    _mapCameraActive = true;
    unawaited(_layers.setMapInteractionActive(true));
  }

  void _onMapIdle(MapIdleEventData event) {
    _mapIdleTimer?.cancel();
    _mapIdleTimer = Timer(const Duration(milliseconds: _mapIdleSettleMs), () {
      _mapIdleTimer = null;

      if (mounted) {
        unawaited(_handleMapIdle());
      }
    });
  }

  Future<void> _handleMapIdle() async {
    if (_mapIdleSyncRunning) {
      _mapIdleSyncQueued = true;
      return;
    }

    _mapIdleSyncRunning = true;

    try {
      do {
        _mapIdleSyncQueued = false;
        _mapCameraActive = false;

        await _layers.setMapInteractionActive(false);
        await _flushPendingLayerZoomUpdate();

        if (_state.selectedPlace != null) {
          _requestSelectedPlaceScreenPointUpdate();
        }
      } while (_mapIdleSyncQueued && mounted);
    } finally {
      _mapIdleSyncRunning = false;
    }
  }

  Future<void> _flushPendingLayerZoomUpdate() async {
    final pending = _pendingLayerZoom;
    if (!mounted || pending == null) {
      return;
    }

    await _layers.updateExploreZoom(pending);
  }

  void _requestSelectedPlaceScreenPointUpdate() {
    if (_map == null || _state.selectedPlace == null) {
      return;
    }

    _selectedPlacePointUpdateRequested = true;

    if (_selectedPlacePointUpdateRunning) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final waitMs =
        _mapCameraUiThrottleMs - (now - _lastSelectedPlacePointUpdateMs);

    if (waitMs <= 0) {
      unawaited(_drainSelectedPlaceScreenPointUpdates());
      return;
    }

    _selectedPlacePointTimer ??= Timer(Duration(milliseconds: waitMs), () {
      _selectedPlacePointTimer = null;
      if (mounted) {
        unawaited(_drainSelectedPlaceScreenPointUpdates());
      }
    });
  }

  Future<void> _drainSelectedPlaceScreenPointUpdates() async {
    if (_selectedPlacePointUpdateRunning) {
      return;
    }

    _selectedPlacePointUpdateRunning = true;

    try {
      _selectedPlacePointUpdateRequested = false;
      _lastSelectedPlacePointUpdateMs = DateTime.now().millisecondsSinceEpoch;
      await _updateSelectedPlaceScreenPoint();
    } finally {
      _selectedPlacePointUpdateRunning = false;
    }

    if (_selectedPlacePointUpdateRequested && mounted) {
      _requestSelectedPlaceScreenPointUpdate();
    }
  }

  Future<void> _updateSelectedPlaceScreenPoint() async {
    final map = _map;
    final place = _state.selectedPlace;

    if (map == null || place == null) {
      return;
    }

    final selectedId = place.placeId;

    final point = await map.pixelForCoordinate(
      Point(coordinates: place.position),
    );

    if (!mounted || _state.selectedPlace?.placeId != selectedId) {
      return;
    }

    final previous = _selectedPlaceOverlay.value;
    final previousPoint = previous.point;

    if (previousPoint != null &&
        (previousPoint.x - point.x).abs() < _placeCardMoveThresholdPx &&
        (previousPoint.y - point.y).abs() < _placeCardMoveThresholdPx &&
        (previous.zoom - _currentZoom).abs() < _mapZoomUiThreshold) {
      return;
    }

    _selectedPlaceOverlay.value = _SelectedPlaceOverlayState(
      point: point,
      zoom: _currentZoom,
    );
  }

  double _selectedMarkerRadiusForZoom(double zoom) {
    const startZoom = 14.4;
    const fullZoom = 16.8;
    const minScale = 1.08;
    const maxScale = 1.42;

    if (zoom <= startZoom) {
      return 37.0 * minScale;
    }

    if (zoom >= fullZoom) {
      return 37.0 * maxScale;
    }

    final rawT = (zoom - startZoom) / (fullZoom - startZoom);

    final t = Curves.easeOutCubic.transform(rawT);
    final scale = minScale + ((maxScale - minScale) * t);

    return 37.0 * scale;
  }

  Future<void> _resetNorth() async {
    final map = _map;

    if (map == null) return;

    final camera = await map.getCameraState();

    await map.easeTo(
      CameraOptions(
        center: camera.center,
        zoom: camera.zoom,
        pitch: camera.pitch,
        bearing: 0,
      ),
      MapAnimationOptions(duration: 420),
    );
  }

  Future<void> _selectPlace(String placeId) async {
    if (_addFlowActive) {
      return;
    }

    final normalizedPlaceId = placeId.trim();
    if (normalizedPlaceId.isEmpty) {
      return;
    }

    final alreadySelected = _state.selectedPlace?.placeId == normalizedPlaceId;
    if (alreadySelected && _selectedPlaceOverlay.value.point != null) {
      return;
    }

    final serial = ++_placeSelectionSerial;

    final preview = _mapPlaceById(normalizedPlaceId);
    if (preview != null) {
      _state.selectPlacePreview(preview);

      GoMateMapUiSession.addRecent(preview);

      await _layers.renderSelected(preview);

      if (serial != _placeSelectionSerial || !mounted) {
        return;
      }

      unawaited(_layers.focusPlace(preview));

      _requestSelectedPlaceScreenPointUpdate();

      unawaited(_enrichSelectedPlace(normalizedPlaceId, serial));
      return;
    }

    await _state.selectPlace(normalizedPlaceId);

    final place = _state.selectedPlace;

    if (place == null) {
      return;
    }

    GoMateMapUiSession.addRecent(place);

    await _layers.renderSelected(place);

    await _layers.focusPlace(place);

    _requestSelectedPlaceScreenPointUpdate();
  }

  GoMateMapPlace? _mapPlaceById(String placeId) {
    for (final place in _state.places) {
      if (place.placeId == placeId) {
        return place;
      }
    }

    final selected = _state.selectedPlace;
    if (selected?.placeId == placeId) {
      return selected;
    }

    return null;
  }

  Future<void> _enrichSelectedPlace(String placeId, int serial) async {
    // Let marker selection and camera focus start first; detail enrichment can
    // follow shortly after without competing with the tap gesture frame.
    await Future<void>.delayed(
      const Duration(milliseconds: _placeDetailEnrichDelayMs),
    );

    if (!mounted ||
        serial != _placeSelectionSerial ||
        _state.selectedPlace?.placeId != placeId) {
      return;
    }

    await _state.enrichSelectedPlace(placeId);

    if (!mounted ||
        serial != _placeSelectionSerial ||
        _state.selectedPlace?.placeId != placeId) {
      return;
    }

    final detail = _state.selectedPlace;
    if (detail != null) {
      GoMateMapUiSession.addRecent(detail);
    }
  }

  Future<void> _clearSelectedPlace() async {
    _placeSelectionSerial++;
    _selectedPlacePointTimer?.cancel();
    _selectedPlacePointTimer = null;
    _selectedPlacePointUpdateRequested = false;

    _state.clearSelection();

    if (mounted) {
      _selectedPlaceOverlay.value = const _SelectedPlaceOverlayState();
    }

    await _layers.renderSelected(null);
  }

  Future<void> _moveToCurrentLocation() async {
    final result = await _locationService.getCurrentLocation();

    switch (result.state) {
      case GoMateLocationState.ready:
        final p = result.position!;

        final current = Position(p.longitude, p.latitude);

        // V17:
        // avatar và custom pulse dùng cùng position.
        final trackingActive = GoMateMapUiSession.hasPinnedTrip;

        await _layers.enableLocationPuck(
          position: current,
          displayName: 'Bạn',
          routeActive: trackingActive,
        );

        _locationAvatarVisible = true;
        _lastAppliedTrackingActive = trackingActive;

        await _layers.focusCoordinate(current, zoom: 16.2);

        _lastTripRouteSignature = null;
        await _syncDisplayedTripRoute();

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

      case GoMateLocationState.whileInUseOnly:
        _showMessage('GoMate đang có quyền vị trí khi dùng app.');
        break;
    }
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

    if (!mounted || selected == null) {
      return;
    }

    await _selectPlace(selected.placeId);
  }

  Future<List<GoMateMapPlace>> _searchPlacesForScreen(String query) async {
    await _state.setQuery(query);

    await _renderExplorePlaces(forceTripRouteRedraw: true);

    return _state.places;
  }

  Future<TripUi?> _pickTrip() async {
    final trips = GoMateMapUiSession.availableTrips;

    final items = trips
        .map(
          (trip) => GoMateItineraryPickerItem(
            id: trip.id,
            title: trip.title,
            dateRange: trip.dateRangeLabel,
            summary: '${trip.days} ngày - ${trip.places.length} địa điểm',
            imageAsset: trip.coverAsset,
            memberCount: trip.isGroup ? trip.memberCount : 0,
          ),
        )
        .toList(growable: false);

    final selected = await Navigator.of(context)
        .push<GoMateItineraryPickerItem>(
          MaterialPageRoute(
            builder: (pickerContext) {
              return GoMateItineraryPickerScreen(
                items: items,
                showCancel: true,
                searchHint: 'Tìm kiếm lịch trình...',
                onCancel: () {
                  Navigator.of(pickerContext).pop();
                },
                onQuickCreate: () {
                  Navigator.of(pickerContext).pop();

                  GoMateMapUiSession.requestMainTab(3);
                  GoMateMapUiSession.requestCreateTrip();
                },
                onSelected: (item) {
                  Navigator.of(pickerContext).pop(item);
                },
              );
            },
          ),
        );

    if (!mounted || selected == null) {
      return null;
    }

    for (final trip in trips) {
      if (trip.id == selected.id) {
        try {
          return await _tripRepository.detail(trip.id);
        } catch (_) {
          return trip;
        }
      }
    }

    return null;
  }

  Future<void> _openTripPicker() async {
    final selected = await _pickTrip();

    if (!mounted || selected == null) {
      return;
    }

    GoMateMapUiSession.selectTrip(selected, day: 1);

    _selectedDay = 1;

    setState(() {
      _tripHeaderExpanded = false;
    });

    await _clearSelectedPlace();

    await _syncTripMemberPreview(selected);
    await _syncDisplayedTripRoute(fitCamera: true);
  }

  Future<void> _openTripDetail() async {
    final trip = _trip;

    if (trip == null) {
      return;
    }

    final result = await Navigator.of(context).push<TripDetailResult>(
      MaterialPageRoute(
        builder: (_) => TripDetailScreen(
          trip: trip,
          messageRepository: _messageRepository,
          tripRepository: _tripRepository,
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.removeFromList) {
      GoMateMapUiSession.removeTrip(result.trip.id);

      setState(() {
        _tripHeaderExpanded = false;
      });

      await _syncDisplayedTripRoute();
      return;
    }

    GoMateMapUiSession.updateTrip(result.trip);

    await _syncTripMemberPreview(result.trip);
    await _syncDisplayedTripRoute(fitCamera: true);
  }

  void _toggleTripExpanded() {
    final trip = _trip;
    if (trip == null) return;

    setState(() {
      _tripHeaderExpanded = !_tripHeaderExpanded;
    });

    if (!_tripHeaderExpanded) {
      return;
    }

    unawaited(_clearSelectedPlace());
  }

  void _changeDay(int delta) {
    final trip = _trip;

    if (trip == null) return;

    final next = (_selectedDay + delta).clamp(1, trip.days).toInt();

    if (next == _selectedDay) {
      return;
    }

    setState(() {
      _selectedDay = next;
    });

    GoMateMapUiSession.selectDay(next);
  }

  Future<void> _openGroupChat() async {
    final trip = _trip;

    if (trip == null || !trip.isGroup) {
      return;
    }

    final conversationId = trip.conversationId;

    if (conversationId == null || conversationId.trim().isEmpty) {
      _showMessage('Nhóm chưa có đoạn chat được liên kết.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessageChatScreen(
          conversationId: conversationId,
          repository: _messageRepository,
        ),
      ),
    );
  }

  Future<void> _syncTripMemberPreview(TripUi? trip) async {
    // Chỉ Map của lịch trình nhóm mới hiển thị vị trí thành viên.
    if (trip == null || !trip.isGroup) {
      await _layers.hidePreviewMembers();
      return;
    }

    final snapshot = TripLocationRealtimeService.instance.snapshot;
    final members = snapshot.tripId == trip.id
        ? snapshot.members
        : const <GoMateMapMember>[];

    if (members.isEmpty) {
      await _layers.hidePreviewMembers();
      return;
    }

    await _layers.showPreviewMembers(
      members,
      currentUserId: _messageRepository.currentUserId,
    );
  }

  Future<void> _renderExplorePlaces({bool forceTripRouteRedraw = false}) async {
    await _layers.showExplorePlaces(_state.places);

    if (_trip != null) {
      await _syncDisplayedTripRoute(
        fitCamera: false,
        forceRedraw: forceTripRouteRedraw,
      );
    }
  }

  Future<void> _syncDisplayedTripRoute({
    bool fitCamera = false,
    bool forceRedraw = false,
  }) async {
    if (_tripRouteSyncRunning) {
      _tripRouteSyncQueued = true;
      _tripRouteQueuedFitCamera = _tripRouteQueuedFitCamera || fitCamera;
      _tripRouteQueuedForceRedraw = _tripRouteQueuedForceRedraw || forceRedraw;
      return;
    }

    _tripRouteSyncRunning = true;

    try {
      do {
        _tripRouteSyncQueued = false;
        await _syncDisplayedTripRouteOnce(
          fitCamera: fitCamera,
          forceRedraw: forceRedraw,
        );
        fitCamera = _tripRouteQueuedFitCamera;
        forceRedraw = _tripRouteQueuedForceRedraw;
        _tripRouteQueuedFitCamera = false;
        _tripRouteQueuedForceRedraw = false;
      } while (_tripRouteSyncQueued && mounted);
    } finally {
      _tripRouteSyncRunning = false;
    }
  }

  Future<void> _syncDisplayedTripRouteOnce({
    required bool fitCamera,
    required bool forceRedraw,
  }) async {
    final map = _map;
    var trip = _trip;

    if (map == null) {
      return;
    }

    if (trip == null) {
      _state.route = null;
      _lastTripRouteSignature = null;
      _lastTripRouteErrorSignature = null;
      await _layers.clearRouteLayers();
      return;
    }

    if (_needsTripDetailForRoute(trip)) {
      final tripId = trip.id;
      final wasActive = trip.isActive;
      if (_tripRouteDetailLoadingIds.add(tripId)) {
        try {
          final detailed = await _tripRepository.detail(tripId);

          if (!mounted || _trip?.id != tripId) {
            return;
          }

          trip = detailed.copyWith(isActive: wasActive);
          GoMateMapUiSession.updateTrip(trip);
          GoMateMapUiSession.selectTrip(trip, day: _selectedDay);
        } catch (error) {
          _state.route = null;
          _lastTripRouteSignature = null;
          await _layers.clearRouteLayers();

          final signature = '$tripId|detail-load';
          if (_lastTripRouteErrorSignature != signature) {
            _lastTripRouteErrorSignature = signature;
            _showMessage('Không tải được chi tiết lịch trình để vẽ đường đi.');
          }
          return;
        } finally {
          _tripRouteDetailLoadingIds.remove(tripId);
        }
      }
    }

    final day = _selectedDay.clamp(1, trip.days).toInt();
    final stops = _routePlacesFor(trip, day);

    if (stops.isEmpty) {
      _state.route = null;
      _lastTripRouteSignature = null;
      _lastTripRouteErrorSignature = null;
      await _layers.clearRouteLayers();
      return;
    }

    final signature = _tripRouteSignature(trip, day);
    final shouldFitCamera = fitCamera || _lastTripRouteSignature != signature;
    if (signature == _lastTripRouteSignature && _state.route != null) {
      if (forceRedraw) {
        await _layers.renderTripRouteLine(
          route: _state.route!,
          fitCamera: fitCamera,
        );
      }
      return;
    }

    final location = await _locationService.getCurrentLocation();

    final currentTrip = _trip;
    if (!mounted ||
        currentTrip == null ||
        _tripRouteSignature(currentTrip, _selectedDay) != signature) {
      return;
    }

    if (location.state != GoMateLocationState.ready ||
        location.position == null) {
      _state.route = null;
      _lastTripRouteSignature = null;
      await _layers.clearRouteLayers();

      if (_lastTripRouteErrorSignature != signature) {
        _lastTripRouteErrorSignature = signature;
        _showMessage(_routeLocationMessage(location.state));
      }
      return;
    }

    try {
      final current = location.position!;
      final route = await _state.gateway.loadTripRouteFromCurrentLocation(
        originLatitude: current.latitude,
        originLongitude: current.longitude,
        placeIds: stops.map((place) => place.placeId.trim()).toList(),
      );

      if (!mounted ||
          _trip == null ||
          _tripRouteSignature(_trip!, _selectedDay) != signature) {
        return;
      }

      _state.route = route;
      _lastTripRouteSignature = signature;
      _lastTripRouteErrorSignature = null;

      await _layers.renderTripRouteLine(
        route: route,
        fitCamera: shouldFitCamera,
      );
    } catch (error) {
      _state.route = null;
      _lastTripRouteSignature = null;
      await _layers.clearRouteLayers();

      if (_lastTripRouteErrorSignature != signature) {
        _lastTripRouteErrorSignature = signature;
        _showMessage('Không tải được đường đi lịch trình: $error');
      }
    }
  }

  String _routeLocationMessage(GoMateLocationState state) {
    return switch (state) {
      GoMateLocationState.serviceOff =>
        'GPS đang tắt nên chưa vẽ được đường đi lịch trình.',
      GoMateLocationState.permissionDenied =>
        'GoMate cần quyền vị trí để vẽ đường đi lịch trình.',
      GoMateLocationState.permissionDeniedForever =>
        'Quyền vị trí đã bị chặn. Hãy bật lại trong Settings để vẽ đường đi.',
      GoMateLocationState.whileInUseOnly =>
        'GoMate đang có quyền vị trí khi dùng app.',
      GoMateLocationState.ready => 'Không lấy được vị trí hiện tại.',
    };
  }

  Future<void> _startAddSelectedPlace() async {
    final place = _state.selectedPlace;

    if (place == null) {
      return;
    }

    TripUi? target = _trip;

    // Case 1:
    // chưa chọn lịch trình.
    if (target == null) {
      target = await _pickTrip();

      if (!mounted || target == null) {
        return;
      }

      GoMateMapUiSession.selectTrip(target);
    }

    // Case 4:
    // Thành viên theo quyền hiện tại chỉ xem, không thêm/xoá/sửa.
    if (!target.canEditTrip) {
      _showMessage('Bạn chỉ có quyền xem lộ trình này.');
      return;
    }

    final skipDayStep = _tripHeaderExpanded;

    await _beginAddFlow(place: place, trip: target, startAtTime: skipDayStep);
  }

  Future<void> _beginAddFlow({
    required GoMateMapPlace place,
    required TripUi trip,
    bool startAtTime = false,
  }) async {
    if (_openingStop || _savingStop) return;
    _openingStop = true;
    final serial = ++_flowSerial;
    try {
      final clock = await _tripRepository.planningContext(trip.timezone);
      if (!mounted || serial != _flowSerial) return;
      _flowClock = clock;
    } catch (error) {
      if (mounted) _showMessage(error.toString());
      return;
    } finally {
      _openingStop = false;
    }
    if (!mounted || serial != _flowSerial) return;
    final day = _selectedDay.clamp(1, trip.days).toInt();

    setState(() {
      _pendingAddPlace = place;
      _pendingAddTrip = trip;
      _editingStopId = null;
      _initialStartTime = null;
      _initialEndTime = null;
      _flowError = null;

      _flowDay = day;
      _flowStartTime = null;
      _flowEndTime = null;

      _addStep = startAtTime
          ? GoMateMapAddPlaceStep.startTime
          : GoMateMapAddPlaceStep.day;
    });

    GoMateMapUiSession.setMapBottomNavHidden(true);
  }

  Future<void> _editDayPlaceTime(int dayIndex) async {
    if (_openingStop || _savingStop) return;
    final trip = _trip;

    if (trip == null || !trip.canEditTrip) {
      return;
    }

    final indexes = _globalIndexesForDay(trip, _selectedDay);

    if (dayIndex < 0 || dayIndex >= indexes.length) {
      return;
    }

    final globalIndex = indexes[dayIndex];

    final stopId = trip.places[globalIndex].id;
    if (stopId.isEmpty || stopId.startsWith('summary-stop-')) {
      _showMessage('Đang tải chi tiết địa điểm. Hãy thử lại sau khi tải xong.');
      return;
    }
    _openingStop = true;
    final serial = ++_flowSerial;
    late TripUi fresh;
    late TripPlanningContext clock;
    try {
      fresh = await _tripRepository.detail(trip.id);
      clock = await _tripRepository.planningContext(fresh.timezone);
    } catch (error) {
      if (mounted) _showMessage(error.toString());
      return;
    } finally {
      _openingStop = false;
    }
    if (!mounted || serial != _flowSerial || _trip?.id != trip.id) return;
    final matches = fresh.places.where((stop) => stop.id == stopId);
    if (!fresh.canEditTrip || matches.isEmpty) {
      _showMessage('Địa điểm không còn khả dụng hoặc bạn không có quyền sửa.');
      return;
    }
    final place = matches.single;
    GoMateMapUiSession.updateTrip(fresh);

    setState(() {
      _pendingAddPlace = null;
      _pendingAddTrip = fresh;
      _editingStopId = stopId;
      _flowClock = clock;
      _flowError = null;

      _flowDay = place.day;
      _flowStartTime = place.startTime.trim().isEmpty ? null : place.startTime;

      _flowEndTime = place.endTime.trim().isEmpty ? null : place.endTime;
      _initialStartTime = _flowStartTime;
      _initialEndTime = _flowEndTime;

      _addStep = GoMateMapAddPlaceStep.startTime;
    });

    GoMateMapUiSession.setMapBottomNavHidden(true);
  }

  void _onAddFlowContinue() {
    if (_savingStop) return;
    final step = _addStep;

    if (step == null) {
      return;
    }

    switch (step) {
      case GoMateMapAddPlaceStep.day:
        setState(() {
          _addStep = GoMateMapAddPlaceStep.startTime;
        });
        break;

      case GoMateMapAddPlaceStep.startTime:
        if (!_validateTimes(includeEnd: false)) return;
        setState(() {
          _addStep = GoMateMapAddPlaceStep.endTime;
        });
        break;

      case GoMateMapAddPlaceStep.endTime:
        if (!_validateTimes()) {
          return;
        }

        _finishAddFlow();
        break;
    }
  }

  void _onAddFlowSkip() {
    if (_savingStop) return;
    final step = _addStep;

    if (step == GoMateMapAddPlaceStep.startTime) {
      setState(() {
        _flowStartTime = null;

        _addStep = GoMateMapAddPlaceStep.endTime;
      });

      return;
    }

    if (step == GoMateMapAddPlaceStep.endTime) {
      setState(() {
        _flowEndTime = null;
      });

      _finishAddFlow();
    }
  }

  bool get _timeChanged =>
      _editingStopId == null ||
      _flowStartTime != _initialStartTime ||
      _flowEndTime != _initialEndTime;

  DateTime? get _stopWallDate {
    final date = _pendingAddTrip?.startDate;
    if (date == null) return null;
    return DateTime.utc(date.year, date.month, date.day + _flowDay - 1);
  }

  String? _startTimeError(String? value) {
    final day = _stopWallDate;
    final now = _flowClock?.now;
    if (value == null || day == null || now == null) return null;
    final today = DateTime.utc(now.year, now.month, now.day);
    if (day.isBefore(today)) {
      return 'Ngày địa điểm đã qua. Hãy sửa ngày lịch trình trước khi đặt giờ mới.';
    }
    final minutes = _timeToMinutes(value);
    if (minutes == null) return 'Giờ địa điểm không hợp lệ.';
    if (!day.add(Duration(minutes: minutes)).isAfter(now)) {
      return 'Giờ bắt đầu phải ở tương lai tại thời điểm lưu.';
    }
    return null;
  }

  bool _validateTimes({bool includeEnd = true}) {
    if (!_timeChanged) return true;
    final start = _flowStartTime;

    final end = _flowEndTime;

    final error = _startTimeError(start);
    if (error != null) {
      setState(() {
        _flowError = error;
        _addStep = GoMateMapAddPlaceStep.startTime;
      });
      return false;
    }
    if (!includeEnd || start == null || end == null) {
      return true;
    }

    final startMinutes = _timeToMinutes(start);

    final endMinutes = _timeToMinutes(end);

    if (startMinutes == null || endMinutes == null) {
      return true;
    }

    if (endMinutes <= startMinutes) {
      setState(
        () => _flowError = 'Giờ kết thúc phải sau giờ bắt đầu trong cùng ngày.',
      );
      return false;
    }

    return true;
  }

  int? _timeToMinutes(String value) {
    final parts = value.split(':');

    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);

    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return null;
    }

    return hour * 60 + minute;
  }

  String _tripPlaceIdentity(TripPlaceUi place) {
    final id = place.placeId.trim().isNotEmpty
        ? place.placeId.trim()
        : place.id.trim();

    if (id.isNotEmpty) {
      return 'id:$id';
    }

    return 'name:${place.name.trim().toLowerCase()}';
  }

  String _mapPlaceIdentity(GoMateMapPlace place) {
    final id = place.placeId.trim();

    if (id.isNotEmpty) {
      return 'id:$id';
    }

    return 'name:${place.name.trim().toLowerCase()}';
  }

  bool _hasAdjacentDuplicatePlaces(List<TripPlaceUi> places) {
    for (var i = 1; i < places.length; i++) {
      if (_tripPlaceIdentity(places[i - 1]) == _tripPlaceIdentity(places[i])) {
        return true;
      }
    }

    return false;
  }

  Future<void> _finishAddFlow() async {
    if (_savingStop || !_validateTimes()) return;
    final trip = _pendingAddTrip;

    if (trip == null) {
      _closeAddFlow();
      return;
    }

    final all = List<TripPlaceUi>.from(trip.places);

    final editingId = _editingStopId;
    final serial = _flowSerial;
    if (editingId != null) {
      final matches = all.where((stop) => stop.id == editingId);
      if (matches.isEmpty) return;
      final edited = matches.single;

      if (edited.id.trim().isEmpty || edited.id.startsWith('summary-stop-')) {
        _showMessage(
          'Địa điểm này chưa đồng bộ với máy chủ. Hãy mở lại lịch trình rồi thử lại.',
        );
        _closeAddFlow();
        return;
      }

      setState(() {
        _savingStop = true;
        _flowError = null;
      });
      try {
        final updated = await _tripRepository.updateStop(
          trip.id,
          edited.id,
          dayNo: _flowDay,
          tripStartDate: trip.startDate,
          startTime: _timeChanged ? _flowStartTime : null,
          endTime: _timeChanged ? _flowEndTime : null,
          clearTime: _timeChanged && _flowStartTime == null,
        );
        if (!mounted || serial != _flowSerial) return;
        _applyUpdatedTrip(updated, day: _flowDay, expand: true);
        _closeAddFlow();
        await _clearSelectedPlace();
      } catch (error) {
        if (mounted && serial == _flowSerial) {
          _stopSaveFailed(error);
        }
      } finally {
        if (mounted) setState(() => _savingStop = false);
      }
      return;
    } else {
      final place = _pendingAddPlace;

      if (place == null) {
        _closeAddFlow();
        return;
      }

      // Một địa điểm được phép xuất hiện nhiều lần trong cùng ngày,
      // nhưng KHÔNG được đứng liền nhau. Muốn A xuất hiện lần 2 phải có
      // ít nhất một địa điểm khác ở giữa: A -> B -> A.
      final sameDayPlaces = all
          .where((item) => item.day == _flowDay)
          .toList(growable: false);

      if (sameDayPlaces.isNotEmpty &&
          _tripPlaceIdentity(sameDayPlaces.last) == _mapPlaceIdentity(place)) {
        setState(
          () => _flowError =
              'Không thể thêm cùng một địa điểm liên tiếp. Hãy thêm một địa điểm khác ở giữa.',
        );
        return;
      }

      setState(() {
        _savingStop = true;
        _flowError = null;
      });
      try {
        final updated = await _tripRepository.addStop(
          trip.id,
          placeId: place.placeId,
          dayNo: _flowDay,
          tripStartDate: trip.startDate,
          startTime: _flowStartTime,
          endTime: _flowEndTime,
        );
        if (!mounted || serial != _flowSerial) return;
        _applyUpdatedTrip(updated, day: _flowDay, expand: true);
        _closeAddFlow();
        await _clearSelectedPlace();
      } catch (error) {
        if (mounted && serial == _flowSerial) {
          _stopSaveFailed(error);
        }
      } finally {
        if (mounted) setState(() => _savingStop = false);
      }
      return;
    }
  }

  void _stopSaveFailed(Object error) {
    setState(() {
      _flowError = error.toString();
      if (_timeChanged && _startTimeError(_flowStartTime) != null) {
        _addStep = GoMateMapAddPlaceStep.startTime;
      }
    });
  }

  void _closeAddFlow() {
    if (!mounted) return;

    setState(() {
      _flowSerial++;
      _addStep = null;
      _pendingAddPlace = null;
      _pendingAddTrip = null;
      _editingStopId = null;
      _flowError = null;
      _initialStartTime = null;
      _initialEndTime = null;
      _flowClock = null;

      _flowStartTime = null;
      _flowEndTime = null;
    });

    GoMateMapUiSession.setMapBottomNavHidden(false);
  }

  List<int> _globalIndexesForDay(TripUi trip, int day) {
    final indexes = <int>[];

    for (var i = 0; i < trip.places.length; i++) {
      if (trip.places[i].day == day) {
        indexes.add(i);
      }
    }

    return indexes;
  }

  Future<void> _removeDayPlace(int dayIndex) async {
    final trip = _trip;

    if (trip == null || !trip.canEditTrip) {
      return;
    }

    final indexes = _globalIndexesForDay(trip, _selectedDay);

    if (dayIndex < 0 || dayIndex >= indexes.length) {
      return;
    }

    final dayPlaces = trip.places
        .where((item) => item.day == _selectedDay)
        .toList();

    if (dayIndex >= 0 && dayIndex < dayPlaces.length) {
      dayPlaces.removeAt(dayIndex);

      if (_hasAdjacentDuplicatePlaces(dayPlaces)) {
        _showMessage(
          'Không thể xoá điểm ở giữa vì sẽ làm hai địa điểm giống nhau đứng liền nhau.',
        );
        return;
      }
    }

    final all = List<TripPlaceUi>.from(trip.places);

    final removed = all[indexes[dayIndex]];
    if (removed.id.trim().isEmpty || removed.id.startsWith('summary-stop-')) {
      _showMessage(
        'Địa điểm này chưa đồng bộ với máy chủ. Hãy mở lại lịch trình rồi thử lại.',
      );
      return;
    }

    all.removeAt(indexes[dayIndex]);

    try {
      final updated = await _tripRepository.deleteStop(trip.id, removed.id);
      _applyUpdatedTrip(updated, day: _selectedDay, expand: true);
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _reorderDayPlaces(int oldIndex, int newIndex) async {
    final trip = _trip;

    if (trip == null || !trip.canEditTrip) {
      return;
    }

    final dayPlaces = trip.places
        .where((item) => item.day == _selectedDay)
        .toList();

    if (oldIndex < 0 || oldIndex >= dayPlaces.length) {
      return;
    }

    var target = newIndex;

    if (target > oldIndex) {
      target--;
    }

    final moved = dayPlaces.removeAt(oldIndex);

    dayPlaces.insert(target.clamp(0, dayPlaces.length).toInt(), moved);

    if (_hasAdjacentDuplicatePlaces(dayPlaces)) {
      _showMessage(
        'Không thể sắp xếp để hai địa điểm giống nhau đứng liền nhau.',
      );
      return;
    }

    var cursor = 0;

    final rebuilt = trip.places.map((item) {
      if (item.day != _selectedDay) {
        return item;
      }

      final replacement = dayPlaces[cursor];

      cursor++;

      return replacement;
    }).toList();

    final updated = trip.copyWith(
      places: List<TripPlaceUi>.unmodifiable(rebuilt),
    );

    if (updated.places.any(
      (place) =>
          place.id.trim().isEmpty || place.id.startsWith('summary-stop-'),
    )) {
      _showMessage(
        'Danh sách địa điểm chưa đồng bộ với máy chủ. Hãy mở lại lịch trình rồi thử lại.',
      );
      return;
    }

    try {
      final persisted = await _tripRepository.reorderStops(
        updated.id,
        updated.places,
      );
      _applyUpdatedTrip(persisted, day: _selectedDay, expand: true);
    } catch (error) {
      _showMessage(error.toString());
    }

    // Backend note:
    // sau khi reorder phải tính lại/swap thời gian hợp lý.
    // UI không tự đoán travel time ở đây.
  }

  void _applyUpdatedTrip(
    TripUi updated, {
    required int day,
    required bool expand,
  }) {
    final previous = _trip;
    final next = updated.copyWith(
      isActive: previous?.isActive ?? updated.isActive,
    );
    GoMateMapUiSession.updateTrip(next);
    GoMateMapUiSession.selectTrip(next, day: day);
    _selectedDay = day.clamp(1, next.days).toInt();
    setState(() {
      _tripHeaderExpanded = expand;
    });
    unawaited(_syncTripMemberPreview(next));
    unawaited(_syncDisplayedTripRoute(fitCamera: true));
  }

  Future<void> _requestOptimizeRoute() async {
    final trip = _trip;

    if (trip == null || !trip.canEditTrip) {
      return;
    }

    try {
      final updated = await _tripRepository.optimizeStops(
        trip.id,
        dayNo: _selectedDay,
      );
      _applyUpdatedTrip(updated, day: _selectedDay, expand: true);
      _showMessage('Đã tối ưu thứ tự điểm trong ngày $_selectedDay.');
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _consumeSessionRequests() async {
    if (_processingSessionRequest || !mounted) {
      return;
    }

    _processingSessionRequest = true;

    try {
      final launch = GoMateMapUiSession.consumeLaunchRequest();

      if (launch != null) {
        _selectedDay = launch.day.clamp(1, launch.trip.days).toInt();

        setState(() {
          _tripHeaderExpanded = launch.expandDayRoute;
        });

        await _syncTripMemberPreview(launch.trip);
        await _syncDisplayedTripRoute(fitCamera: true);
      }

      final add = GoMateMapUiSession.consumeAddPlaceRequest();

      if (add != null) {
        GoMateMapUiSession.selectTrip(add.trip);

        await _state.selectPlace(add.placeId);

        final loaded = _state.selectedPlace;

        if (loaded != null) {
          await _layers.renderSelected(loaded);

          await _layers.focusPlace(loaded);

          _beginAddFlow(place: loaded, trip: add.trip, startAtTime: false);
          await _syncDisplayedTripRoute();
        }
      }
    } finally {
      _processingSessionRequest = false;
    }
  }

  Future<void> _openSelectedPlaceDetail() async {
    var selected = _state.selectedPlace;

    if (selected == null) {
      return;
    }

    if (selected.description == null && selected.mediaUrls.length <= 1) {
      await _state.enrichSelectedPlace(selected.placeId);
      selected = _state.selectedPlace ?? selected;
    }

    if (!mounted) {
      return;
    }

    final placeForDetail = selected;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceDetailScreen(place: _toUiPlace(placeForDetail)),
      ),
    );

    if (!mounted || _state.query.trim().isEmpty) {
      return;
    }

    await _state.setQuery('');

    await _renderExplorePlaces(forceTripRouteRedraw: true);

    final current = _state.selectedPlace;

    if (current != null) {
      await _layers.renderSelected(current);
      _requestSelectedPlaceScreenPointUpdate();
    }
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

  void _onMapTap(MapContentGestureContext gesture) {
    unawaited(_handleMapTap(gesture));
  }

  Future<void> _handleMapTap(MapContentGestureContext gesture) async {
    if (_addFlowActive) {
      return;
    }

    if (_state.selectedPlace != null) {
      await _clearSelectedPlace();
      return;
    }

    final lng = gesture.point.coordinates.lng.toDouble();

    final lat = gesture.point.coordinates.lat.toDouble();

    setState(() {
      _coordinateText =
          '${lat.toStringAsFixed(5)}, '
          '${lng.toStringAsFixed(5)}';
    });

    _coordinateTextTimer?.cancel();
    _coordinateTextTimer = Timer(const Duration(seconds: 3), () {
      _coordinateTextTimer = null;

      if (mounted) {
        setState(() {
          _coordinateText = null;
        });
      }
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    GoMateSnackBar.show(
      context,
      message: message,
      bottomOffset: GoMateMapUiSession.hideMapBottomNav ? 24 : 90,
      icon: LucideIcons.circle_alert,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    final width = media.size.width;

    final top = media.padding.top;

    final bottom = widget.bottomNavigationInset;

    final trip = _trip;

    final selectedPlace = _state.selectedPlace;

    // Cụm nút phải có vị trí cố định, KHÔNG phụ thuộc việc header ngày
    // đang mở hay đóng. GoMateMapControls đã tự giữ slot riêng cho compass,
    // nên chỉ cần đặt top của toàn cụm đủ thấp để compass không đè header.
    final controlsTop = top + (width * 0.34).clamp(122.0, 140.0).toDouble();

    final content = Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
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
                onCameraChangeListener: _onCameraChanged,
                onMapIdleListener: _onMapIdle,
                onTapListener: _onMapTap,
              ),
            ),
          ),

          if (trip != null)
            Positioned(
              top: top + 12,
              left: 0,
              right: 0,
              child: Center(
                child: GoMateMapTripHeader(
                  trip: trip,
                  selectedDay: _selectedDay,
                  placeCount: _dayPlaces.length,
                  expanded: _tripHeaderExpanded,
                  onToggleExpanded: _toggleTripExpanded,
                  onEdit: trip.canEditTrip
                      ? () {
                          unawaited(_openTripDetail());
                        }
                      : null,
                  onPreviousDay: () => _changeDay(-1),
                  onNextDay: () => _changeDay(1),
                  onDaySwipe: _changeDay,
                ),
              ),
            ),

          Positioned(
            top: controlsTop,
            right: (width * 0.055).clamp(18.0, 23.0).toDouble(),
            child: ValueListenableBuilder<_MapCameraChromeState>(
              valueListenable: _cameraChrome,
              builder: (context, camera, _) {
                return GoMateMapControls(
                  onSearch: _openPlaceSearch,
                  onTripPicker: _openTripPicker,
                  onLocation: _moveToCurrentLocation,
                  showCompass: camera.showCompass,
                  bearing: camera.bearing,
                  onCompass: _resetNorth,
                  onChat: trip?.hasChat == true
                      ? () {
                          unawaited(_openGroupChat());
                        }
                      : null,
                  pinButton: trip == null
                      ? null
                      : GoMateMapTripPinButton(
                          trip: trip,
                          tripRepository: _tripRepository,
                          locationService: _locationService,
                          bottomInset: GoMateMapUiSession.hideMapBottomNav
                              ? 24
                              : 90,
                        ),
                );
              },
            ),
          ),

          if (_state.loading)
            Positioned(
              top: top + (width * 0.26).clamp(92.0, 110.0).toDouble(),
              left: 0,
              right: 0,
              child: const IgnorePointer(
                child: Center(
                  child: GoMateMapStatusPill(
                    text: 'Đang tải dữ liệu...',
                    icon: LucideIcons.refresh_cw,
                  ),
                ),
              ),
            ),

          if (_coordinateText != null)
            Positioned(
              top: top + (width * 0.26).clamp(92.0, 110.0).toDouble(),
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: GoMateMapStatusPill(
                    text: _coordinateText!,
                    icon: LucideIcons.map_pin,
                  ),
                ),
              ),
            ),

          // Card địa điểm được neo trực tiếp vào geographic marker.
          // Pan / rotate / zoom -> pixelForCoordinate cập nhật -> card đi theo icon.
          if (selectedPlace != null)
            ValueListenableBuilder<_SelectedPlaceOverlayState>(
              valueListenable: _selectedPlaceOverlay,
              builder: (context, overlay, _) {
                final selectedPoint = overlay.point;
                if (selectedPoint == null) {
                  return const SizedBox.shrink();
                }

                final placeCardWidth = GoMateMapPlaceCard.cardWidthFor(width);
                final placeCardTotalHeight = GoMateMapPlaceCard.totalHeightFor(
                  width,
                );
                const horizontalMargin = 8.0;

                final placeCardLeft = (selectedPoint.x - placeCardWidth / 2)
                    .clamp(
                      horizontalMargin,
                      width - placeCardWidth - horizontalMargin,
                    )
                    .toDouble();

                final placeCardPointerX = selectedPoint.x - placeCardLeft;

                // Mũi card chạm vào mép trên của selected circular marker.
                final markerRadius = _selectedMarkerRadiusForZoom(overlay.zoom);
                final markerTop = selectedPoint.y - markerRadius + 2;
                final placeCardTop = markerTop - placeCardTotalHeight;

                return Positioned(
                  left: placeCardLeft,
                  top: placeCardTop,
                  child: GoMateMapPlaceCard(
                    place: selectedPlace,
                    pointerCenterX: placeCardPointerX,
                    canAddToTrip: trip == null || trip.canEditTrip,
                    onClose: () {
                      unawaited(_clearSelectedPlace());
                    },
                    onToggleSaved: _state.toggleSavedSelected,
                    onOpenDetail: () {
                      unawaited(_openSelectedPlaceDetail());
                    },
                    onAddToTrip: () {
                      unawaited(_startAddSelectedPlace());
                    },
                  ),
                );
              },
            ),

          if (_tripHeaderExpanded && trip != null && !_addFlowActive)
            Positioned(
              top: top + 12 + GoMateMapTripHeader.expandedHeightFor(width) + 8,
              left: 0,
              right: 0,
              bottom: 0,
              child: GoMateMapDayRoutePanel(
                places: _dayPlaces,
                canEdit: trip.canEditTrip,
                bottomInset: bottom,
                onOptimize: () => unawaited(_requestOptimizeRoute()),
                onPlaceTap: _editDayPlaceTime,
                onRemove: trip.canEditTrip
                    ? (index) => unawaited(_removeDayPlace(index))
                    : null,
                onReorder: trip.canEditTrip
                    ? (oldIndex, newIndex) =>
                          unawaited(_reorderDayPlaces(oldIndex, newIndex))
                    : null,
              ),
            ),

          if (_addStep != null && _pendingAddTrip != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GoMateMapAddPlaceFlowPanel(
                key: ValueKey(
                  'map-add-${_addStep!}-${_editingStopId ?? 'new'}',
                ),
                trip: _pendingAddTrip!,
                step: _addStep!,
                selectedDay: _flowDay,
                errorText: _flowError,
                saving: _savingStop,
                timeAllowed: (value) {
                  if (_addStep == GoMateMapAddPlaceStep.startTime) {
                    return _startTimeError(value) == null;
                  }
                  if (_flowStartTime == null) return true;
                  return _startTimeError(_flowStartTime) == null &&
                      (_timeToMinutes(value) ?? -1) >
                          (_timeToMinutes(_flowStartTime!) ?? 0);
                },
                selectedTime: _addStep == GoMateMapAddPlaceStep.startTime
                    ? _flowStartTime
                    : _flowEndTime,
                onDayChanged: (value) {
                  setState(() {
                    _flowDay = value;
                    _flowError = null;
                  });
                },
                onTimeChanged: (value) {
                  setState(() {
                    _flowError = null;
                    if (_addStep == GoMateMapAddPlaceStep.startTime) {
                      _flowStartTime = value;
                    } else if (_addStep == GoMateMapAddPlaceStep.endTime) {
                      _flowEndTime = value;
                    }
                    _flowError = _startTimeError(_flowStartTime);
                    if (_flowError == null &&
                        _flowStartTime != null &&
                        _flowEndTime != null &&
                        _timeToMinutes(_flowEndTime!)! <=
                            _timeToMinutes(_flowStartTime!)!) {
                      _flowError =
                          'Giờ kết thúc phải sau giờ bắt đầu trong cùng ngày.';
                    }
                  });
                },
                onContinue: _onAddFlowContinue,
                onSkip: _onAddFlowSkip,
                onClose: _closeAddFlow,
              ),
            ),
        ],
      ),
    );
    return GoMateMapStopFlowBackScope(
      active: _addFlowActive,
      visible: widget.active,
      onClose: _closeAddFlow,
      child: content,
    );
  }
}

class _MapCameraChromeState {
  final bool showCompass;
  final double bearing;

  const _MapCameraChromeState({this.showCompass = false, this.bearing = 0});
}

class _SelectedPlaceOverlayState {
  final ScreenCoordinate? point;
  final double zoom;

  const _SelectedPlaceOverlayState({this.point, this.zoom = 14.2});
}
