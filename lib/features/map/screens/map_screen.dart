import 'dart:async';
import '../../trip/screens/create_trip_screen.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import 'place_detail_screen.dart';

import '../data/spring_map_gateway.dart';
import '../models/map_place.dart';
import '../services/location_service.dart';
import '../services/mapbox_layer_controller.dart';
import '../state/map_state.dart';
import '../utils/cloudinary_image_url.dart';
import '../widgets/directions_route_sheet.dart';
import '../widgets/map_controls.dart';
import '../widgets/map_status_pill.dart';
import '../widgets/place_bottom_sheet.dart';
import '../widgets/trip_route_sheet.dart';

class GoMateMapScreen extends StatefulWidget {
  final double bottomNavigationInset;

  const GoMateMapScreen({super.key, this.bottomNavigationInset = 0});

  @override
  State<GoMateMapScreen> createState() => _GoMateMapScreenState();
}

class _GoMateMapScreenState extends State<GoMateMapScreen> {
  final _state = GoMateMapState(SpringGoMateMapGateway());

  final _layers = GoMateMapboxLayerController();

  final _locationService = GoMateLocationService();

  MapboxMap? _map;
  String? _coordinateText;

  final Position _defaultCenter = Position(108.4488, 11.9416);

  @override
  void initState() {
    super.initState();

    _state.addListener(_onStateChanged);
    unawaited(_loadInitialPlaces());
  }

  Future<void> _openCreateTrip() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateTripScreen()));
  }

  Future<void> _loadInitialPlaces() async {
    await _state.init();

    if (_map != null && _state.mode == GoMateMapMode.explore) {
      await _layers.showExplorePlaces(_state.places);
    }
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _state.dispose();

    _layers.dispose();

    super.dispose();
  }

  /// Chỉ rebuild UI.
  ///
  /// Không render lại toàn bộ Mapbox layer mỗi lần
  /// ChangeNotifier notify để tránh lag emulator.
  void _onStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;

    await _layers.attach(
      map,
      onPlaceTap: (placeId) {
        unawaited(_selectPlace(placeId));
      },
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
        final route = _state.route;
        final origin = _state.directionsOrigin;
        final destination = _state.directionsDestination;

        if (route != null && origin != null && destination != null) {
          await _layers.renderDirections(
            route: route,
            origin: origin,
            destination: destination,
          );
        }
        break;

      case GoMateMapMode.trip:
        final route = _state.route;

        if (route != null) {
          await _layers.renderTrip(
            route: route,
            stops: _state.tripStops,
            members: _state.members,
          );
        }
        break;
    }
  }

  Future<void> _selectPlace(String placeId) async {
    if (_state.mode == GoMateMapMode.directions &&
        _state.choosingDirectionsOrigin) {
      final ok = await _state.changeDirectionsOriginPlace(placeId);

      if (!ok) {
        _showMessage(_state.errorMessage ?? 'Không đổi được điểm bắt đầu.');
        return;
      }

      await _renderCurrentMode();
      return;
    }

    if (_state.mode != GoMateMapMode.explore) {
      return;
    }

    await _state.selectPlace(placeId);

    final place = _state.selectedPlace;

    if (place != null) {
      await _layers.renderSelected(place);
      await _layers.focusPlace(place);
      unawaited(_precachePlaceHero(place));
    }
  }

  Future<void> _precachePlaceHero(GoMateMapPlace place) async {
    final rawUrl = place.mediaUrls.isNotEmpty
        ? place.mediaUrls.first
        : place.thumbnailUrl;
    if (rawUrl == null) return;

    try {
      await precacheImage(
        NetworkImage(cloudinaryPlaceHeroUrl(rawUrl)),
        context,
      );
    } catch (_) {
      // Image fallback in the detail screen will handle this visibly.
    }
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

    await _renderCurrentMode();
  }

  void _beginChooseOrigin() {
    _state.beginChooseDirectionsOrigin();

    _showMessage('Chạm một marker địa điểm để chọn điểm bắt đầu mới.');
  }

  void _useCurrentLocationForDirections() {
    unawaited(_recalculateDirectionsFromCurrentLocation());
  }

  Future<void> _recalculateDirectionsFromCurrentLocation() async {
    final destination = _state.directionsDestination;
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

    await _renderCurrentMode();
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

  Future<void> _showTrip() async {
    await _state.showTrip('trip-demo-01');

    await _renderCurrentMode();
  }

  Future<void> _showExplore() async {
    await _state.showExplore();

    await _layers.showExplorePlaces(_state.places);
  }

  void _onMapTap(MapContentGestureContext context) {
    unawaited(_handleMapTap(context));
  }

  Future<void> _handleMapTap(MapContentGestureContext context) async {
    final lng = context.point.coordinates.lng.toDouble();

    final lat = context.point.coordinates.lat.toDouble();

    if (_state.mode == GoMateMapMode.directions &&
        _state.choosingDirectionsOrigin) {
      _showMessage('Hãy chạm một marker Place để route bằng places.id thật.');
      return;
    }

    if (_state.mode != GoMateMapMode.explore) {
      return;
    }

    if (_state.selectedPlace != null) {
      _state.clearSelection();

      await _layers.renderSelected(null);

      return;
    }

    setState(() {
      _coordinateText = '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    });

    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _coordinateText = null);
      }
    });
  }

  Future<void> _openSearchSheet() async {
    final uiPlaces = _state.places.map(_toUiPlace).toList(growable: false);

    final selectedUi = await showModalBottomSheet<MapPlaceUi>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _MapSearchSheet(places: uiPlaces, onSearch: _searchSheetPlaces),
    );

    if (!mounted || selectedUi == null) {
      return;
    }

    GoMateMapPlace? destination;
    for (final place in _state.places) {
      if (place.placeId == selectedUi.id) {
        destination = place;
        break;
      }
    }

    if (destination == null) {
      _showMessage('Không tìm thấy địa điểm trên bản đồ hiện tại.');
      return;
    }

    await _state.selectPlace(destination.placeId);

    final selected = _state.selectedPlace;
    if (selected == null) return;

    await _layers.renderSelected(selected);
    await _layers.focusPlace(selected);
    await _openSelectedPlaceDetail();
  }

  Future<List<MapPlaceUi>> _searchSheetPlaces(String query) async {
    await _state.setQuery(query);

    if (_state.mode == GoMateMapMode.explore) {
      await _layers.showExplorePlaces(_state.places);
    }

    return _state.places.map(_toUiPlace).toList(growable: false);
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

    if (routeRequested == true) {
      await _directionsToSelected();
    }
  }

  MapPlaceUi _toUiPlace(GoMateMapPlace place) {
    final subtitle =
        place.description ?? 'Khám phá địa điểm nổi bật tại Đà Lạt.';
    var distanceText = 'Xem trên bản đồ';
    final openInfo = place.openingHours ?? 'Đang cập nhật';
    final priceInfo = _priceInfo(place.priceLevel);
    final likeCount = place.saveCount;
    final tags = <String>[
      place.categoryLabel,
      if (place.district != null) place.district!,
      place.province ?? 'Đà Lạt',
    ];

    return MapPlaceUi(
      id: place.placeId,
      name: place.name,
      subtitle: subtitle,
      address: place.address,
      distanceText: distanceText,
      openInfo: openInfo,
      priceInfo: priceInfo,
      rating: place.rating,
      reviewCount: place.reviewCount,
      likeCount: likeCount,
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

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = widget.bottomNavigationInset;

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

          if (_state.mode == GoMateMapMode.explore)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, top: 10),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openSearchSheet,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.96),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.search_rounded,
                          size: 27,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            right: 14,
            bottom: _controlsBottom(bottom),
            child: GoMateMapControls(
              onCreateTrip: _openCreateTrip,
              onTrip: _showTrip,
              onResetNorth: _resetNorth,
              onLocation: _moveToCurrentLocation,
            ),
          ),

          if (_state.loading)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 118,
              left: 0,
              right: 0,
              child: const Center(
                child: GoMateMapStatusPill(
                  text: 'Đang tải dữ liệu...',
                  icon: Icons.sync_rounded,
                ),
              ),
            ),

          if (_state.mode == GoMateMapMode.directions &&
              _state.choosingDirectionsOrigin)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 18,
              left: 14,
              right: 14,
              child: const GoMateMapStatusPill(
                text: 'Chạm một marker để chọn điểm bắt đầu',
                icon: Icons.edit_location_alt_rounded,
              ),
            ),

          if (_coordinateText != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 118,
              left: 0,
              right: 0,
              child: Center(
                child: GoMateMapStatusPill(
                  text: _coordinateText!,
                  icon: Icons.pin_drop_outlined,
                ),
              ),
            ),

          if (_state.errorMessage != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 118,
              left: 14,
              right: 14,
              child: GoMateMapStatusPill(
                text: _state.errorMessage!,
                icon: Icons.error_outline_rounded,
              ),
            ),

          if (_state.selectedPlace != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 14 + bottom,
              child: GoMatePlaceBottomSheet(
                place: _state.selectedPlace!,
                onClose: () {
                  _state.clearSelection();

                  unawaited(_layers.renderSelected(null));
                },
                onToggleSaved: _state.toggleSavedSelected,
                onDirections: _directionsToSelected,
                onOpenDetail: () {
                  unawaited(_openSelectedPlaceDetail());
                },
              ),
            )
          else if (_state.mode == GoMateMapMode.directions &&
              _state.route != null &&
              _state.directionsDestination != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 14 + bottom,
              child: GoMateDirectionsRouteSheet(
                route: _state.route!,
                destination: _state.directionsDestination!,
                originLabel: _state.directionsOriginLabel,
                originIsCurrentLocation:
                    _state.directionsOriginIsCurrentLocation,
                choosingOrigin: _state.choosingDirectionsOrigin,
                onChooseOrigin: _beginChooseOrigin,
                onUseCurrentLocation: _useCurrentLocationForDirections,
                onClose: _showExplore,
              ),
            )
          else if (_state.mode == GoMateMapMode.trip && _state.route != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 14 + bottom,
              child: GoMateTripRouteSheet(
                route: _state.route!,
                stops: _state.tripStops,
                onExitTrip: _showExplore,
                onStartTrip: () {
                  _showMessage('Production: chuyển sang Live Trip mode.');
                },
              ),
            ),
        ],
      ),
    );
  }

  double _controlsBottom(double bottomInset) {
    if (_state.selectedPlace != null) {
      return 238 + bottomInset;
    }

    if (_state.mode == GoMateMapMode.directions) {
      return 270 + bottomInset;
    }

    if (_state.mode == GoMateMapMode.trip && _state.route != null) {
      return 248 + bottomInset;
    }

    return 30 + bottomInset;
  }
}

// ============================================================================
// FRONTEND SEARCH UI GIỮ TỪ BẢN DART CỦA BẠN
// Fake map cũ KHÔNG được mang sang; Mapbox V4 vẫn là map thật.
// ============================================================================

class _MapSearchSheet extends StatefulWidget {
  final List<MapPlaceUi> places;
  final Future<List<MapPlaceUi>> Function(String query) onSearch;

  const _MapSearchSheet({required this.places, required this.onSearch});

  @override
  State<_MapSearchSheet> createState() => _MapSearchSheetState();
}

class _MapSearchSheetState extends State<_MapSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  final List<String> _categories = const [
    'Tất cả',
    'Ăn uống',
    'Check-in',
    'Thiên nhiên',
    'Văn hóa',
    'Local',
  ];

  String _selectedCategory = 'Tất cả';
  late List<MapPlaceUi> _places;
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _places = widget.places;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  List<MapPlaceUi> get _results {
    final keyword = _controller.text.trim().toLowerCase();

    return _places.where((place) {
      final matchesKeyword =
          keyword.isEmpty ||
          place.name.toLowerCase().contains(keyword) ||
          place.address.toLowerCase().contains(keyword) ||
          place.subtitle.toLowerCase().contains(keyword) ||
          place.tags.join(' ').toLowerCase().contains(keyword);

      if (!matchesKeyword) return false;

      if (_selectedCategory == 'Tất cả') {
        return true;
      }

      final source = [
        place.name,
        place.subtitle,
        place.address,
        ...place.tags,
      ].join(' ').toLowerCase();

      switch (_selectedCategory) {
        case 'Ăn uống':
          return source.contains('ẩm thực') ||
              source.contains('cà phê') ||
              source.contains('ăn') ||
              source.contains('đặc sản');

        case 'Check-in':
          return source.contains('check-in') ||
              source.contains('sống ảo') ||
              source.contains('view đẹp');

        case 'Thiên nhiên':
          return source.contains('hồ') ||
              source.contains('vườn') ||
              source.contains('đồi') ||
              source.contains('thiên nhiên');

        case 'Văn hóa':
          return source.contains('văn hóa') ||
              source.contains('dinh') ||
              source.contains('ga');

        case 'Local':
          return source.contains('local') ||
              source.contains('chợ') ||
              source.contains('đặc sản');

        default:
          return true;
      }
    }).toList();
  }

  void _onQueryChanged(String value) {
    setState(() {
      _errorMessage = null;
    });

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      _runSearch(value);
    });
  }

  Future<void> _runSearch(String value) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final places = await widget.onSearch(value);
      if (!mounted) return;
      setState(() {
        _places = places;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _places = const <MapPlaceUi>[];
        _errorMessage = 'Không tải được kết quả tìm kiếm.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.58,
      maxChildSize: 0.96,
      snap: true,
      snapSizes: const [0.58, 0.88, 0.96],
      builder: (context, scrollController) {
        final results = _results;

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),

              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.blue100,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 16),

              // SEARCH
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: TextField(
                  controller: _controller,
                  onChanged: _onQueryChanged,
                  decoration: InputDecoration(
                    hintText: 'Bạn muốn đi đâu?',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondary,
                    ),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _controller.clear();
                              _onQueryChanged('');
                            },
                            icon: const Icon(Icons.close_rounded, size: 19),
                          ),
                    filled: true,
                    fillColor: AppColors.blue50.withOpacity(0.45),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // CATEGORY TITLE
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    const Text(
                      'Danh mục',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 16,
                              color: AppColors.blue500,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Bộ lọc',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.blue500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                height: 38,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final category = _categories[index];
                    final active = _selectedCategory == category;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active ? AppColors.blue500 : AppColors.blue50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 18),

              // LIST TITLE
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Text(
                      _controller.text.trim().isEmpty
                          ? 'Gợi ý địa điểm'
                          : 'Kết quả tìm kiếm',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${results.length} địa điểm',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: LinearProgressIndicator(minHeight: 2),
                ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: _SearchErrorState(message: _errorMessage!),
                ),

              // GRID
              Expanded(
                child: _errorMessage != null
                    ? const SizedBox.shrink()
                    : results.isEmpty
                    ? const _SearchEmptyState()
                    : GridView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.76,
                            ),
                        itemCount: results.length,
                        itemBuilder: (_, index) {
                          final place = results[index];

                          return _PlaceGridCard(
                            place: place,
                            onTap: () => Navigator.pop(context, place),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// GRID PLACE CARD
// ============================================================================

class _PlaceGridCard extends StatelessWidget {
  final MapPlaceUi place;
  final VoidCallback onTap;

  const _PlaceGridCard({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.blue100.withOpacity(0.42)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _PlaceImage(place: place),

                  Positioned(
                    top: 9,
                    right: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.94),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Color(0xFFFFB547),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            place.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        const Icon(
                          Icons.route_outlined,
                          size: 14,
                          color: AppColors.blue500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            place.distanceText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      _shortCategory(place),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortCategory(MapPlaceUi place) {
    if (place.tags.isEmpty) return 'Địa điểm';

    return place.tags.take(2).join(' • ');
  }
}

class _PlaceImage extends StatelessWidget {
  final MapPlaceUi place;

  const _PlaceImage({required this.place});

  @override
  Widget build(BuildContext context) {
    if (place.imageUrl != null) {
      return Image.network(
        place.imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _placeholder();
        },
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }

    if (place.imageAsset != null) {
      return Image.asset(
        place.imageAsset!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.blue100, AppColors.blue50],
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.landscape_outlined,
        size: 36,
        color: AppColors.blue500,
      ),
    );
  }
}

class _SearchErrorState extends StatelessWidget {
  final String message;

  const _SearchErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Color(0xFFBE123C),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9F1239),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 34, color: AppColors.blue300),
            SizedBox(height: 10),
            Text(
              'Không tìm thấy địa điểm',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Thử từ khóa hoặc danh mục khác.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
