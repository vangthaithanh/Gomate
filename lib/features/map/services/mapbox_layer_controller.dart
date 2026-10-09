import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../models/map_member.dart';
import '../models/map_place.dart';
import '../models/map_route.dart';

typedef GoMatePlaceTap = void Function(String placeId);

class GoMateMapboxLayerController {
  MapboxMap? _map;

  // Marker size policy:
  // - zoom xa: dot có kích thước tối thiểu cố định.
  // - zoom gần: icon xuất hiện và tăng dần theo zoom.
  // - sau khi đủ lớn thì dừng, không tăng vô hạn.
  static const double _farDotRadius = 7.5;
  static const double _mediumDotRadius = 10.0;

  static const double _nearStartZoom = 14.4;
  static const double _nearFullZoom = 16.8;
  static const double _nearZoomStep = 0.25;

  static const double _nearMinIconSize = 0.88;
  static const double _nearMaxIconSize = 1.28;

  static const double _selectedMinIconSize = 1.08;
  static const double _selectedMaxIconSize = 1.42;

  // Zenly-style member marker.
  // Zoom xa: avatar-only, không có card trắng.
  // Zoom vừa/gần: card trắng hiện ra, tăng dần rồi dừng.
  static const double _memberCardStartZoom = 12.6;
  static const double _memberCardFullZoom = 16.2;
  static const double _memberZoomStep = 0.25;

  static const double _memberFarIconSize = 1.08;
  static const double _memberCardMinIconSize = 1.42;
  static const double _memberCardMaxIconSize = 1.72;



  _PlaceVisualType _visualTypeForPlace(
      GoMateMapPlace place,
      ) {
    final source = <String>[
      place.categoryLabel,
      place.name,
      place.description ?? '',
      place.address,
    ].join(' ').toLowerCase();

    bool containsAny(List<String> keys) {
      return keys.any(source.contains);
    }

    // Transport first because backend hiện vẫn có thể gom chúng vào attraction.
    if (containsAny([
      'bus',
      'xe buýt',
      'xe buyt',
      'public transport',
      'trạm xe',
      'tram xe',
    ])) {
      return _PlaceVisualType.bus;
    }

    if (containsAny([
      'train',
      'rail',
      'railway',
      'ga ',
      'nhà ga',
      'nha ga',
      'tàu',
      'tau ',
    ])) {
      return _PlaceVisualType.train;
    }

    if (containsAny([
      'hotel',
      'hostel',
      'resort',
      'lodging',
      'khách sạn',
      'khach san',
      'nhà nghỉ',
      'nha nghi',
      'homestay',
    ])) {
      return _PlaceVisualType.hotel;
    }

    if (containsAny([
      'bar',
      'pub',
      'nightlife',
      'cocktail',
      'beer',
      'bia ',
    ])) {
      return _PlaceVisualType.bar;
    }

    if (containsAny([
      'cafe',
      'coffee',
      'cà phê',
      'ca phe',
      'quán cà phê',
      'quan ca phe',
    ])) {
      return _PlaceVisualType.cafe;
    }

    if (containsAny([
      'bakery',
      'dessert',
      'cake',
      'bánh',
      'banh ',
      'kem ',
      'ice cream',
    ])) {
      return _PlaceVisualType.bakery;
    }

    if (containsAny([
      'restaurant',
      'food',
      'ẩm thực',
      'am thuc',
      'ăn uống',
      'an uong',
      'quán ăn',
      'quan an',
      'nhà hàng',
      'nha hang',
    ])) {
      return _PlaceVisualType.restaurant;
    }

    if (containsAny([
      'museum',
      'bảo tàng',
      'bao tang',
      'heritage',
      'di tích',
      'di tich',
      'historical',
      'lịch sử',
      'lich su',
      'văn hóa',
      'van hoa',
      'temple',
      'pagoda',
      'chùa',
      'chua ',
    ])) {
      return _PlaceVisualType.culture;
    }

    if (containsAny([
      'check-in',
      'checkin',
      'photo',
      'camera',
      'viewpoint',
      'landmark',
      'quảng trường',
      'quang truong',
    ])) {
      return _PlaceVisualType.checkin;
    }

    if (containsAny([
      'lake',
      'water',
      'beach',
      'river',
      'waterfall',
      'hồ ',
      'ho ',
      'sông',
      'song ',
      'thác',
      'thac ',
      'biển',
      'bien ',
      'suối',
      'suoi ',
    ])) {
      return _PlaceVisualType.water;
    }

    if (containsAny([
      'mountain',
      'hill',
      'valley',
      'đồi',
      'doi ',
      'núi',
      'nui ',
      'thung lũng',
      'thung lung',
    ])) {
      return _PlaceVisualType.landscape;
    }

    if (containsAny([
      'park',
      'garden',
      'forest',
      'nature',
      'công viên',
      'cong vien',
      'vườn',
      'vuon ',
      'rừng',
      'rung ',
      'thiên nhiên',
      'thien nhien',
    ])) {
      return _PlaceVisualType.park;
    }

    if (containsAny([
      'shopping',
      'mall',
      'market',
      'store',
      'shop',
      'mua sắm',
      'mua sam',
      'chợ',
      'cho ',
    ])) {
      return _PlaceVisualType.shopping;
    }

    if (containsAny([
      'music',
      'theater',
      'theatre',
      'entertainment',
      'activity',
      'music venue',
      'âm nhạc',
      'am nhac',
      'giải trí',
      'giai tri',
      'sân khấu',
      'san khau',
    ])) {
      return _PlaceVisualType.entertainment;
    }

    // Fallback vẫn bám enum backend hiện tại, không thay backend contract.
    return switch (place.category) {
      GoMatePlaceCategory.attraction =>
      _PlaceVisualType.attraction,
      GoMatePlaceCategory.cafe =>
      _PlaceVisualType.cafe,
      GoMatePlaceCategory.food =>
      _PlaceVisualType.restaurant,
      GoMatePlaceCategory.nature =>
      _PlaceVisualType.park,
      GoMatePlaceCategory.shopping =>
      _PlaceVisualType.shopping,
    };
  }

  int _visualColor(
      _PlaceVisualType type,
      ) {
    return switch (type) {
      _PlaceVisualType.attraction => 0xFF5B8DEF,
      _PlaceVisualType.checkin => 0xFFEF6F72,
      _PlaceVisualType.culture => 0xFFE2A51A,

      _PlaceVisualType.cafe => 0xFFE79B57,
      _PlaceVisualType.restaurant => 0xFFF07B63,
      _PlaceVisualType.bakery => 0xFFF2A65A,
      _PlaceVisualType.bar => 0xFFC45A9A,

      _PlaceVisualType.park => 0xFF64B77D,
      _PlaceVisualType.water => 0xFF45A7C5,
      _PlaceVisualType.landscape => 0xFF5A9C70,

      _PlaceVisualType.shopping => 0xFF8D6BC8,
      _PlaceVisualType.hotel => 0xFF2C9C91,

      _PlaceVisualType.bus => 0xFF2F80ED,
      _PlaceVisualType.train => 0xFF4D8097,

      _PlaceVisualType.entertainment => 0xFFE35A9A,
    };
  }

  IconData _visualIcon(
      _PlaceVisualType type,
      ) {
    return switch (type) {
      _PlaceVisualType.attraction => Icons.star,
      _PlaceVisualType.checkin => Icons.camera_alt,
      _PlaceVisualType.culture => Icons.account_balance,

      _PlaceVisualType.cafe => Icons.local_cafe,
      _PlaceVisualType.restaurant => Icons.restaurant,
      _PlaceVisualType.bakery => Icons.cake,
      _PlaceVisualType.bar => Icons.local_bar,

      _PlaceVisualType.park => Icons.park,
      _PlaceVisualType.water => Icons.pool,
      _PlaceVisualType.landscape => Icons.landscape,

      _PlaceVisualType.shopping => Icons.shopping_bag,
      _PlaceVisualType.hotel => Icons.hotel,

      _PlaceVisualType.bus => Icons.directions_bus,
      _PlaceVisualType.train => Icons.train,

      _PlaceVisualType.entertainment => Icons.music_note,
    };
  }

  int _nearZoomBucket(
      double zoom,
      ) {
    final clamped = zoom
        .clamp(_nearStartZoom, _nearFullZoom)
        .toDouble();

    return ((clamped - _nearStartZoom) / _nearZoomStep)
        .floor();
  }

  double _nearIconSizeForZoom(
      double zoom,
      ) {
    final clamped = zoom
        .clamp(_nearStartZoom, _nearFullZoom)
        .toDouble();

    final rawT =
        (clamped - _nearStartZoom) /
            (_nearFullZoom - _nearStartZoom);

    // Ease-out: tăng nhanh ở đầu để icon sớm đủ rõ,
    // sau đó tăng chậm dần và dừng ở max size.
    final t = Curves.easeOutCubic.transform(rawT);

    return _nearMinIconSize +
        ((_nearMaxIconSize - _nearMinIconSize) * t);
  }

  double _selectedIconSizeForZoom(
      double zoom,
      ) {
    final normal = _nearIconSizeForZoom(zoom);

    return (normal + 0.16)
        .clamp(
      _selectedMinIconSize,
      _selectedMaxIconSize,
    )
        .toDouble();
  }

  _MemberMarkerMode _memberModeForZoom(
      double zoom,
      ) {
    if (zoom < _memberCardStartZoom) {
      return _MemberMarkerMode.far;
    }

    return _MemberMarkerMode.card;
  }

  double _currentUserIconSizeForZoom(
      double zoom,
      ) {
    final clamped = zoom
        .clamp(
      _memberCardStartZoom,
      _memberCardFullZoom,
    )
        .toDouble();

    final rawT =
        (clamped - _memberCardStartZoom) /
            (_memberCardFullZoom -
                _memberCardStartZoom);

    final t =
    Curves.easeOutCubic.transform(
      rawT,
    );

    const minSize = 1.10;
    const maxSize = 1.42;

    return minSize +
        ((maxSize - minSize) * t);
  }

  int _memberZoomBucket(
      double zoom,
      ) {
    final clamped = zoom
        .clamp(
      _memberCardStartZoom,
      _memberCardFullZoom,
    )
        .toDouble();

    return ((clamped - _memberCardStartZoom) /
        _memberZoomStep)
        .floor();
  }

  double _memberCardIconSizeForZoom(
      double zoom,
      ) {
    final clamped = zoom
        .clamp(
      _memberCardStartZoom,
      _memberCardFullZoom,
    )
        .toDouble();

    final rawT =
        (clamped - _memberCardStartZoom) /
            (_memberCardFullZoom - _memberCardStartZoom);

    final t =
    Curves.easeOutCubic.transform(rawT);

    return _memberCardMinIconSize +
        ((_memberCardMaxIconSize -
            _memberCardMinIconSize) *
            t);
  }

  bool _isPreviewCurrentUser(
      GoMateMapMember member,
      ) {
    return _previewCurrentUserId != null &&
        member.userId == _previewCurrentUserId;
  }

  String _memberSubtitle(
      GoMateMapMember member,
      ) {
    if (_isPreviewCurrentUser(member)) {
      return '';
    }

    final currentId = _previewCurrentUserId;

    if (currentId == null) {
      return 'Đang hoạt động';
    }

    GoMateMapMember? current;

    for (final item in _previewMembers) {
      if (item.userId == currentId) {
        current = item;
        break;
      }
    }

    if (current == null) {
      return 'Đang hoạt động';
    }

    final km = _distanceKm(
      current.position,
      member.position,
    );

    if (km < 1) {
      return '${(km * 1000).round()} m';
    }

    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  double _distanceKm(
      Position a,
      Position b,
      ) {
    const earthRadiusKm = 6371.0;

    final lat1 =
        a.lat.toDouble() * math.pi / 180;

    final lat2 =
        b.lat.toDouble() * math.pi / 180;

    final dLat =
        (b.lat.toDouble() -
            a.lat.toDouble()) *
            math.pi /
            180;

    final dLng =
        (b.lng.toDouble() -
            a.lng.toDouble()) *
            math.pi /
            180;

    final sinLat =
    math.sin(dLat / 2);

    final sinLng =
    math.sin(dLng / 2);

    final h =
        (sinLat * sinLat) +
            math.cos(lat1) *
                math.cos(lat2) *
                (sinLng * sinLng);

    final c =
        2 *
            math.atan2(
              math.sqrt(h),
              math.sqrt(1 - h),
            );

    return earthRadiusKm * c;
  }

  _ExploreMarkerMode _markerModeForZoom(
      double zoom,
      ) {
    if (zoom < 12.8) {
      return _ExploreMarkerMode.far;
    }

    if (zoom < _nearStartZoom) {
      return _ExploreMarkerMode.medium;
    }

    return _ExploreMarkerMode.near;
  }

  PointAnnotationManager? _placeManager;
  CircleAnnotationManager? _placeDotManager;

  PointAnnotationManager? _selectedManager;
  PointAnnotationManager? _tripStopManager;
  PointAnnotationManager? _memberManager;

  // Pulse của current user dùng cùng tọa độ với avatar.
  // Manager này được tạo TRƯỚC currentUserManager để layer pulse nằm dưới avatar.
  CircleAnnotationManager? _currentUserPulseManager;

  // Current user is rendered as a PointAnnotation so it behaves exactly
  // like the approved member marker and stays upright when the map rotates.
  PointAnnotationManager? _currentUserManager;

  PolylineAnnotationManager? _routeShadowManager;
  PolylineAnnotationManager? _routeManager;

  CircleAnnotationManager? _checkinRadiusManager;
  CircleAnnotationManager? _originManager;

  Cancelable? _placeTapSubscription;
  Cancelable? _placeDotTapSubscription;
  Cancelable? _tripTapSubscription;

  final Map<_PlaceVisualType, Uint8List> _placeMarkerImages = {};
  final Map<_PlaceVisualType, Uint8List> _selectedMarkerImages = {};

  // Trip stop được vẽ runtime để không còn phụ thuộc trip_stop_1..6.png.
  // Key: "<number>:normal" hoặc "<number>:destination".
  final Map<String, Uint8List> _tripStopMarkerCache = {};

  // Giữ raw image cho flow Trip cũ.
  final Map<String, Uint8List> _memberImages = {};

  // Preview Zenly-style dùng ui.Image để crop avatar tròn.
  final Map<String, ui.Image> _memberAvatarImages = {};
  final Map<String, Uint8List> _memberMarkerCache = {};

  final Map<String, Uint8List> _currentUserMarkerCache = {};
  Uint8List? _transparentLocationPuckImage;

  CircleAnnotation? _currentUserPulseAnnotation;
  Timer? _currentUserPulseTimer;
  bool _currentUserPulseFrameInFlight = false;
  int _currentUserPulseStartedAtMs = 0;

  // Nhịp gần cảm giác pulse native V9:
  // nở rõ, mờ dần, reset nhanh.
  static const int _currentUserPulseCycleMs = 1050;
  static const Duration _currentUserPulseFrameInterval =
  Duration(milliseconds: 40);

  bool _locationAvatarEnabled = false;
  bool _routeTrackingActive = false;

  String _locationAvatarAsset =
      'assets/map/member_thu.png';

  String _locationDisplayName = 'Bạn';

  Position? _currentUserPosition;

  _MemberMarkerMode? _currentUserMarkerMode;
  int? _currentUserMarkerBucket;

  List<GoMateMapPlace> _explorePlaces =
  const <GoMateMapPlace>[];

  double _currentZoom = 14.2;

  bool _exploreMarkersEnabled = true;

  _ExploreMarkerMode? _placeMarkerMode;
  int? _nearMarkerBucket;
  GoMateMapPlace? _selectedPlace;

  List<GoMateMapMember> _previewMembers =
  const <GoMateMapMember>[];

  String? _previewCurrentUserId;
  bool _previewMembersEnabled = false;

  _MemberMarkerMode? _memberMarkerMode;
  int? _memberMarkerBucket;

  Future<void> attach(
      MapboxMap map, {
        required GoMatePlaceTap onPlaceTap,
      }) async {
    _map = map;
    await _loadAssets();

    _placeManager =
    await map.annotations.createPointAnnotationManager();

    _placeDotManager =
    await map.annotations.createCircleAnnotationManager();

    _selectedManager =
    await map.annotations.createPointAnnotationManager();
    _tripStopManager =
    await map.annotations.createPointAnnotationManager();
    _memberManager =
    await map.annotations.createPointAnnotationManager();

    // Tạo pulse trước avatar để layer của avatar luôn nằm phía trên.
    _currentUserPulseManager =
    await map.annotations.createCircleAnnotationManager();

    _currentUserManager =
    await map.annotations.createPointAnnotationManager();

    _routeShadowManager =
    await map.annotations.createPolylineAnnotationManager();
    _routeManager =
    await map.annotations.createPolylineAnnotationManager();

    _checkinRadiusManager =
    await map.annotations.createCircleAnnotationManager();
    _originManager =
    await map.annotations.createCircleAnnotationManager();

    await _placeManager?.setIconAllowOverlap(true);
    await _selectedManager?.setIconAllowOverlap(true);
    await _tripStopManager?.setIconAllowOverlap(true);
    await _memberManager?.setIconAllowOverlap(true);

    await _currentUserPulseManager?.setCirclePitchAlignment(
      CirclePitchAlignment.VIEWPORT,
    );
    await _currentUserPulseManager?.setCirclePitchScale(
      CirclePitchScale.VIEWPORT,
    );

    await _currentUserManager?.setIconAllowOverlap(true);
    await _currentUserManager?.setIconIgnorePlacement(true);

    // Force the current-user marker to face the screen.
    // Rotating/pitching the map no longer rotates/distorts the avatar card.
    await _currentUserManager?.setIconRotationAlignment(
      IconRotationAlignment.VIEWPORT,
    );
    await _currentUserManager?.setIconPitchAlignment(
      IconPitchAlignment.VIEWPORT,
    );

    _placeTapSubscription = _placeManager?.tapEvents(
      onTap: (annotation) {
        final id = annotation.customData?['placeId']?.toString();

        if (id != null) {
          onPlaceTap(id);
        }
      },
    );

    _placeDotTapSubscription =
        _placeDotManager?.tapEvents(
          onTap: (annotation) {
            final id =
            annotation.customData?['placeId']?.toString();

            if (id != null) {
              onPlaceTap(id);
            }
          },
        );

    _tripTapSubscription = _tripStopManager?.tapEvents(
      onTap: (annotation) {
        final id = annotation.customData?['placeId']?.toString();
        if (id != null) {
          onPlaceTap(id);
        }
      },
    );
  }


  Future<void> configureGoMateBaseStyle() async {
    final map = _map;
    if (map == null) return;

    await map.style.setStyleImportConfigProperties(
      'basemap',
      <String, Object>{
        // ============================================================
        // GOMATE LIGHT MAP
        // ============================================================

        'lightPreset': 'day',

        // QUAN TRỌNG:
        // Không dùng monochrome nữa vì làm toàn map bị xám.
        'theme': 'default',

        // ============================================================
        // VISIBILITY
        // ============================================================

        'showPointOfInterestLabels': false,
        'showPlaceLabels': true,
        'showRoadLabels': true,
        'showTransitLabels': false,
        'showPedestrianRoads': true,

        // Giúp nhận biết ranh giới khu vực rõ hơn.
        'showAdminBoundaries': true,

        'show3dObjects': false,

        // ============================================================
        // BASE
        // ============================================================

        // Nền đất hơi xanh/xám, không dùng trắng tinh.
        'colorLand': '#F4F7FB',

        // Nước phải đủ khác với đất.
        'colorWater': '#CFEAF7',

        // ============================================================
        // LAND USE
        // ============================================================

        // Công viên / cây xanh.
        'colorGreenspace': '#DDEFE3',

        // Khu thương mại - xanh tím cực nhạt.
        'colorCommercial': '#E9EFF9',

        // Trường học / đại học.
        'colorEducation': '#EEEAF8',

        // Bệnh viện / y tế.
        'colorMedical': '#F8E8EC',

        // Công nghiệp.
        'colorIndustrial': '#ECE8E1',

        // ============================================================
        // BUILDINGS
        // ============================================================

        'colorBuildings': '#DCE3EC',

        // ============================================================
        // ROADS
        // ============================================================

        // Đường nhỏ sáng hơn nền building.
        'colorRoads': '#FFFFFF',

        // Trục đường lớn.
        'colorTrunks': '#D5E2F0',

        // Cao tốc / đường chính nổi hơn một chút.
        'colorMotorways': '#BFD7F5',

        // ============================================================
        // LABELS
        // ============================================================

        'colorPlaceLabels': '#42546D',

        'colorRoadLabels': '#68788D',

        // ============================================================
        // ADMINISTRATIVE BOUNDARIES
        // ============================================================

        'colorAdminBoundaries': '#AEBCCE',
      },
    );
  }

  /// Current-user location visual.
  ///
  /// Important:
  /// - visible avatar/card = PointAnnotation;
  /// - native Mapbox location component = pulse only.
  ///
  /// This is what makes the current user behave exactly like the
  /// approved simulated member marker when the map rotates.
  Future<void> enableLocationPuck({
    Position? position,
    String avatarAsset =
    'assets/map/member_thu.png',
    String displayName = 'Bạn',
    bool routeActive = false,
  }) async {
    final nextName =
    displayName.trim().isEmpty
        ? 'Bạn'
        : displayName.trim();

    final visualChanged =
        avatarAsset != _locationAvatarAsset ||
            nextName != _locationDisplayName;

    _locationAvatarEnabled = true;
    _locationAvatarAsset = avatarAsset;
    _locationDisplayName = nextName;
    _routeTrackingActive = routeActive;

    if (position != null) {
      _currentUserPosition = position;
    }

    if (visualChanged) {
      _currentUserMarkerCache.clear();
    }

    await _applyNativeLocationPulse();

    // Pulse và avatar đều lấy đúng _currentUserPosition.
    // Vì vậy hai tâm luôn trùng nhau, kể cả khi GPS cập nhật.
    await _renderCurrentUserPulse();

    await _renderCurrentUserMarker(
      force: true,
    );

    if (_previewMembersEnabled) {
      await _renderPreviewMembers(
        force: true,
      );
    }
  }

  /// Call this whenever a fresh GPS/background location is received.
  Future<void> updateCurrentUserPosition(
      Position position,
      ) async {
    _currentUserPosition = position;

    if (!_locationAvatarEnabled) {
      return;
    }

    await _renderCurrentUserPulse();

    await _renderCurrentUserMarker(
      force: true,
    );
  }

  /// Pinned trip / active route:
  /// false -> neutral avatar, no pulse
  /// true  -> blue ring + native animated pulse
  Future<void> setRouteTrackingActive(
      bool active, {
        Position? position,
        String? avatarAsset,
        String? displayName,
      }) async {
    _locationAvatarEnabled = true;
    _routeTrackingActive = active;

    if (position != null) {
      _currentUserPosition = position;
    }

    var visualChanged = false;

    if (avatarAsset != null &&
        avatarAsset.trim().isNotEmpty &&
        avatarAsset != _locationAvatarAsset) {
      _locationAvatarAsset = avatarAsset;
      visualChanged = true;
    }

    if (displayName != null &&
        displayName.trim().isNotEmpty &&
        displayName.trim() !=
            _locationDisplayName) {
      _locationDisplayName =
          displayName.trim();
      visualChanged = true;
    }

    if (visualChanged) {
      _currentUserMarkerCache.clear();
    }

    // Active/idle uses different ring color.
    _currentUserMarkerCache.removeWhere(
          (_, __) => true,
    );

    await _applyNativeLocationPulse();

    await _renderCurrentUserPulse();

    await _renderCurrentUserMarker(
      force: true,
    );

    if (_previewMembersEnabled) {
      await _renderPreviewMembers(
        force: true,
      );
    }
  }

  Future<void> disableLocationPuck() async {
    _locationAvatarEnabled = false;
    _routeTrackingActive = false;
    _currentUserMarkerMode = null;
    _currentUserMarkerBucket = null;

    _stopCurrentUserPulseAnimation();

    _currentUserPulseAnnotation = null;
    await _currentUserPulseManager?.deleteAll();
    await _currentUserManager?.deleteAll();

    final map = _map;

    if (map != null) {
      await map.location.updateSettings(
        LocationComponentSettings(
          enabled: false,
        ),
      );
    }

    if (_previewMembersEnabled) {
      await _renderPreviewMembers(
        force: true,
      );
    }
  }

  /// Keep native Mapbox pulse from V9, but make its own puck invisible.
  /// The visible marker is the PointAnnotation above.
  Future<void> _applyNativeLocationPulse() async {
    final map = _map;
    if (map == null) return;

    final transparent =
        _transparentLocationPuckImage ??
            await _buildTransparentLocationPuck();

    _transparentLocationPuckImage =
        transparent;

    await map.location.updateSettings(
      LocationComponentSettings(
        enabled: true,

        // Native pulse tắt hoàn toàn.
        // Pulse nhìn thấy được render bằng CircleAnnotation
        // tại chính _currentUserPosition để không bao giờ lệch avatar.
        pulsingEnabled: false,
        pulsingMaxRadius: 0,

        showAccuracyRing: false,
        puckBearingEnabled: false,

        locationPuck: LocationPuck(
          locationPuck2D:
          DefaultLocationPuck2D(
            topImage: transparent,
            bearingImage: Uint8List(0),
            shadowImage: Uint8List(0),
            opacity: 1,
          ),
        ),
      ),
    );
  }

  Future<void> _renderCurrentUserPulse() async {
    final manager =
        _currentUserPulseManager;

    final position =
        _currentUserPosition;

    // Chỉ pulse khi:
    // - marker current user đang bật;
    // - Trip đã ghim / tracking ACTIVE;
    // - đã có tọa độ hiện tại.
    if (manager == null ||
        !_locationAvatarEnabled ||
        !_routeTrackingActive ||
        position == null) {
      _stopCurrentUserPulseAnimation();

      _currentUserPulseAnnotation = null;
      await manager?.deleteAll();
      return;
    }

    final baseRadius =
    _currentUserPulseBaseRadius();

    final point = Point(
      coordinates: position,
    );

    final existing =
        _currentUserPulseAnnotation;

    if (existing == null) {
      await manager.deleteAll();

      _currentUserPulseAnnotation =
      await manager.create(
        CircleAnnotationOptions(
          geometry: point,

          // Phần giữa sẽ bị avatar che.
          // Chỉ phần vòng ngoài mới nhìn thấy như pulse Zenly/V9.
          circleRadius: baseRadius,
          circleColor: 0xFF0D8AE8,
          circleOpacity: 0.30,
          circleBlur: 0.04,
          circleStrokeWidth: 0,

          customData:
          <String, Object>{
            'currentUserPulse': true,
          },
        ),
      );
    } else {
      // Quan trọng nhất:
      // pulse dùng CHÍNH tọa độ mà avatar đang dùng.
      // Không còn phụ thuộc vị trí GPS nội bộ của LocationComponent.
      existing.geometry = point;
      existing.circleRadius = baseRadius;
      existing.circleOpacity = 0.36;

      await manager.update(existing);
    }

    _startCurrentUserPulseAnimation();
  }

  double _currentUserPulseBaseRadius() {
    final iconSize =
    _currentUserIconSizeForZoom(
      _currentZoom,
    );

    // Avatar marker:
    // canvas radius ngoài ≈ 32px rồi nhân iconSize.
    // Pulse bắt đầu sát ngoài avatar để không bị to quá như V13.
    return (25.0 * iconSize) + 1.5;
  }

  void _startCurrentUserPulseAnimation() {
    if (!_routeTrackingActive ||
        _currentUserPulseAnnotation == null) {
      return;
    }

    if (_currentUserPulseTimer != null) {
      return;
    }

    _currentUserPulseStartedAtMs =
        DateTime.now()
            .millisecondsSinceEpoch;

    // Reset frame đầu tiên để nhìn thấy rõ pulse bắt đầu sát avatar.
    final pulse =
        _currentUserPulseAnnotation;

    if (pulse != null) {
      pulse.circleRadius =
          _currentUserPulseBaseRadius();
      pulse.circleOpacity = 0.36;

      unawaited(
        _currentUserPulseManager?.update(
          pulse,
        ),
      );
    }

    _currentUserPulseTimer =
        Timer.periodic(
          _currentUserPulseFrameInterval,
              (_) {
            unawaited(
              _updateCurrentUserPulseFrame(),
            );
          },
        );

    unawaited(
      _updateCurrentUserPulseFrame(),
    );
  }

  void _stopCurrentUserPulseAnimation() {
    _currentUserPulseTimer?.cancel();
    _currentUserPulseTimer = null;
    _currentUserPulseFrameInFlight = false;
  }

  Future<void>
  _updateCurrentUserPulseFrame() async {
    if (_currentUserPulseFrameInFlight ||
        !_routeTrackingActive ||
        _currentUserPulseAnnotation == null) {
      return;
    }

    final manager =
        _currentUserPulseManager;

    if (manager == null) {
      return;
    }

    _currentUserPulseFrameInFlight = true;

    try {
      final now =
          DateTime.now()
              .millisecondsSinceEpoch;

      final elapsed =
          (now - _currentUserPulseStartedAtMs) %
              _currentUserPulseCycleMs;

      final t =
          elapsed /
              _currentUserPulseCycleMs;

      // Native V9 có cảm giác "bung" nhanh rồi mờ dần.
      // easeOutQuad cho chuyển động rõ hơn nhưng vẫn mềm.
      final eased =
      Curves.easeOutQuad.transform(
        t,
      );

      final baseRadius =
      _currentUserPulseBaseRadius();

      // Nở đủ để mắt nhận ra chuyển động, nhưng vẫn gọn quanh avatar.
      final radius =
          baseRadius +
              (4.0 * eased);

      // Mờ dần rõ ràng từ đầu chu kỳ đến cuối.
      final opacity =
      (0.36 * (1.0 - t))
          .clamp(0.0, 0.36)
          .toDouble();

      final pulse =
          _currentUserPulseAnnotation;

      if (pulse == null) {
        return;
      }

      // QUAN TRỌNG:
      // CircleAnnotationOptions đã gán radius/opacity riêng cho feature.
      // Vì vậy phải update CHÍNH annotation này ở mỗi frame.
      // Chỉ set property trên manager có thể không làm feature đổi trực quan.
      pulse.circleRadius = radius;
      pulse.circleOpacity = opacity;

      await manager.update(pulse);
    } finally {
      _currentUserPulseFrameInFlight = false;
    }
  }

  Future<Uint8List>
  _buildTransparentLocationPuck() async {
    final recorder =
    ui.PictureRecorder();

    // Transparent 2x2 bitmap.
    ui.Canvas(recorder);

    final picture =
    recorder.endRecording();

    final image =
    await picture.toImage(
      2,
      2,
    );

    final data =
    await image.toByteData(
      format:
      ui.ImageByteFormat.png,
    );

    if (data == null) {
      throw StateError(
        'Không tạo được transparent location puck',
      );
    }

    return data.buffer
        .asUint8List();
  }

  Future<void> _renderCurrentUserMarker({
    bool force = false,
  }) async {
    if (!_locationAvatarEnabled) {
      return;
    }

    final manager =
        _currentUserManager;

    final position =
        _currentUserPosition;

    if (manager == null ||
        position == null) {
      return;
    }

    // EXACTLY reuse member zoom behavior.
    final mode =
    _memberModeForZoom(
      _currentZoom,
    );

    final nextBucket =
    mode == _MemberMarkerMode.card
        ? _memberZoomBucket(
      _currentZoom,
    )
        : null;

    final sameMode =
        mode ==
            _currentUserMarkerMode;

    final sameBucket =
        mode != _MemberMarkerMode.card ||
            nextBucket ==
                _currentUserMarkerBucket;

    if (!force &&
        sameMode &&
        sameBucket) {
      return;
    }

    _currentUserMarkerMode = mode;
    _currentUserMarkerBucket =
        nextBucket;

    final image =
    await _currentUserMarkerImage(
      active: _routeTrackingActive,
    );

    final iconSize =
    _currentUserIconSizeForZoom(
      _currentZoom,
    );

    await manager.deleteAll();

    await manager.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: position,
        ),
        image: image,
        iconAnchor:
        IconAnchor.CENTER,
        iconSize: iconSize,
        symbolSortKey: 650,
        customData:
        <String, Object>{
          'currentUser': true,
        },
      ),
    );
  }

  Future<Uint8List>
  _currentUserMarkerImage({
    required bool active,
  }) async {
    final key = <String>[
      _locationAvatarAsset,
      active ? 'active' : 'idle',
    ].join('|');

    final cached =
    _currentUserMarkerCache[key];

    if (cached != null) {
      return cached;
    }

    final avatar =
    await _memberAvatarImage(
      _locationAvatarAsset,
    );

    final image =
    await _buildCurrentUserCompactMarker(
      avatar: avatar,
      active: active,
    );

    _currentUserMarkerCache[key] =
        image;

    return image;
  }

  Future<Uint8List>
  _buildCurrentUserCompactMarker({
    required ui.Image? avatar,
    required bool active,
  }) async {
    // Same dimensions as approved member compact marker.
    const size = 76.0;
    const center =
    ui.Offset(
      size / 2,
      size / 2,
    );
    const radius = 30.0;

    final recorder =
    ui.PictureRecorder();
    final canvas =
    ui.Canvas(recorder);

    canvas.drawCircle(
      center.translate(
        0,
        2,
      ),
      radius + 2,
      ui.Paint()
        ..color =
        const ui.Color(
          0x26000000,
        )
        ..maskFilter =
        const ui.MaskFilter.blur(
          ui.BlurStyle.normal,
          3,
        ),
    );

    canvas.drawCircle(
      center,
      radius + 2,
      ui.Paint()
        ..color = active
            ? const ui.Color(
          0xFF0A43A8,
        )
            : const ui.Color(
          0xFF9AA8BA,
        ),
    );

    _drawAvatarCircle(
      canvas,
      avatar: avatar,
      center: center,
      radius: radius - 2,
      fallbackColor:
      const ui.Color(
        0xFFDCE8FA,
      ),
      opacity: 1,
    );

    return _pictureToPng(
      recorder,
      width: size,
      height: size,
    );
  }

  Future<void> renderPlaces(
      List<GoMateMapPlace> places,
      ) async {
    _explorePlaces =
    List<GoMateMapPlace>.unmodifiable(
      places,
    );

    _exploreMarkersEnabled = true;

    await _renderExploreMarkers(
      force: true,
    );
  }

  Future<void> _renderExploreMarkers({
    bool force = false,
  }) async {
    if (!_exploreMarkersEnabled) return;

    final pointManager = _placeManager;
    final dotManager = _placeDotManager;

    if (pointManager == null ||
        dotManager == null) {
      return;
    }

    final mode =
    _markerModeForZoom(_currentZoom);

    final nextNearBucket =
    mode == _ExploreMarkerMode.near
        ? _nearZoomBucket(_currentZoom)
        : null;

    final sameMode =
        mode == _placeMarkerMode;

    final sameNearBucket =
        mode != _ExploreMarkerMode.near ||
            nextNearBucket == _nearMarkerBucket;

    if (!force &&
        sameMode &&
        sameNearBucket) {
      return;
    }

    _placeMarkerMode = mode;
    _nearMarkerBucket = nextNearBucket;

    // Chỉ để một loại marker explore tồn tại
    // để tránh double tap / marker chồng nhau.
    await pointManager.deleteAll();
    await dotManager.deleteAll();

    if (mode == _ExploreMarkerMode.near) {
      await _renderPlaceIcons(
        iconSize:
        _nearIconSizeForZoom(_currentZoom),
      );
      return;
    }

    await _renderPlaceDots(
      medium:
      mode == _ExploreMarkerMode.medium,
    );
  }

  Future<void> _renderPlaceDots({
    required bool medium,
  }) async {
    final manager = _placeDotManager;

    if (manager == null) return;

    final options =
    <CircleAnnotationOptions>[];

    for (final place in _explorePlaces) {
      options.add(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: place.position,
          ),

          circleColor:
          _visualColor(
            _visualTypeForPlace(place),
          ),

          circleRadius:
          medium ? _mediumDotRadius : _farDotRadius,

          circleOpacity: 1,

          circleStrokeColor:
          0xFFFFFFFF,

          circleStrokeWidth:
          medium ? 2.2 : 1.6,

          circleStrokeOpacity: 1,

          circleSortKey: 10,

          customData: <String, Object>{
            'placeId': place.placeId,
          },
        ),
      );
    }

    if (options.isNotEmpty) {
      await manager.createMulti(options);
    }
  }

  Future<void> _renderPlaceIcons({
    required double iconSize,
  }) async {
    final manager = _placeManager;

    if (manager == null) return;

    final options =
    <PointAnnotationOptions>[];

    for (final place in _explorePlaces) {
      final visual =
      _visualTypeForPlace(place);

      final image =
      _placeMarkerImages[visual];

      if (image == null) continue;

      options.add(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: place.position,
          ),
          image: image,
          iconAnchor: IconAnchor.CENTER,

          // Size tăng theo zoom và dừng ở _nearMaxIconSize.
          iconSize: iconSize,

          symbolSortKey: 10,

          customData: <String, Object>{
            'placeId': place.placeId,
          },
        ),
      );
    }

    if (options.isNotEmpty) {
      await manager.createMulti(options);
    }
  }

  Future<void> updateExploreZoom(
      double zoom,
      ) async {
    final previousMode =
        _placeMarkerMode;

    final previousNearBucket =
        _nearMarkerBucket;

    final previousMemberMode =
        _memberMarkerMode;

    final previousMemberBucket =
        _memberMarkerBucket;

    _currentZoom = zoom;

    if (_locationAvatarEnabled) {
      await _renderCurrentUserMarker();
    }

    if (_previewMembersEnabled) {
      final nextMemberMode =
      _memberModeForZoom(zoom);

      final nextMemberBucket =
      nextMemberMode ==
          _MemberMarkerMode.card
          ? _memberZoomBucket(zoom)
          : null;

      final memberModeChanged =
          nextMemberMode !=
              previousMemberMode;

      final memberSizeChanged =
          nextMemberMode ==
              _MemberMarkerMode.card &&
              nextMemberBucket !=
                  previousMemberBucket;

      if (memberModeChanged ||
          memberSizeChanged) {
        await _renderPreviewMembers();
      }
    }

    if (!_exploreMarkersEnabled) {
      return;
    }

    final nextMode =
    _markerModeForZoom(zoom);

    final nextNearBucket =
    nextMode ==
        _ExploreMarkerMode.near
        ? _nearZoomBucket(zoom)
        : null;

    final modeChanged =
        nextMode != previousMode;

    final nearSizeChanged =
        nextMode ==
            _ExploreMarkerMode.near &&
            nextNearBucket !=
                previousNearBucket;

    if (!modeChanged &&
        !nearSizeChanged) {
      return;
    }

    await _renderExploreMarkers();

    if (_selectedPlace != null) {
      await _renderSelectedMarker();
    }
  }

  /// Hiển thị member giả lập để test visual Zenly-style.
  ///
  /// Chưa gắn business rule "chỉ lịch trình nhóm mới hiện".
  Future<void> showPreviewMembers(
      List<GoMateMapMember> members, {
        required String currentUserId,
      }) async {
    _previewMembers =
    List<GoMateMapMember>.unmodifiable(
      members,
    );

    _previewCurrentUserId =
        currentUserId;

    _previewMembersEnabled = true;

    await _renderPreviewMembers(
      force: true,
    );
  }

  Future<void> hidePreviewMembers() async {
    _previewMembersEnabled = false;
    _memberMarkerMode = null;
    _memberMarkerBucket = null;

    await _memberManager?.deleteAll();
  }

  Future<void> _renderPreviewMembers({
    bool force = false,
  }) async {
    if (!_previewMembersEnabled) return;

    final manager = _memberManager;

    if (manager == null) return;

    final mode =
    _memberModeForZoom(_currentZoom);

    final nextBucket =
    mode == _MemberMarkerMode.card
        ? _memberZoomBucket(
      _currentZoom,
    )
        : null;

    final sameMode =
        mode == _memberMarkerMode;

    final sameBucket =
        mode != _MemberMarkerMode.card ||
            nextBucket == _memberMarkerBucket;

    if (!force &&
        sameMode &&
        sameBucket) {
      return;
    }

    _memberMarkerMode = mode;
    _memberMarkerBucket = nextBucket;

    await manager.deleteAll();

    final options =
    <PointAnnotationOptions>[];

    for (final member in _previewMembers) {
      // Chính mình dùng Mapbox location puck khi GPS/avatar puck đang bật.
      // Tránh render trùng một avatar ở cùng người dùng.
      if (_locationAvatarEnabled &&
          _isPreviewCurrentUser(member)) {
        continue;
      }

      final compact =
          mode == _MemberMarkerMode.far;

      final image =
      await _memberMarkerImage(
        member,
        compact: compact,
      );

      final baseSize = compact
          ? _memberFarIconSize
          : _memberCardIconSizeForZoom(
        _currentZoom,
      );

      final iconSize = member.isStale
          ? baseSize * 0.90
          : baseSize;

      options.add(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: member.position,
          ),
          image: image,
          iconAnchor: IconAnchor.CENTER,
          iconSize: iconSize,
          symbolSortKey:
          _isPreviewCurrentUser(member)
              ? 520
              : 500,
          customData: <String, Object>{
            'userId': member.userId,
          },
        ),
      );
    }

    if (options.isNotEmpty) {
      await manager.createMulti(options);
    }
  }

  Future<Uint8List> _memberMarkerImage(
      GoMateMapMember member, {
        required bool compact,
      }) async {
    final subtitle =
    compact ? '' : _memberSubtitle(member);

    final cacheKey = <String>[
      member.assetIcon,
      member.displayName,
      subtitle,
      compact ? 'compact' : 'card',
      _isPreviewCurrentUser(member)
          ? 'self'
          : 'other',
      member.isStale
          ? 'stale'
          : 'fresh',
    ].join('|');

    final cached =
    _memberMarkerCache[cacheKey];

    if (cached != null) {
      return cached;
    }

    final avatar =
    await _memberAvatarImage(
      member.assetIcon,
    );

    final image =
    await _buildMemberMarker(
      member: member,
      avatar: avatar,
      subtitle: subtitle,
      compact: compact,
      isCurrentUser:
      _isPreviewCurrentUser(member),
    );

    _memberMarkerCache[cacheKey] =
        image;

    return image;
  }

  Future<ui.Image?> _memberAvatarImage(
      String path,
      ) async {
    final cached =
    _memberAvatarImages[path];

    if (cached != null) {
      return cached;
    }

    try {
      final bytes =
      await rootBundle.load(path);

      final codec =
      await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(),
      );

      final frame =
      await codec.getNextFrame();

      _memberAvatarImages[path] =
          frame.image;

      return frame.image;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _buildMemberMarker({
    required GoMateMapMember member,
    required ui.Image? avatar,
    required String subtitle,
    required bool compact,
    required bool isCurrentUser,
  }) async {
    if (compact) {
      return _buildCompactMemberMarker(
        avatar: avatar,
        isCurrentUser: isCurrentUser,
        isStale: member.isStale,
      );
    }

    return _buildMemberCardMarker(
      member: member,
      avatar: avatar,
      subtitle: subtitle,
      isCurrentUser: isCurrentUser,
      isStale: member.isStale,
    );
  }

  Future<Uint8List> _buildCompactMemberMarker({
    required ui.Image? avatar,
    required bool isCurrentUser,
    required bool isStale,
  }) async {
    const size = 76.0;

    const center =
    ui.Offset(size / 2, size / 2);

    const radius = 30.0;

    final recorder =
    ui.PictureRecorder();

    final canvas =
    ui.Canvas(recorder);

    // Zoom xa: chỉ avatar, không có card trắng.
    canvas.drawCircle(
      center.translate(0, 2),
      radius + 2,
      ui.Paint()
        ..color =
        const ui.Color(0x26000000)
        ..maskFilter =
        const ui.MaskFilter.blur(
          ui.BlurStyle.normal,
          3,
        ),
    );

    canvas.drawCircle(
      center,
      radius + 2,
      ui.Paint()
        ..color = isCurrentUser
            ? const ui.Color(0xFF0A43A8)
            : const ui.Color(0xFF9AA8BA),
    );

    _drawAvatarCircle(
      canvas,
      avatar: avatar,
      center: center,
      radius: radius - 2,
      fallbackColor: isCurrentUser
          ? const ui.Color(0xFFDCE8FA)
          : const ui.Color(0xFFE7ECF3),
      opacity:
      isStale ? 0.65 : 1,
    );

    return _pictureToPng(
      recorder,
      width: size,
      height: size,
    );
  }

  Future<Uint8List> _buildMemberCardMarker({
    required GoMateMapMember member,
    required ui.Image? avatar,
    required String subtitle,
    required bool isCurrentUser,
    required bool isStale,
  }) async {
    const width = 136.0;

    // Self không có dòng phụ nên card thấp hơn.
    final height =
    isCurrentUser ? 124.0 : 148.0;

    const avatarCenter =
    ui.Offset(width / 2, 35);

    const avatarRadius = 30.0;

    final recorder =
    ui.PictureRecorder();

    final canvas =
    ui.Canvas(recorder);

    // Card bắt đầu thấp hơn avatar để đúng kiểu Zenly:
    // avatar nằm trên, khung trắng nằm phía dưới.
    final cardTop = 57.0;

    final cardHeight =
    isCurrentUser ? 56.0 : 78.0;

    final cardRect =
    ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(
        7,
        cardTop,
        width - 14,
        cardHeight,
      ),
      const ui.Radius.circular(18),
    );

    // Card shadow.
    canvas.drawRRect(
      cardRect.shift(
        const ui.Offset(0, 3),
      ),
      ui.Paint()
        ..color =
        const ui.Color(0x24000000)
        ..maskFilter =
        const ui.MaskFilter.blur(
          ui.BlurStyle.normal,
          4,
        ),
    );

    // White card.
    canvas.drawRRect(
      cardRect,
      ui.Paint()
        ..color =
        const ui.Color(0xFFFFFFFF),
    );

    // Avatar shadow.
    canvas.drawCircle(
      avatarCenter.translate(0, 2),
      avatarRadius + 3,
      ui.Paint()
        ..color =
        const ui.Color(0x22000000)
        ..maskFilter =
        const ui.MaskFilter.blur(
          ui.BlurStyle.normal,
          3,
        ),
    );

    // Marker của mình có ring xanh GoMate.
    // Người khác dùng ring xám nhạt.
    canvas.drawCircle(
      avatarCenter,
      avatarRadius + 3,
      ui.Paint()
        ..color = isCurrentUser
            ? const ui.Color(0xFF0A43A8)
            : const ui.Color(0xFFD7DFE9),
    );

    _drawAvatarCircle(
      canvas,
      avatar: avatar,
      center: avatarCenter,
      radius: avatarRadius,
      fallbackColor: isCurrentUser
          ? const ui.Color(0xFFDCE8FA)
          : const ui.Color(0xFFE7ECF3),
      opacity:
      isStale ? 0.65 : 1,
    );

    final namePainter =
    TextPainter(
      text: TextSpan(
        text: member.displayName,
        style: const TextStyle(
          fontSize: 18.5,
          height: 1,
          fontWeight: FontWeight.w800,
          color: Color(0xFF111111),
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textAlign: TextAlign.center,
      textDirection:
      TextDirection.ltr,
    )..layout(
      maxWidth: width - 22,
    );

    final nameY =
    isCurrentUser ? 79.0 : 77.0;

    namePainter.paint(
      canvas,
      ui.Offset(
        (width - namePainter.width) / 2,
        nameY,
      ),
    );

    // Người khác: hiện khoảng cách màu xanh GoMate.
    // Chính mình: không có dòng phụ.
    if (!isCurrentUser &&
        subtitle.trim().isNotEmpty) {
      final subtitlePainter =
      TextPainter(
        text: TextSpan(
          text: subtitle,
          style: const TextStyle(
            fontSize: 15.5,
            height: 1,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A43A8),
          ),
        ),
        maxLines: 1,
        textAlign: TextAlign.center,
        textDirection:
        TextDirection.ltr,
      )..layout(
        maxWidth: width - 22,
      );

      subtitlePainter.paint(
        canvas,
        ui.Offset(
          (width - subtitlePainter.width) / 2,
          105,
        ),
      );
    }

    return _pictureToPng(
      recorder,
      width: width,
      height: height,
    );
  }

  void _drawAvatarCircle(
      ui.Canvas canvas, {
        required ui.Image? avatar,
        required ui.Offset center,
        required double radius,
        required ui.Color fallbackColor,
        required double opacity,
      }) {
    final rect =
    ui.Rect.fromCircle(
      center: center,
      radius: radius,
    );

    canvas.save();

    canvas.clipPath(
      ui.Path()
        ..addOval(rect),
    );

    if (avatar != null) {
      final src =
      _coverSourceRect(
        avatar,
      );

      canvas.drawImageRect(
        avatar,
        src,
        rect,
        ui.Paint()
          ..color = ui.Color.fromRGBO(
            255,
            255,
            255,
            opacity,
          ),
      );
    } else {
      canvas.drawCircle(
        center,
        radius,
        ui.Paint()
          ..color = fallbackColor,
      );

      final iconPainter =
      TextPainter(
        text: TextSpan(
          text: String.fromCharCode(
            Icons.person.codePoint,
          ),
          style: TextStyle(
            fontFamily:
            Icons.person.fontFamily,
            fontSize:
            radius * 1.15,
            color: Colors.white,
          ),
        ),
        textDirection:
        TextDirection.ltr,
      )..layout();

      iconPainter.paint(
        canvas,
        ui.Offset(
          center.dx -
              (iconPainter.width / 2),
          center.dy -
              (iconPainter.height / 2),
        ),
      );
    }

    canvas.restore();
  }

  ui.Rect _coverSourceRect(
      ui.Image image,
      ) {
    final width =
    image.width.toDouble();

    final height =
    image.height.toDouble();

    final side =
    math.min(width, height);

    return ui.Rect.fromLTWH(
      (width - side) / 2,
      (height - side) / 2,
      side,
      side,
    );
  }

  Future<Uint8List> _pictureToPng(
      ui.PictureRecorder recorder, {
        required double width,
        required double height,
      }) async {
    final picture =
    recorder.endRecording();

    final image =
    await picture.toImage(
      width.round(),
      height.round(),
    );

    final data =
    await image.toByteData(
      format:
      ui.ImageByteFormat.png,
    );

    if (data == null) {
      throw StateError(
        'Không tạo được member marker image',
      );
    }

    return data.buffer
        .asUint8List();
  }

  Future<void> renderSelected(
      GoMateMapPlace? place,
      ) async {
    _selectedPlace = place;
    await _renderSelectedMarker();
  }

  Future<void> _renderSelectedMarker() async {
    final manager = _selectedManager;
    if (manager == null) return;

    await manager.deleteAll();

    final place = _selectedPlace;

    if (place == null) {
      return;
    }

    final visual =
    _visualTypeForPlace(place);

    final image =
    _selectedMarkerImages[visual];

    if (image == null) {
      return;
    }

    await manager.create(
      PointAnnotationOptions(
        geometry:
        Point(coordinates: place.position),
        image: image,
        iconAnchor: IconAnchor.CENTER,
        iconSize:
        _selectedIconSizeForZoom(_currentZoom),
        symbolSortKey: 100,
        customData: {
          'placeId': place.placeId,
        },
      ),
    );
  }

  Future<void> clearRouteLayers() async {
    await _routeShadowManager?.deleteAll();
    await _routeManager?.deleteAll();
    await _originManager?.deleteAll();
  }

  Future<void> clearTripLayers() async {
    await clearRouteLayers();
    await _tripStopManager?.deleteAll();
    await _memberManager?.deleteAll();
    await _checkinRadiusManager?.deleteAll();
  }

  Future<void> renderDirections({
    required GoMateMapRoute route,
    required Position origin,
    required GoMateMapPlace destination,
  }) async {
    await clearTripLayers();

    _exploreMarkersEnabled = false;
    _previewMembersEnabled = false;

    await _placeManager?.deleteAll();
    await _placeDotManager?.deleteAll();
    await _selectedManager?.deleteAll();

    await _drawRouteLine(route);

    await _originManager?.create(
      CircleAnnotationOptions(
        geometry: Point(coordinates: origin),

        // Origin theo design system GoMate.
        circleColor: 0xFF0A43A8,
        circleRadius: 7.5,

        // Viền trắng giúp tách khỏi route/background.
        circleStrokeColor: 0xFFFFFFFF,
        circleStrokeWidth: 3,

        circleOpacity: 1,
      ),
    );

    final destinationVisual =
    _visualTypeForPlace(destination);

    final destinationImage =
    _selectedMarkerImages[destinationVisual];

    if (destinationImage != null) {
      await _selectedManager?.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: destination.position),
          image: destinationImage,
          iconAnchor: IconAnchor.CENTER,
          iconSize:
          _selectedIconSizeForZoom(_currentZoom),
          symbolSortKey: 200,
          customData: {
            'placeId': destination.placeId,
          },
        ),
      );
    }

    await fitRoute(
      route.geometry,
      bottomPadding: 265,
      pitch: 18,
    );
  }

  Future<void> renderTrip({
    required GoMateMapRoute route,
    required List<GoMateMapPlace> stops,
    required List<GoMateMapMember> members,
  }) async {
    await clearTripLayers();

    _exploreMarkersEnabled = false;
    _previewMembersEnabled = false;

    await _placeManager?.deleteAll();
    await _placeDotManager?.deleteAll();

    await _drawRouteLine(route);

    final stopOptions = <PointAnnotationOptions>[];

    for (var i = 0; i < stops.length; i++) {
      final number = i + 1;
      final isDestination =
          i == stops.length - 1;

      final image =
      await _tripStopMarkerImage(
        number,
        isDestination: isDestination,
      );

      stopOptions.add(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: stops[i].position,
          ),
          image: image,

          // Marker tròn nằm đúng tâm tọa độ,
          // không còn kiểu pin neo ở đáy.
          iconAnchor: IconAnchor.CENTER,

          // Điểm đến lớn hơn nhẹ để nhận biết ngay.
          iconSize:
          isDestination ? 0.82 : 0.74,

          symbolSortKey:
          isDestination
              ? 280
              : 220 + i.toDouble(),

          customData: {
            'placeId': stops[i].placeId,
          },
        ),
      );
    }

    if (stopOptions.isNotEmpty) {
      await _tripStopManager?.createMulti(stopOptions);
    }

    final memberOptions = <PointAnnotationOptions>[];

    for (final member in members) {
      final image = _memberImages[member.assetIcon];
      if (image == null) continue;

      memberOptions.add(
        PointAnnotationOptions(
          geometry: Point(coordinates: member.position),
          image: image,
          iconSize: member.isStale ? .88 : 1,
          symbolSortKey: 300,
          customData: {'userId': member.userId},
        ),
      );
    }

    if (memberOptions.isNotEmpty) {
      await _memberManager?.createMulti(memberOptions);
    }

    if (stops.isNotEmpty) {
      await _checkinRadiusManager?.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: stops.first.position,
          ),

          // Giữ nguyên semantics vùng check-in,
          // chỉ đổi visual sang GoMate.
          circleColor: 0x140C6ECF,
          circleStrokeColor: 0x660C6ECF,
          circleStrokeWidth: 2,
          circleRadius: 30,
          circleOpacity: .62,
        ),
      );
    }

    await fitRoute(
      route.geometry,
      bottomPadding: 260,
      pitch: 18,
    );
  }

  Future<void> _drawRouteLine(
      GoMateMapRoute route,
      ) async {
    if (route.geometry.length < 2) {
      return;
    }

    final line = LineString(
      coordinates: route.geometry,
    );

    // Outer route:
    // xanh rất nhạt + viền trắng để tuyến đường tách rõ khỏi map
    // nhưng không tạo cảm giác quá nặng như route navigation.
    await _routeShadowManager?.create(
      PolylineAnnotationOptions(
        geometry: line,
        lineColor: 0xFFDCEBFF,
        lineWidth: 14,
        lineOpacity: .96,
        lineJoin: LineJoin.ROUND,
        lineBorderColor: 0xFFFFFFFF,
        lineBorderWidth: 1.8,
      ),
    );

    // Main GoMate route.
    await _routeManager?.create(
      PolylineAnnotationOptions(
        geometry: line,
        lineColor: 0xFF0C6ECF,
        lineWidth: 7,
        lineOpacity: 1,
        lineJoin: LineJoin.ROUND,

        // Viền xanh đậm rất nhẹ để route vẫn rõ
        // trên cả nền nước, park và đường sáng.
        lineBorderColor: 0x660A43A8,
        lineBorderWidth: 0.8,
      ),
    );
  }

  Future<void> fitRoute(
      List<Position> coordinates, {
        double bottomPadding = 250,
        double pitch = 18,
      }) async {
    final map = _map;

    if (map == null || coordinates.isEmpty) {
      return;
    }

    try {
      final camera = await map.cameraForCoordinates(
        coordinates
            .map((p) => Point(coordinates: p))
            .toList(),
        MbxEdgeInsets(
          top: 120,
          left: 48,
          bottom: bottomPadding,
          right: 48,
        ),
        0,
        pitch,
      );

      await map.easeTo(
        camera,
        MapAnimationOptions(duration: 750),
      );
    } catch (_) {
      final middle =
      coordinates[coordinates.length ~/ 2];

      await map.easeTo(
        CameraOptions(
          center: Point(coordinates: middle),
          zoom: 13.8,
          pitch: pitch,
          bearing: 0,
        ),
        MapAnimationOptions(duration: 650),
      );
    }
  }

  Future<void> focusPlace(
      GoMateMapPlace place,
      ) async {
    final map = _map;
    if (map == null) return;

    await map.easeTo(
      CameraOptions(
        center: Point(
          coordinates: place.position,
        ),
        zoom: 15.3,
        pitch: 15,
        padding: MbxEdgeInsets(
          top: 80,
          left: 20,
          bottom: 245,
          right: 20,
        ),
      ),
      MapAnimationOptions(duration: 650),
    );
  }

  Future<void> focusCoordinate(
      Position position, {
        double zoom = 16,
      }) async {
    final map = _map;
    if (map == null) return;

    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: position),
        zoom: zoom,
        pitch: 15,
      ),
      MapAnimationOptions(duration: 750),
    );
  }

  Future<void> showExplorePlaces(
      List<GoMateMapPlace> places,
      ) async {
    await clearTripLayers();
    await _selectedManager?.deleteAll();

    _exploreMarkersEnabled = true;

    await renderPlaces(places);

    if (_previewMembers.isNotEmpty) {
      _previewMembersEnabled = true;

      await _renderPreviewMembers(
        force: true,
      );
    }
  }

  void dispose() {
    _stopCurrentUserPulseAnimation();

    _placeTapSubscription?.cancel();
    _placeDotTapSubscription?.cancel();
    _tripTapSubscription?.cancel();
  }

  Future<Uint8List> _load(
      String path,
      ) async {
    final bytes = await rootBundle.load(path);
    return bytes.buffer.asUint8List();
  }

  Future<Uint8List> _buildPlaceMarker(
      _PlaceVisualType visual, {
        required bool selected,
      }) async {
    // Raster tương đối lớn để icon nét trên màn hình DPI cao.
    final canvasSize =
    selected ? 92.0 : 80.0;

    final center = ui.Offset(
      canvasSize / 2,
      canvasSize / 2,
    );

    final recorder =
    ui.PictureRecorder();

    final canvas =
    ui.Canvas(recorder);

    final markerColor =
    ui.Color(_visualColor(visual));

    final outerRadius =
    selected ? 37.0 : 33.0;

    // Shadow mềm.
    canvas.drawCircle(
      center.translate(
        0,
        selected ? 2.8 : 2.4,
      ),
      outerRadius,
      ui.Paint()
        ..color =
        const ui.Color(0x26000000)
        ..maskFilter =
        const ui.MaskFilter.blur(
          ui.BlurStyle.normal,
          4,
        ),
    );

    if (selected) {
      // Ring xanh GoMate.
      canvas.drawCircle(
        center,
        36.0,
        ui.Paint()
          ..color =
          const ui.Color(0xFF0A43A8),
      );

      // White separator.
      canvas.drawCircle(
        center,
        32.0,
        ui.Paint()
          ..color =
          const ui.Color(0xFFFFFFFF),
      );

      canvas.drawCircle(
        center,
        28.5,
        ui.Paint()
          ..color = markerColor,
      );
    } else {
      // Marker thường có viền trắng rõ.
      canvas.drawCircle(
        center,
        33.0,
        ui.Paint()
          ..color =
          const ui.Color(0xFFFFFFFF),
      );

      canvas.drawCircle(
        center,
        29.0,
        ui.Paint()
          ..color = markerColor,
      );
    }

    final icon =
    _visualIcon(visual);

    final iconPainter =
    TextPainter(
      text: TextSpan(
        text: String.fromCharCode(
          icon.codePoint,
        ),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          fontSize:
          selected ? 34.0 : 32.0,
          color: Colors.white,
        ),
      ),
      textDirection:
      TextDirection.ltr,
    )..layout();

    iconPainter.paint(
      canvas,
      ui.Offset(
        center.dx -
            (iconPainter.width / 2),
        center.dy -
            (iconPainter.height / 2),
      ),
    );

    final picture =
    recorder.endRecording();

    final image =
    await picture.toImage(
      canvasSize.round(),
      canvasSize.round(),
    );

    final data =
    await image.toByteData(
      format:
      ui.ImageByteFormat.png,
    );

    if (data == null) {
      throw StateError(
        'Không tạo được marker image cho $visual',
      );
    }

    return data.buffer
        .asUint8List();
  }

  Future<Uint8List> _tripStopMarkerImage(
      int number, {
        required bool isDestination,
      }) async {
    final safeNumber =
    number.clamp(1, 999).toInt();

    final cacheKey =
        '$safeNumber:${isDestination ? 'destination' : 'normal'}';

    final cached =
    _tripStopMarkerCache[cacheKey];

    if (cached != null) {
      return cached;
    }

    final marker =
    await _buildTripStopMarker(
      safeNumber,
      isDestination: isDestination,
    );

    _tripStopMarkerCache[cacheKey] =
        marker;

    return marker;
  }

  Future<Uint8List> _buildTripStopMarker(
      int number, {
        required bool isDestination,
      }) async {
    final canvasSize =
    isDestination ? 92.0 : 82.0;

    final center = ui.Offset(
      canvasSize / 2,
      canvasSize / 2,
    );

    final recorder =
    ui.PictureRecorder();

    final canvas =
    ui.Canvas(recorder);

    final shadowRadius =
    isDestination ? 36.0 : 32.0;

    // Shadow mềm.
    canvas.drawCircle(
      center.translate(0, 2.5),
      shadowRadius,
      ui.Paint()
        ..color =
        const ui.Color(0x26000000)
        ..maskFilter =
        const ui.MaskFilter.blur(
          ui.BlurStyle.normal,
          4,
        ),
    );

    if (isDestination) {
      // Destination có outer ring xanh nhạt để phân biệt,
      // nhưng vẫn giữ số thứ tự của điểm dừng.
      canvas.drawCircle(
        center,
        38,
        ui.Paint()
          ..color =
          const ui.Color(0xFFDCEBFF),
      );

      canvas.drawCircle(
        center,
        34.5,
        ui.Paint()
          ..color =
          const ui.Color(0xFFFFFFFF),
      );

      canvas.drawCircle(
        center,
        30.5,
        ui.Paint()
          ..shader =
          ui.Gradient.linear(
            ui.Offset(
              center.dx - 22,
              center.dy - 22,
            ),
            ui.Offset(
              center.dx + 22,
              center.dy + 22,
            ),
            const <ui.Color>[
              ui.Color(0xFF0A43A8),
              ui.Color(0xFF0D8AE8),
            ],
          ),
      );
    } else {
      // Stop thường.
      canvas.drawCircle(
        center,
        33,
        ui.Paint()
          ..color =
          const ui.Color(0xFFFFFFFF),
      );

      canvas.drawCircle(
        center,
        29,
        ui.Paint()
          ..shader =
          ui.Gradient.linear(
            ui.Offset(
              center.dx - 20,
              center.dy - 20,
            ),
            ui.Offset(
              center.dx + 20,
              center.dy + 20,
            ),
            const <ui.Color>[
              ui.Color(0xFF0A43A8),
              ui.Color(0xFF0C6ECF),
              ui.Color(0xFF0D8AE8),
            ],
            const <double>[
              0,
              0.57,
              1,
            ],
          ),
      );
    }

    final numberPainter =
    TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          fontSize:
          isDestination ? 29 : 27,
          height: 1,
          fontWeight:
          FontWeight.w800,
          color: Colors.white,
        ),
      ),
      maxLines: 1,
      textAlign:
      TextAlign.center,
      textDirection:
      TextDirection.ltr,
    )..layout();

    numberPainter.paint(
      canvas,
      ui.Offset(
        center.dx -
            (numberPainter.width / 2),
        center.dy -
            (numberPainter.height / 2),
      ),
    );

    final picture =
    recorder.endRecording();

    final image =
    await picture.toImage(
      canvasSize.round(),
      canvasSize.round(),
    );

    final data =
    await image.toByteData(
      format:
      ui.ImageByteFormat.png,
    );

    if (data == null) {
      throw StateError(
        'Không tạo được Trip stop marker $number',
      );
    }

    return data.buffer
        .asUint8List();
  }

  Future<void> _loadAssets() async {
    for (final visual
    in _PlaceVisualType.values) {
      _placeMarkerImages[visual] =
      await _buildPlaceMarker(
        visual,
        selected: false,
      );

      _selectedMarkerImages[visual] =
      await _buildPlaceMarker(
        visual,
        selected: true,
      );
    }

    for (final path in [
      'assets/map/member_an.png',
      'assets/map/member_thu.png',
    ]) {
      _memberImages[path] = await _load(path);

      final avatar =
      await _memberAvatarImage(path);

      if (avatar != null) {
        _memberAvatarImages[path] = avatar;
      }
    }
  }
}
enum _MemberMarkerMode {
  far,
  card,
}

enum _PlaceVisualType {
  attraction,
  checkin,
  culture,

  cafe,
  restaurant,
  bakery,
  bar,

  park,
  water,
  landscape,

  shopping,
  hotel,

  bus,
  train,

  entertainment,
}

enum _ExploreMarkerMode {
  far,
  medium,
  near,
}

