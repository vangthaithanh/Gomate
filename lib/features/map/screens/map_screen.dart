import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gomate_itinerary_picker.dart';
import '../../../core/widgets/snackbar.dart';
import '../../messages/data/message_repository.dart';
import '../../messages/screens/chat_screen.dart';
import '../../trip/models/trip_ui_models.dart';
import '../../trip/screens/trip_detail_screen.dart';
import '../data/spring_map_gateway.dart';
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
import 'map_place_search_screen.dart';
import 'place_detail_screen.dart';

class GoMateMapScreen extends StatefulWidget {
  final double bottomNavigationInset;

  const GoMateMapScreen({
    super.key,
    this.bottomNavigationInset = 0,
  });

  @override
  State<GoMateMapScreen> createState() =>
      _GoMateMapScreenState();
}

class _GoMateMapScreenState
    extends State<GoMateMapScreen> {
  final GoMateMapState _state =
      GoMateMapState(
    SpringGoMateMapGateway(),
  );

  final GoMateMapboxLayerController _layers =
      GoMateMapboxLayerController();

  final GoMateLocationService _locationService =
      GoMateLocationService();

  final MessageRepository _messageRepository =
      DemoMessageRepository.instance;

  final Position _defaultCenter =
      Position(
    108.4488,
    11.9416,
  );

  MapboxMap? _map;

  String? _coordinateText;

  double _bearing = 0;
  double _currentZoom = 14.2;

  // Flutter place-card được neo vào đúng geographic position của marker.
  ScreenCoordinate? _selectedPlaceScreenPoint;
  bool _selectedPlacePointUpdateRunning = false;
  bool _selectedPlacePointUpdateRequested = false;

  // Chỉ update pulse state sau khi current-user avatar thực sự được bật.
  bool _locationAvatarVisible = false;
  bool _lastAppliedTrackingActive = false;

  bool _tripHeaderExpanded = false;

  int _selectedDay = 1;

  GoMateMapAddPlaceStep? _addStep;
  GoMateMapPlace? _pendingAddPlace;
  TripUi? _pendingAddTrip;

  int? _editingTripPlaceGlobalIndex;

  int _flowDay = 1;
  String? _flowStartTime;
  String? _flowEndTime;

  bool _processingSessionRequest = false;

  TripUi? get _trip =>
      GoMateMapUiSession.displayedTrip;

  bool get _showCompass {
    final value =
        ((_bearing % 360) + 360) % 360;

    return value > 1.0 &&
        value < 359.0;
  }

  bool get _addFlowActive =>
      _addStep != null;

  List<TripPlaceUi> get _dayPlaces {
    final trip = _trip;
    if (trip == null) {
      return const <TripPlaceUi>[];
    }

    return trip.places
        .where(
          (place) =>
              place.day == _selectedDay,
        )
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();

    _selectedDay =
        GoMateMapUiSession.selectedDay;

    _state.addListener(
      _onMapStateChanged,
    );

    GoMateMapUiSession.revision.addListener(
      _onMapUiSessionChanged,
    );

    unawaited(
      _loadInitialPlaces(),
    );

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        unawaited(
          _consumeSessionRequests(),
        );
      },
    );
  }

  @override
  void dispose() {
    _state.removeListener(
      _onMapStateChanged,
    );

    GoMateMapUiSession.revision
        .removeListener(
      _onMapUiSessionChanged,
    );

    if (GoMateMapUiSession
        .hideMapBottomNav) {
      GoMateMapUiSession
          .setMapBottomNavHidden(false);
    }

    _state.dispose();
    _layers.dispose();

    super.dispose();
  }

  void _onMapStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onMapUiSessionChanged() {
    if (!mounted) return;

    final sessionDay =
        GoMateMapUiSession.selectedDay;

    final trip = _trip;

    if (trip != null) {
      _selectedDay =
          sessionDay
              .clamp(1, trip.days)
              .toInt();
    }

    setState(() {});

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        unawaited(
          _consumeSessionRequests(),
        );
        unawaited(
          _syncSessionDependentMapVisuals(),
        );
      },
    );
  }

  Future<void> _syncSessionDependentMapVisuals() async {
    await _syncTripMemberPreview(_trip);

    if (!_locationAvatarVisible) {
      return;
    }

    final trackingActive =
        GoMateMapUiSession.hasPinnedTrip;

    if (trackingActive == _lastAppliedTrackingActive) {
      return;
    }

    _lastAppliedTrackingActive = trackingActive;

    await _layers.setRouteTrackingActive(
      trackingActive,
    );
  }

  Future<void> _loadInitialPlaces() async {
    await _state.init();

    if (_map != null) {
      await _layers.showExplorePlaces(
        _state.places,
      );
    }

    await _syncTripMemberPreview(
      _trip,
    );

    await _consumeSessionRequests();
  }

  Future<void> _onMapCreated(
    MapboxMap map,
  ) async {
    _map = map;

    // Tắt compass native của Mapbox.
    // Ta render compass vào đúng dãy nút tròn bên phải.
    await map.compass.updateSettings(
      CompassSettings(
        enabled: false,
      ),
    );

    await _layers.attach(
      map,
      onPlaceTap: (placeId) {
        unawaited(
          _selectPlace(placeId),
        );
      },
    );

    await _layers.showExplorePlaces(
      _state.places,
    );

    await _syncTripMemberPreview(
      _trip,
    );
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
    await map.style.setStyleImportConfigProperties(
      'basemap',
      <String, Object>{
        'showPointOfInterestLabels': false,
        'showPlaceLabels': false,
        'showTransitLabels': false,

        // Vẫn giữ tên đường để người dùng định hướng.
        'showRoadLabels': true,
      },
    );

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
    await _layers.showExplorePlaces(
      _state.places,
    );
  }

  void _onCameraChanged(
    CameraChangedEventData event,
  ) {
    final camera = event.cameraState;

    unawaited(
      _layers.updateExploreZoom(
        camera.zoom,
      ),
    );

    final nextBearing = camera.bearing;
    final nextZoom = camera.zoom;

    final bearingChanged =
        (_bearing - nextBearing).abs() > 0.5;
    final zoomChanged =
        (_currentZoom - nextZoom).abs() > 0.02;

    if (bearingChanged || zoomChanged) {
      setState(() {
        if (bearingChanged) {
          _bearing = nextBearing;
        }

        if (zoomChanged) {
          _currentZoom = nextZoom;
        }
      });
    }

    // Card địa điểm phải đi theo marker khi pan / rotate / zoom.
    _requestSelectedPlaceScreenPointUpdate();
  }

  void _requestSelectedPlaceScreenPointUpdate() {
    if (_map == null || _state.selectedPlace == null) {
      return;
    }

    _selectedPlacePointUpdateRequested = true;

    if (_selectedPlacePointUpdateRunning) {
      return;
    }

    unawaited(
      _drainSelectedPlaceScreenPointUpdates(),
    );
  }

  Future<void> _drainSelectedPlaceScreenPointUpdates() async {
    _selectedPlacePointUpdateRunning = true;

    try {
      while (_selectedPlacePointUpdateRequested && mounted) {
        _selectedPlacePointUpdateRequested = false;
        await _updateSelectedPlaceScreenPoint();
      }
    } finally {
      _selectedPlacePointUpdateRunning = false;
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

    if (!mounted ||
        _state.selectedPlace?.placeId != selectedId) {
      return;
    }

    final previous = _selectedPlaceScreenPoint;

    if (previous != null &&
        (previous.x - point.x).abs() < 0.35 &&
        (previous.y - point.y).abs() < 0.35) {
      return;
    }

    setState(() {
      _selectedPlaceScreenPoint = point;
    });
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

    final rawT =
        (zoom - startZoom) /
            (fullZoom - startZoom);

    final t = Curves.easeOutCubic.transform(rawT);
    final scale =
        minScale + ((maxScale - minScale) * t);

    return 37.0 * scale;
  }

  Future<void> _resetNorth() async {
    final map = _map;

    if (map == null) return;

    final camera =
        await map.getCameraState();

    await map.easeTo(
      CameraOptions(
        center: camera.center,
        zoom: camera.zoom,
        pitch: camera.pitch,
        bearing: 0,
      ),
      MapAnimationOptions(
        duration: 420,
      ),
    );
  }

  Future<void> _selectPlace(
    String placeId,
  ) async {
    if (_addFlowActive) {
      return;
    }

    await _state.selectPlace(
      placeId,
    );

    final place =
        _state.selectedPlace;

    if (place == null) {
      return;
    }

    GoMateMapUiSession.addRecent(
      place,
    );

    await _layers.renderSelected(
      place,
    );

    await _layers.focusPlace(
      place,
    );

    _requestSelectedPlaceScreenPointUpdate();
  }

  Future<void> _clearSelectedPlace() async {
    _state.clearSelection();

    if (mounted) {
      setState(() {
        _selectedPlaceScreenPoint = null;
      });
    }

    await _layers.renderSelected(
      null,
    );
  }

  Future<void> _moveToCurrentLocation() async {
    final result =
        await _locationService
            .getCurrentLocation();

    switch (result.state) {
      case GoMateLocationState.ready:
        final p = result.position!;

        final current =
            Position(
          p.longitude,
          p.latitude,
        );

        // V17:
        // avatar và custom pulse dùng cùng position.
        final trackingActive =
            GoMateMapUiSession.hasPinnedTrip;

        await _layers.enableLocationPuck(
          position: current,
          displayName: 'Bạn',
          routeActive: trackingActive,
        );

        _locationAvatarVisible = true;
        _lastAppliedTrackingActive = trackingActive;

        await _layers.focusCoordinate(
          current,
          zoom: 16.2,
        );

        break;

      case GoMateLocationState.serviceOff:
        _showMessage(
          'GPS đang tắt. Hãy bật Location rồi thử lại.',
        );
        break;

      case GoMateLocationState.permissionDenied:
        _showMessage(
          'GoMate cần quyền vị trí để hiển thị vị trí của bạn.',
        );
        break;

      case GoMateLocationState
            .permissionDeniedForever:
        _showMessage(
          'Quyền vị trí đã bị chặn. Hãy bật lại trong Settings.',
        );
        break;
    }
  }

  Future<void> _openPlaceSearch() async {
    final selected =
        await Navigator.of(context)
            .push<GoMateMapPlace>(
      MaterialPageRoute(
        builder: (_) =>
            MapPlaceSearchScreen(
          initialPlaces:
              _state.places,
          onSearch:
              _searchPlacesForScreen,
        ),
      ),
    );

    if (!mounted ||
        selected == null) {
      return;
    }

    await _selectPlace(
      selected.placeId,
    );
  }

  Future<List<GoMateMapPlace>>
      _searchPlacesForScreen(
    String query,
  ) async {
    await _state.setQuery(
      query,
    );

    await _layers.showExplorePlaces(
      _state.places,
    );

    return _state.places;
  }

  Future<TripUi?> _pickTrip() async {
    final trips =
        GoMateMapUiSession
            .availableTrips;

    final items =
        trips
            .map(
              (trip) =>
                  GoMateItineraryPickerItem(
                id: trip.id,
                title: trip.title,
                dateRange:
                    trip.dateRangeLabel,
                summary:
                    '${trip.days} ngày - ${trip.places.length} địa điểm',
                imageAsset:
                    trip.coverAsset,
                memberCount:
                    trip.isGroup
                        ? trip.memberCount
                        : 0,
              ),
            )
            .toList(
              growable: false,
            );

    final selected =
        await Navigator.of(context)
            .push<GoMateItineraryPickerItem>(
      MaterialPageRoute(
        builder: (
          pickerContext,
        ) {
          return GoMateItineraryPickerScreen(
            items: items,
            showCancel: true,
            searchHint:
                'Tìm kiếm lịch trình...',
            onCancel: () {
              Navigator.of(
                pickerContext,
              ).pop();
            },
            onQuickCreate: () {
              Navigator.of(
                pickerContext,
              ).pop();

              GoMateMapUiSession
                  .requestMainTab(3);
            },
            onSelected: (item) {
              Navigator.of(
                pickerContext,
              ).pop(item);
            },
          );
        },
      ),
    );

    if (!mounted ||
        selected == null) {
      return null;
    }

    for (final trip in trips) {
      if (trip.id == selected.id) {
        return trip;
      }
    }

    return null;
  }

  Future<void> _openTripPicker() async {
    final selected =
        await _pickTrip();

    if (!mounted ||
        selected == null) {
      return;
    }

    GoMateMapUiSession.selectTrip(
      selected,
      day: 1,
    );

    _selectedDay = 1;

    setState(() {
      _tripHeaderExpanded =
          false;
    });

    await _clearSelectedPlace();

    await _syncTripMemberPreview(
      selected,
    );
  }

  Future<void> _openTripDetail() async {
    final trip = _trip;

    if (trip == null) {
      return;
    }

    final result =
        await Navigator.of(context)
            .push<TripDetailResult>(
      MaterialPageRoute(
        builder: (_) =>
            TripDetailScreen(
          trip: trip,
          messageRepository:
              _messageRepository,
        ),
      ),
    );

    if (!mounted ||
        result == null) {
      return;
    }

    if (result.removeFromList) {
      GoMateMapUiSession.removeTrip(
        result.trip.id,
      );

      setState(() {
        _tripHeaderExpanded =
            false;
      });

      return;
    }

    GoMateMapUiSession.updateTrip(
      result.trip,
    );

    await _syncTripMemberPreview(
      result.trip,
    );
  }

  void _toggleTripExpanded() {
    final trip = _trip;
    if (trip == null) return;

    setState(() {
      _tripHeaderExpanded =
          !_tripHeaderExpanded;
    });

    if (!_tripHeaderExpanded) {
      return;
    }

    unawaited(
      _clearSelectedPlace(),
    );
  }

  void _changeDay(
    int delta,
  ) {
    final trip = _trip;

    if (trip == null) return;

    final next =
        (_selectedDay + delta)
            .clamp(
              1,
              trip.days,
            )
            .toInt();

    if (next == _selectedDay) {
      return;
    }

    setState(() {
      _selectedDay = next;
    });

    GoMateMapUiSession.selectDay(
      next,
    );
  }

  Future<void> _openGroupChat() async {
    final trip = _trip;

    if (trip == null ||
        !trip.isGroup) {
      return;
    }

    final conversationId =
        trip.conversationId;

    if (conversationId == null ||
        conversationId.trim().isEmpty) {
      _showMessage(
        'Nhóm chưa có đoạn chat được liên kết.',
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MessageChatScreen(
          conversationId:
              conversationId,
          repository:
              _messageRepository,
        ),
      ),
    );
  }

  Future<void> _syncTripMemberPreview(
    TripUi? trip,
  ) async {
    // Chỉ Map của lịch trình nhóm mới hiển thị vị trí thành viên.
    if (trip == null || !trip.isGroup) {
      await _layers.hidePreviewMembers();
      return;
    }

    final conversationId = trip.conversationId;
    final conversation = conversationId == null
        ? null
        : _messageRepository.conversation(conversationId);

    final currentUserId = _messageRepository.currentUserId;
    final seeds = <_MapMemberPreviewSeed>[];

    if (conversation != null) {
      // Conversation là nguồn tốt nhất cho UI demo vì chứa nickname hiện tại.
      // displayName đã tự ưu tiên nickname nếu user đã đặt biệt danh trong chat.
      for (final participant in conversation.participants) {
        if (participant.id == currentUserId || participant.id == 'me') {
          continue;
        }

        seeds.add(
          _MapMemberPreviewSeed(
            id: participant.id,
            displayName: participant.displayName,
            avatarAsset: participant.avatarAsset ?? '',
          ),
        );
      }
    } else {
      // Fallback cho group trip chưa có/không load được linked conversation.
      for (final member in trip.members) {
        if (member.id == currentUserId || member.id == 'me') {
          continue;
        }

        seeds.add(
          _MapMemberPreviewSeed(
            id: member.id,
            displayName: member.name,
            avatarAsset: member.avatarAsset,
          ),
        );
      }
    }

    final otherMembers = seeds.take(4).toList(growable: false);

    if (otherMembers.isEmpty) {
      await _layers.hidePreviewMembers();
      return;
    }

    final previews = <GoMateMapMember>[];

    for (var i = 0; i < otherMembers.length; i++) {
      final member = otherMembers[i];

      final avatarAsset = member.avatarAsset.trim().isNotEmpty
          ? member.avatarAsset
          : i.isEven
              ? 'assets/map/member_an.png'
              : 'assets/map/member_thu.png';

      // UI demo position only. Backend sau này trả realtime lat/lng thật.
      final lngOffset = 0.0020 + (i * 0.0014);
      final latOffset = 0.0014 + ((i % 2) * 0.0013);

      previews.add(
        GoMateMapMember(
          userId: member.id.isEmpty
              ? 'member-$i'
              : member.id,
          displayName: member.displayName,
          assetIcon: avatarAsset,
          position: Position(
            _defaultCenter.lng.toDouble() + lngOffset,
            _defaultCenter.lat.toDouble() + latOffset,
          ),
          updatedAt: DateTime.now(),
        ),
      );
    }

    await _layers.showPreviewMembers(
      previews,
      currentUserId:
          '__current_user_location_puck__',
    );
  }

  Future<void> _startAddSelectedPlace() async {
    final place =
        _state.selectedPlace;

    if (place == null) {
      return;
    }

    TripUi? target =
        _trip;

    // Case 1:
    // chưa chọn lịch trình.
    if (target == null) {
      target =
          await _pickTrip();

      if (!mounted ||
          target == null) {
        return;
      }

      GoMateMapUiSession.selectTrip(
        target,
      );
    }

    // Case 4:
    // member/deputy theo quyền hiện tại
    // chỉ xem, không thêm/xoá/sửa.
    if (!target.canEditTrip) {
      _showMessage(
        'Bạn chỉ có quyền xem lộ trình này.',
      );
      return;
    }

    final skipDayStep =
        _tripHeaderExpanded;

    _beginAddFlow(
      place: place,
      trip: target,
      startAtTime:
          skipDayStep,
    );
  }

  void _beginAddFlow({
    required GoMateMapPlace place,
    required TripUi trip,
    bool startAtTime = false,
  }) {
    final day =
        _selectedDay
            .clamp(
              1,
              trip.days,
            )
            .toInt();

    setState(() {
      _pendingAddPlace = place;
      _pendingAddTrip = trip;
      _editingTripPlaceGlobalIndex =
          null;

      _flowDay = day;
      _flowStartTime = null;
      _flowEndTime = null;

      _addStep = startAtTime
          ? GoMateMapAddPlaceStep
              .startTime
          : GoMateMapAddPlaceStep.day;
    });

    GoMateMapUiSession
        .setMapBottomNavHidden(true);
  }

  void _editDayPlaceTime(
    int dayIndex,
  ) {
    final trip = _trip;

    if (trip == null ||
        !trip.canEditTrip) {
      return;
    }

    final indexes =
        _globalIndexesForDay(
      trip,
      _selectedDay,
    );

    if (dayIndex < 0 ||
        dayIndex >= indexes.length) {
      return;
    }

    final globalIndex =
        indexes[dayIndex];

    final place =
        trip.places[globalIndex];

    setState(() {
      _pendingAddPlace = null;
      _pendingAddTrip = trip;
      _editingTripPlaceGlobalIndex =
          globalIndex;

      _flowDay = place.day;
      _flowStartTime =
          place.startTime
                  .trim()
                  .isEmpty
              ? null
              : place.startTime;

      _flowEndTime =
          place.endTime
                  .trim()
                  .isEmpty
              ? null
              : place.endTime;

      _addStep =
          GoMateMapAddPlaceStep
              .startTime;
    });

    GoMateMapUiSession
        .setMapBottomNavHidden(true);
  }

  void _onAddFlowContinue() {
    final step = _addStep;

    if (step == null) {
      return;
    }

    switch (step) {
      case GoMateMapAddPlaceStep.day:
        setState(() {
          _addStep =
              GoMateMapAddPlaceStep
                  .startTime;
        });
        break;

      case GoMateMapAddPlaceStep
            .startTime:
        setState(() {
          _addStep =
              GoMateMapAddPlaceStep
                  .endTime;
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
    final step = _addStep;

    if (step ==
        GoMateMapAddPlaceStep
            .startTime) {
      setState(() {
        _flowStartTime = null;

        _addStep =
            GoMateMapAddPlaceStep
                .endTime;
      });

      return;
    }

    if (step ==
        GoMateMapAddPlaceStep
            .endTime) {
      setState(() {
        _flowEndTime = null;
      });

      _finishAddFlow();
    }
  }

  bool _validateTimes() {
    final start =
        _flowStartTime;

    final end =
        _flowEndTime;

    if (start == null ||
        end == null) {
      return true;
    }

    final startMinutes =
        _timeToMinutes(start);

    final endMinutes =
        _timeToMinutes(end);

    if (startMinutes == null ||
        endMinutes == null) {
      return true;
    }

    if (endMinutes <=
        startMinutes) {
      _showMessage(
        'Giờ kết thúc phải sau giờ bắt đầu.',
      );
      return false;
    }

    return true;
  }

  int? _timeToMinutes(
    String value,
  ) {
    final parts =
        value.split(':');

    if (parts.length != 2) {
      return null;
    }

    final hour =
        int.tryParse(parts[0]);

    final minute =
        int.tryParse(parts[1]);

    if (hour == null ||
        minute == null) {
      return null;
    }

    return hour * 60 + minute;
  }

  String _tripPlaceIdentity(TripPlaceUi place) {
    final id = place.id.trim();

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

  bool _hasAdjacentDuplicatePlaces(
    List<TripPlaceUi> places,
  ) {
    for (var i = 1; i < places.length; i++) {
      if (_tripPlaceIdentity(places[i - 1]) ==
          _tripPlaceIdentity(places[i])) {
        return true;
      }
    }

    return false;
  }

  Future<void> _finishAddFlow() async {
    final trip =
        _pendingAddTrip;

    if (trip == null) {
      _closeAddFlow();
      return;
    }

    final all =
        List<TripPlaceUi>.from(
      trip.places,
    );

    final editingIndex =
        _editingTripPlaceGlobalIndex;

    if (editingIndex != null &&
        editingIndex >= 0 &&
        editingIndex < all.length) {
      all[editingIndex] =
          all[editingIndex].copyWith(
        startTime:
            _flowStartTime ?? '',
        endTime:
            _flowEndTime ?? '',
      );
    } else {
      final place =
          _pendingAddPlace;

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
          _tripPlaceIdentity(sameDayPlaces.last) ==
              _mapPlaceIdentity(place)) {
        _showMessage(
          'Không thể thêm cùng một địa điểm liên tiếp. Hãy thêm một địa điểm khác ở giữa.',
        );
        _closeAddFlow();
        return;
      }

      final imageUrl =
          place.thumbnailUrl ??
              (place.mediaUrls.isEmpty
                  ? null
                  : place.mediaUrls.first);

      all.add(
        TripPlaceUi(
          id: place.placeId,
          name: place.name,
          day: _flowDay,
          startTime:
              _flowStartTime ?? '',
          endTime:
              _flowEndTime ?? '',
          imageUrl: imageUrl,
        ),
      );
    }

    final updated =
        trip.copyWith(
      places:
          List<TripPlaceUi>.unmodifiable(
        all,
      ),
    );

    GoMateMapUiSession.updateTrip(
      updated,
    );

    GoMateMapUiSession.selectTrip(
      updated,
      day: _flowDay,
    );

    _selectedDay =
        _flowDay;

    setState(() {
      _tripHeaderExpanded = true;
    });

    await _clearSelectedPlace();

    _closeAddFlow();

    await _syncTripMemberPreview(
      updated,
    );
  }

  void _closeAddFlow() {
    if (!mounted) return;

    setState(() {
      _addStep = null;
      _pendingAddPlace = null;
      _pendingAddTrip = null;
      _editingTripPlaceGlobalIndex =
          null;

      _flowStartTime = null;
      _flowEndTime = null;
    });

    GoMateMapUiSession
        .setMapBottomNavHidden(false);
  }

  List<int> _globalIndexesForDay(
    TripUi trip,
    int day,
  ) {
    final indexes = <int>[];

    for (var i = 0;
        i < trip.places.length;
        i++) {
      if (trip.places[i].day ==
          day) {
        indexes.add(i);
      }
    }

    return indexes;
  }

  void _removeDayPlace(
    int dayIndex,
  ) {
    final trip = _trip;

    if (trip == null ||
        !trip.canEditTrip) {
      return;
    }

    final indexes =
        _globalIndexesForDay(
      trip,
      _selectedDay,
    );

    if (dayIndex < 0 ||
        dayIndex >= indexes.length) {
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

    final all =
        List<TripPlaceUi>.from(
      trip.places,
    );

    all.removeAt(
      indexes[dayIndex],
    );

    final updated =
        trip.copyWith(
      places:
          List<TripPlaceUi>.unmodifiable(
        all,
      ),
    );

    GoMateMapUiSession.updateTrip(
      updated,
    );
  }

  void _reorderDayPlaces(
    int oldIndex,
    int newIndex,
  ) {
    final trip = _trip;

    if (trip == null ||
        !trip.canEditTrip) {
      return;
    }

    final dayPlaces =
        trip.places
            .where(
              (item) =>
                  item.day ==
                  _selectedDay,
            )
            .toList();

    if (oldIndex < 0 ||
        oldIndex >= dayPlaces.length) {
      return;
    }

    var target = newIndex;

    if (target > oldIndex) {
      target--;
    }

    final moved =
        dayPlaces.removeAt(
      oldIndex,
    );

    dayPlaces.insert(
      target
          .clamp(
            0,
            dayPlaces.length,
          )
          .toInt(),
      moved,
    );

    if (_hasAdjacentDuplicatePlaces(dayPlaces)) {
      _showMessage(
        'Không thể sắp xếp để hai địa điểm giống nhau đứng liền nhau.',
      );
      return;
    }

    var cursor = 0;

    final rebuilt =
        trip.places.map(
      (item) {
        if (item.day !=
            _selectedDay) {
          return item;
        }

        final replacement =
            dayPlaces[cursor];

        cursor++;

        return replacement;
      },
    ).toList();

    final updated =
        trip.copyWith(
      places:
          List<TripPlaceUi>.unmodifiable(
        rebuilt,
      ),
    );

    GoMateMapUiSession.updateTrip(
      updated,
    );

    // Backend note:
    // sau khi reorder phải tính lại/swap thời gian hợp lý.
    // UI không tự đoán travel time ở đây.
  }

  void _requestOptimizeRoute() {
    final trip = _trip;

    if (trip == null ||
        !trip.canEditTrip) {
      return;
    }

    _showMessage(
      'Tối ưu lộ trình đã sẵn sàng ở UI; thứ tự tối ưu sẽ do backend trả về.',
    );
  }

  Future<void> _consumeSessionRequests() async {
    if (_processingSessionRequest ||
        !mounted) {
      return;
    }

    _processingSessionRequest = true;

    try {
      final launch =
          GoMateMapUiSession
              .consumeLaunchRequest();

      if (launch != null) {
        _selectedDay =
            launch.day
                .clamp(
                  1,
                  launch.trip.days,
                )
                .toInt();

        setState(() {
          _tripHeaderExpanded =
              launch.expandDayRoute;
        });

        await _syncTripMemberPreview(
          launch.trip,
        );
      }

      final add =
          GoMateMapUiSession
              .consumeAddPlaceRequest();

      if (add != null) {
        GoMateMapUiSession.selectTrip(
          add.trip,
        );

        await _state.selectPlace(
          add.placeId,
        );

        final loaded =
            _state.selectedPlace;

        if (loaded != null) {
          await _layers.renderSelected(
            loaded,
          );

          await _layers.focusPlace(
            loaded,
          );

          _beginAddFlow(
            place: loaded,
            trip: add.trip,
            startAtTime: false,
          );
        }
      }
    } finally {
      _processingSessionRequest =
          false;
    }
  }

  Future<void> _openSelectedPlaceDetail() async {
    final selected =
        _state.selectedPlace;

    if (selected == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PlaceDetailScreen(
          place:
              _toUiPlace(selected),
        ),
      ),
    );
  }

  MapPlaceUi _toUiPlace(
    GoMateMapPlace place,
  ) {
    final tags = <String>[
      place.categoryLabel,
      if (place.district != null)
        place.district!,
      place.province ?? 'Đà Lạt',
    ];

    return MapPlaceUi(
      id: place.placeId,
      name: place.name,
      subtitle:
          place.description ??
              'Khám phá địa điểm nổi bật.',
      address: place.address,
      distanceText:
          'Xem trên bản đồ',
      openInfo:
          place.openingHours ??
              'Đang cập nhật',
      priceInfo:
          _priceInfo(
        place.priceLevel,
      ),
      rating: place.rating,
      reviewCount:
          place.reviewCount,
      likeCount: place.saveCount,
      tags: tags,
      imageUrl:
          place.thumbnailUrl,
      mediaUrls:
          place.mediaUrls,
    );
  }

  String _priceInfo(
    int? priceLevel,
  ) {
    return switch (priceLevel) {
      0 => 'Miễn phí',
      1 => 'Chi phí thấp',
      2 => 'Chi phí vừa phải',
      3 => 'Chi phí cao',
      4 => 'Cao cấp',
      _ => 'Đang cập nhật',
    };
  }

  void _onMapTap(
    MapContentGestureContext gesture,
  ) {
    unawaited(
      _handleMapTap(gesture),
    );
  }

  Future<void> _handleMapTap(
    MapContentGestureContext gesture,
  ) async {
    if (_addFlowActive) {
      return;
    }

    if (_state.selectedPlace !=
        null) {
      await _clearSelectedPlace();
      return;
    }

    final lng =
        gesture
            .point
            .coordinates
            .lng
            .toDouble();

    final lat =
        gesture
            .point
            .coordinates
            .lat
            .toDouble();

    setState(() {
      _coordinateText =
          '${lat.toStringAsFixed(5)}, '
          '${lng.toStringAsFixed(5)}';
    });

    Future<void>.delayed(
      const Duration(
        seconds: 3,
      ),
      () {
        if (mounted) {
          setState(() {
            _coordinateText = null;
          });
        }
      },
    );
  }

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    GoMateSnackBar.show(
      context,
      message: message,
      bottomOffset:
          GoMateMapUiSession
                  .hideMapBottomNav
              ? 24
              : 90,
      icon:
          LucideIcons.circle_alert,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final media =
        MediaQuery.of(context);

    final width =
        media.size.width;

    final top =
        media.padding.top;

    final bottom =
        widget.bottomNavigationInset;

    final trip = _trip;

    final selectedPlace =
        _state.selectedPlace;

    // Cụm nút phải có vị trí cố định, KHÔNG phụ thuộc việc header ngày
    // đang mở hay đóng. GoMateMapControls đã tự giữ slot riêng cho compass,
    // nên chỉ cần đặt top của toàn cụm đủ thấp để compass không đè header.
    final controlsTop =
        top +
            (width * 0.34)
                .clamp(
                  122.0,
                  140.0,
                )
                .toDouble();

    final selectedPoint =
        _selectedPlaceScreenPoint;

    final placeCardWidth =
        GoMateMapPlaceCard.cardWidthFor(width);
    final placeCardTotalHeight =
        GoMateMapPlaceCard.totalHeightFor(width);

    double? placeCardLeft;
    double? placeCardTop;
    double? placeCardPointerX;

    if (selectedPlace != null && selectedPoint != null) {
      const horizontalMargin = 8.0;

      placeCardLeft =
          (selectedPoint.x - placeCardWidth / 2)
              .clamp(
                horizontalMargin,
                width - placeCardWidth - horizontalMargin,
              )
              .toDouble();

      placeCardPointerX =
          selectedPoint.x - placeCardLeft;

      // Mũi card chạm vào mép trên của selected circular marker.
      final markerRadius =
          _selectedMarkerRadiusForZoom(_currentZoom);

      final markerTop =
          selectedPoint.y - markerRadius + 2;

      placeCardTop =
          markerTop - placeCardTotalHeight;
    }

    return Scaffold(
      backgroundColor:
          Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: MapWidget(
              key: const ValueKey(
                'gomate-map',
              ),
              styleUri:
                  MapboxStyles.STANDARD,
              cameraOptions:
                  CameraOptions(
                center: Point(
                  coordinates:
                      _defaultCenter,
                ),
                zoom: 14.2,
                pitch: 15,
                bearing: 0,
              ),
              onMapCreated:
                  _onMapCreated,
              onStyleLoadedListener:
                  (_) =>
                      _onStyleLoaded(),
              onCameraChangeListener:
                  _onCameraChanged,
              onTapListener:
                  _onMapTap,
            ),
          ),

          if (trip != null)
            Positioned(
              top: top + 12,
              left: 0,
              right: 0,
              child: Center(
                child:
                    GoMateMapTripHeader(
                  trip: trip,
                  selectedDay:
                      _selectedDay,
                  placeCount:
                      _dayPlaces.length,
                  expanded:
                      _tripHeaderExpanded,
                  onToggleExpanded:
                      _toggleTripExpanded,
                  onEdit:
                      trip.canEditTrip
                          ? () {
                              unawaited(
                                _openTripDetail(),
                              );
                            }
                          : null,
                  onPreviousDay:
                      () =>
                          _changeDay(-1),
                  onNextDay:
                      () =>
                          _changeDay(1),
                  onDaySwipe:
                      _changeDay,
                ),
              ),
            ),

          Positioned(
            top: controlsTop,
            right:
                (width * 0.055)
                    .clamp(
                      18.0,
                      23.0,
                    )
                    .toDouble(),
            child:
                GoMateMapControls(
              onSearch:
                  _openPlaceSearch,
              onTripPicker:
                  _openTripPicker,
              onLocation:
                  _moveToCurrentLocation,
              showCompass:
                  _showCompass,
              bearing: _bearing,
              onCompass:
                  _resetNorth,
              onChat:
                  trip?.isGroup == true
                      ? () {
                          unawaited(
                            _openGroupChat(),
                          );
                        }
                      : null,
            ),
          ),

          if (_state.loading)
            Positioned(
              top: top +
                  (width * 0.26)
                      .clamp(
                        92.0,
                        110.0,
                      )
                      .toDouble(),
              left: 0,
              right: 0,
              child: const Center(
                child:
                    GoMateMapStatusPill(
                  text:
                      'Đang tải dữ liệu...',
                  icon:
                      LucideIcons.refresh_cw,
                ),
              ),
            ),

          if (_coordinateText !=
              null)
            Positioned(
              top: top +
                  (width * 0.26)
                      .clamp(
                        92.0,
                        110.0,
                      )
                      .toDouble(),
              left: 0,
              right: 0,
              child: Center(
                child:
                    GoMateMapStatusPill(
                  text:
                      _coordinateText!,
                  icon:
                      LucideIcons.map_pin,
                ),
              ),
            ),

          // Card địa điểm được neo trực tiếp vào geographic marker.
          // Pan / rotate / zoom -> pixelForCoordinate cập nhật -> card đi theo icon.
          if (selectedPlace != null &&
              placeCardLeft != null &&
              placeCardTop != null &&
              placeCardPointerX != null)
            Positioned(
              left: placeCardLeft,
              top: placeCardTop,
              child: GoMateMapPlaceCard(
                place: selectedPlace,
                pointerCenterX: placeCardPointerX,
                canAddToTrip:
                    trip == null || trip.canEditTrip,
                onClose: () {
                  unawaited(
                    _clearSelectedPlace(),
                  );
                },
                onToggleSaved:
                    _state.toggleSavedSelected,
                onOpenDetail: () {
                  unawaited(
                    _openSelectedPlaceDetail(),
                  );
                },
                onAddToTrip: () {
                  unawaited(
                    _startAddSelectedPlace(),
                  );
                },
              ),
            ),

          if (_tripHeaderExpanded &&
              trip != null &&
              !_addFlowActive)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child:
                  GoMateMapDayRoutePanel(
                places:
                    _dayPlaces,
                canEdit:
                    trip.canEditTrip,
                bottomInset:
                    bottom,
                onOptimize:
                    _requestOptimizeRoute,
                onPlaceTap:
                    _editDayPlaceTime,
                onRemove:
                    trip.canEditTrip
                        ? _removeDayPlace
                        : null,
                onReorder:
                    trip.canEditTrip
                        ? _reorderDayPlaces
                        : null,
              ),
            ),

          if (_addStep != null &&
              _pendingAddTrip !=
                  null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child:
                  GoMateMapAddPlaceFlowPanel(
                key: ValueKey(
                  'map-add-${_addStep!}-${_editingTripPlaceGlobalIndex ?? 'new'}',
                ),
                trip:
                    _pendingAddTrip!,
                step: _addStep!,
                selectedDay:
                    _flowDay,
                selectedTime:
                    _addStep ==
                            GoMateMapAddPlaceStep
                                .startTime
                        ? _flowStartTime
                        : _flowEndTime,
                onDayChanged:
                    (value) {
                  _flowDay =
                      value;
                },
                onTimeChanged:
                    (value) {
                  if (_addStep ==
                      GoMateMapAddPlaceStep
                          .startTime) {
                    _flowStartTime =
                        value;
                  } else if (_addStep ==
                      GoMateMapAddPlaceStep
                          .endTime) {
                    _flowEndTime =
                        value;
                  }
                },
                onContinue:
                    _onAddFlowContinue,
                onSkip:
                    _onAddFlowSkip,
              ),
            ),
        ],
      ),
    );
  }
}


class _MapMemberPreviewSeed {
  final String id;
  final String displayName;
  final String avatarAsset;

  const _MapMemberPreviewSeed({
    required this.id,
    required this.displayName,
    required this.avatarAsset,
  });
}
