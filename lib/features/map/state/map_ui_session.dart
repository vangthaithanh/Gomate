import 'package:flutter/foundation.dart';

import '../../trip/models/trip_ui_models.dart';
import '../models/map_place.dart';

class GoMateMapLaunchRequest {
  final TripUi trip;
  final int day;
  final bool expandDayRoute;

  const GoMateMapLaunchRequest({
    required this.trip,
    this.day = 1,
    this.expandDayRoute = true,
  });
}

class GoMateMapAddPlaceRequest {
  final String placeId;
  final TripUi trip;

  const GoMateMapAddPlaceRequest({
    required this.placeId,
    required this.trip,
  });
}

/// UI-only session state.
///
/// Không gọi API/backend ở đây.
/// Đây là lớp nối tạm thời giữa:
/// - Trip
/// - Map
/// - Place detail
/// - Message
///
/// Backend sau này sẽ thay nguồn dữ liệu, nhưng contract UI có thể giữ lại.
class GoMateMapUiSession {
  GoMateMapUiSession._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// MainShell lắng nghe notifier này để đổi tab.
  static final ValueNotifier<int?> requestedMainTab =
      ValueNotifier<int?>(null);

  static final List<GoMateMapPlace> _recentPlaces =
      <GoMateMapPlace>[];

  static List<TripUi> _availableTrips = <TripUi>[];

  static TripUi? _pinnedTrip;
  static TripUi? _selectedTrip;

  static int _selectedDay = 1;

  static GoMateMapLaunchRequest? _pendingLaunchRequest;
  static GoMateMapAddPlaceRequest? _pendingAddPlaceRequest;

  static bool _hideMapBottomNav = false;

  static List<GoMateMapPlace> get recentPlaces =>
      List<GoMateMapPlace>.unmodifiable(_recentPlaces);

  static List<TripUi> get availableTrips =>
      List<TripUi>.unmodifiable(_availableTrips);

  static TripUi? get pinnedTrip => _pinnedTrip;

  static TripUi? get selectedTrip => _selectedTrip;

  /// Trip đang được hiển thị trên Map.
  ///
  /// Nếu chưa chọn tạm thời thì ưu tiên lịch trình đang ghim.
  static TripUi? get displayedTrip =>
      _selectedTrip ?? _pinnedTrip;

  static bool get hasPinnedTrip => _pinnedTrip != null;

  static int get selectedDay => _selectedDay;

  static bool get hideMapBottomNav => _hideMapBottomNav;

  static void _notify() {
    revision.value++;
  }

  static void registerTrips(
    List<TripUi> trips,
  ) {
    _availableTrips =
        List<TripUi>.unmodifiable(trips);

    TripUi? active;

    for (final item in _availableTrips) {
      if (item.isActive) {
        active = item;
        break;
      }
    }

    if (active != null) {
      _pinnedTrip = active;
    } else {
      // Trip list hiện tại là source of truth cho UI demo.
      // Không còn item isActive => không còn pinned trip.
      _pinnedTrip = null;
    }

    final current = _selectedTrip;

    if (current != null) {
      for (final item in _availableTrips) {
        if (item.id == current.id) {
          _selectedTrip = item;
          break;
        }
      }
    } else if (_pinnedTrip != null) {
      _selectedTrip = _pinnedTrip;
    }

    _notify();
  }

  static void updateTrip(
    TripUi trip,
  ) {
    final items =
        List<TripUi>.from(_availableTrips);

    final index = items.indexWhere(
      (item) => item.id == trip.id,
    );

    if (index >= 0) {
      items[index] = trip;
    } else {
      items.insert(0, trip);
    }

    _availableTrips =
        List<TripUi>.unmodifiable(items);

    if (_selectedTrip?.id == trip.id) {
      _selectedTrip = trip;
    }

    if (_pinnedTrip?.id == trip.id) {
      _pinnedTrip = trip;
    }

    if (trip.isActive) {
      pinTrip(trip);
      return;
    }

    _notify();
  }

  static void removeTrip(
    String tripId,
  ) {
    _availableTrips = _availableTrips
        .where((item) => item.id != tripId)
        .toList(growable: false);

    if (_selectedTrip?.id == tripId) {
      _selectedTrip = null;
    }

    if (_pinnedTrip?.id == tripId) {
      _pinnedTrip = null;
    }

    _notify();
  }

  static void pinTrip(
    TripUi trip,
  ) {
    final pinned =
        trip.copyWith(isActive: true);

    _pinnedTrip = pinned;

    _availableTrips = _availableTrips
        .map(
          (item) => item.copyWith(
            isActive: item.id == pinned.id,
          ),
        )
        .toList(growable: false);

    if (_selectedTrip == null ||
        _selectedTrip?.id == pinned.id) {
      _selectedTrip = pinned;
    }

    _notify();
  }

  static void clearPinnedTrip({
    String? tripId,
  }) {
    if (tripId != null &&
        _pinnedTrip?.id != tripId) {
      return;
    }

    final oldId = _pinnedTrip?.id;
    _pinnedTrip = null;

    if (oldId != null) {
      _availableTrips = _availableTrips
          .map(
            (item) => item.id == oldId
                ? item.copyWith(isActive: false)
                : item,
          )
          .toList(growable: false);
    }

    _notify();
  }

  static void selectTrip(
    TripUi trip, {
    int day = 1,
  }) {
    _selectedTrip = trip;
    _selectedDay =
        day.clamp(1, trip.days).toInt();

    _notify();
  }

  static void selectDay(
    int day,
  ) {
    final trip = displayedTrip;

    if (trip == null) {
      _selectedDay = 1;
    } else {
      _selectedDay =
          day.clamp(1, trip.days).toInt();
    }

    _notify();
  }

  /// Quy tắc đã chốt:
  ///
  /// - Có pinned trip:
  ///   rời Map sang tab khác => quay về pinned trip.
  ///
  /// - Không có pinned trip:
  ///   giữ trip người dùng đang chọn.
  static void handleLeavingMapTab() {
    if (_pinnedTrip == null) {
      return;
    }

    _selectedTrip = _pinnedTrip;
    _selectedDay = 1;
    _notify();
  }

  static void requestMainTab(
    int index,
  ) {
    requestedMainTab.value = index;
  }

  static void clearRequestedMainTab() {
    requestedMainTab.value = null;
  }

  static void requestOpenTripOnMap(
    TripUi trip, {
    int day = 1,
    bool expandDayRoute = true,
  }) {
    selectTrip(
      trip,
      day: day,
    );

    _pendingLaunchRequest =
        GoMateMapLaunchRequest(
      trip: trip,
      day: day,
      expandDayRoute: expandDayRoute,
    );

    requestMainTab(2);
    _notify();
  }

  static GoMateMapLaunchRequest?
      consumeLaunchRequest() {
    final value =
        _pendingLaunchRequest;

    _pendingLaunchRequest = null;

    return value;
  }

  static void requestAddPlaceFromDetail({
    required String placeId,
    required TripUi trip,
  }) {
    selectTrip(trip);

    _pendingAddPlaceRequest =
        GoMateMapAddPlaceRequest(
      placeId: placeId,
      trip: trip,
    );

    requestMainTab(2);
    _notify();
  }

  static GoMateMapAddPlaceRequest?
      consumeAddPlaceRequest() {
    final value =
        _pendingAddPlaceRequest;

    _pendingAddPlaceRequest = null;

    return value;
  }

  static void setMapBottomNavHidden(
    bool hidden,
  ) {
    if (_hideMapBottomNav == hidden) {
      return;
    }

    _hideMapBottomNav = hidden;
    _notify();
  }

  static void addRecent(
    GoMateMapPlace place,
  ) {
    _recentPlaces.removeWhere(
      (item) => item.placeId == place.placeId,
    );

    _recentPlaces.insert(0, place);

    if (_recentPlaces.length > 5) {
      _recentPlaces.removeRange(
        5,
        _recentPlaces.length,
      );
    }
  }
}
